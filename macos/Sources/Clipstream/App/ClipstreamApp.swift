import SwiftUI
import SwiftData
import AppKit

@main
struct ClipstreamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([ClipItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hudWindow: NSPanel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure menu bar item
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
            button.image = NSImage(systemSymbolName: "paperclip.badge.ellipsis", accessibilityDescription: "Clipstream")
            button.action = #selector(toggleHUD)
            button.target = self
        }
    }
    
    @objc func toggleHUD() {
        if hudWindow?.isVisible == true {
            hudWindow?.orderOut(nil)
        } else {
            showHUD()
        }
    }
    
    private func showHUD() {
        if hudWindow == nil {
            let panel = NSPanel(
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
            
            let contentView = ClipstreamView(onDismiss: { [weak panel] in
                panel?.orderOut(nil)
            })
            panel.contentView = NSHostingView(rootView: contentView)
            hudWindow = panel
        }
        
        hudWindow?.center()
        hudWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
