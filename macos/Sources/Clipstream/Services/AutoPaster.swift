import AppKit
import ApplicationServices

/// Simulates pasting into the previously active application by generating synthetic CGEvent keyboard events.
public struct AutoPaster {
    
    /// Copies text to the system pasteboard and simulates a ⌘ + V keystroke into the previous target application.
    @MainActor
    public static func paste(item: ClipItem, hideWindowHandler: () -> Void) {
        // 1. Accessibility Check & System Prompt
        let isTrusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)
        
        // 2. Prevent self-triggering duplicate in ClipboardManager
        ClipboardManager.shared.isPasting = true
        
        // Update history: bring this item to top without creating a duplicate
        ClipboardManager.shared.recordPaste(item: item)
        
        // Write to system pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.rawContent, forType: .string)
        ClipboardManager.shared.lastChangeCount = pasteboard.changeCount
        
        // 3. Dismiss HUD window and hide app so macOS restores focus to previously active app
        hideWindowHandler()
        
        // 4. Small delay to allow macOS window server to switch target app focus
        if isTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                simulateCmdV()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    ClipboardManager.shared.isPasting = false
                }
            }
        } else {
            ClipboardManager.shared.isPasting = false
        }
    }
    
    /// Posts synthetic Command + V key down and key up events to the system event tap.
    private static func simulateCmdV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        
        let vKeyCode: CGKeyCode = 9 // Key code for 'V'
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        
        // Apply ⌘ (Command) modifier
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // Post events to the active session
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
