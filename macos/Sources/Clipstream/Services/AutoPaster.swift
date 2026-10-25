import AppKit
import ApplicationServices

/// Simulates pasting into the active application by generating synthetic CGEvent keyboard events.
public struct AutoPaster {
    
    /// Copies text to the system pasteboard and simulates a ⌘ + V keystroke into the previous target application.
    @MainActor
    public static func paste(text: String, hideWindowHandler: () -> Void) {
        // 1. Write content to system pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 2. Dismiss HUD window to restore focus to previously active app
        hideWindowHandler()
        
        // 3. Small dispatch delay to allow macOS window server to switch target focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            simulateCmdV()
        }
    }
    
    /// Posts synthetic Command + V key down and key up events to the system event tap.
    private static func simulateCmdV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        
        // Key code for 'V' is 9
        let vKeyCode: CGKeyCode = 9
        
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
