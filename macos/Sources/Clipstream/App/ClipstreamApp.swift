import SwiftUI
import AppKit

/// Pure AppKit application entry point for a true menu-bar resident agent (LSUIElement = true).
/// This prevents SwiftUI from opening any empty Settings or WindowGroup windows on launch.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    
    var statusItem: NSStatusItem?
    var hudWindow: HUDPanel?
    var previousApp: NSRunningApplication?
    
    private var outsideClickMonitor: Any?
    private var localKeyMonitor: Any?
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
    
    override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Close any phantom windows if created
        for window in NSApp.windows {
            if window !== hudWindow {
                window.close()
            }
        }
        
        // Start background clipboard observer
        ClipboardManager.shared.startObserving()
        
        // Configure menu bar item with the Clipstream logo
        setupStatusItem()
        
        // Register global hotkey: ⌘ + ⇧ + V
        HotKeyManager.shared.onHotKeyTriggered = { [weak self] in
            Task { @MainActor in
                self?.toggleHUD()
            }
        }
        HotKeyManager.shared.registerDefaultHotKey()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = createStatusBarLogoImage()
            button.imagePosition = .imageOnly
            button.action = #selector(toggleHUD)
            button.target = self
        }
    }
    
    /// Generates a crisp vector status bar icon matching the Clipstream logo (clipboard + stream waves)
    private func createStatusBarLogoImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            // Clipboard base outline
            let bodyRect = NSRect(x: 2.5, y: 1.5, width: 13, height: 13)
            let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 3, yRadius: 3)
            bodyPath.lineWidth = 1.4
            NSColor.labelColor.setStroke()
            bodyPath.stroke()
            
            // Top clip
            let clipRect = NSRect(x: 5.5, y: 13, width: 7, height: 3.5)
            let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: 1.2, yRadius: 1.2)
            NSColor.labelColor.setFill()
            clipPath.fill()
            
            // Stream wave 1
            let wave1 = NSBezierPath()
            wave1.move(to: NSPoint(x: 4.5, y: 9.5))
            wave1.curve(to: NSPoint(x: 13.5, y: 8.5), controlPoint1: NSPoint(x: 7.5, y: 11.5), controlPoint2: NSPoint(x: 10.5, y: 6.5))
            wave1.lineWidth = 1.3
            wave1.lineCapStyle = .round
            wave1.stroke()
            
            // Stream wave 2
            let wave2 = NSBezierPath()
            wave2.move(to: NSPoint(x: 4.5, y: 5.5))
            wave2.curve(to: NSPoint(x: 13.5, y: 4.5), controlPoint1: NSPoint(x: 7.5, y: 7.5), controlPoint2: NSPoint(x: 10.5, y: 2.5))
            wave2.lineWidth = 1.2
            wave2.lineCapStyle = .round
            wave2.stroke()
            
            return true
        }
        img.isTemplate = true
        return img
    }
    
    @objc func toggleHUD() {
        if hudWindow?.isVisible == true {
            hideHUD()
        } else {
            showHUD()
        }
    }
    
    func showHUD() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        if frontApp?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontApp
        }
        
        // Notify view that window is about to appear, resetting selection to top item
        NotificationCenter.default.post(name: Notification.Name("clipstreamWindowWillShow"), object: nil)
        
        if hudWindow == nil {
            let panel = HUDPanel(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isReleasedWhenClosed = false
            
            let contentView = ClipstreamView(onDismiss: { [weak self] in
                self?.hideHUD()
            })
            panel.contentView = NSHostingView(rootView: contentView)
            hudWindow = panel
        }
        
        hudWindow?.center()
        hudWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        startMonitors()
    }
    
    @objc func hideHUD() {
        stopMonitors()
        hudWindow?.orderOut(nil)
        NSApp.hide(nil)
        
        if let prev = previousApp {
            prev.activate()
        }
    }
    
    // MARK: - Event Monitors (Click Outside & Keyboard Navigation)
    
    private func startMonitors() {
        stopMonitors()
        
        // 1. Outside click monitor: dismiss when user clicks outside HUD
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            Task { @MainActor in
                AppDelegate.shared?.hideHUD()
            }
        }
        
        // 2. Local keyboard monitor: handle Esc, Up, Down, Enter, and ⌘ 1-9
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Esc key (53)
            if event.keyCode == 53 {
                self.hideHUD()
                return nil
            }
            
            // Up Arrow (126)
            if event.keyCode == 126 {
                NotificationCenter.default.post(name: .clipstreamNavigateUp, object: nil)
                return nil
            }
            
            // Down Arrow (125)
            if event.keyCode == 125 {
                NotificationCenter.default.post(name: .clipstreamNavigateDown, object: nil)
                return nil
            }
            
            // Return / Enter key (36)
            if event.keyCode == 36 {
                NotificationCenter.default.post(name: .clipstreamPasteSelected, object: nil)
                return nil
            }
            
            // Quick Paste: 1-9 keys (when Command modifier is pressed)
            if event.modifierFlags.contains(.command),
               let chars = event.characters,
               let num = Int(chars), num >= 1, num <= 9 {
                NotificationCenter.default.post(name: .clipstreamQuickPaste, object: num - 1)
                return nil
            }
            
            return event
        }
    }
    
    private func stopMonitors() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}

/// Custom floating panel for the HUD overlay
final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func cancelOperation(_ sender: Any?) {
        AppDelegate.shared?.hideHUD()
    }
}
