import AppKit
import Carbon

/// Registers and manages global system hotkeys using Carbon EventHotKey API.
/// Defaults to Cmd + Shift + V for toggling Clipstream's floating HUD.
public final class HotKeyManager {
    public static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    public var onHotKeyTriggered: (() -> Void)?
    
    private init() {}
    
    /// Registers the default global hotkey: ⌘ + ⇧ + V (KeyCode: 9 for 'V')
    public func registerDefaultHotKey() {
        unregisterHotKey()
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // 'CLIP', 1
        let modifiers = UInt32(cmdKey | shiftKey)
        let keyCode = UInt32(kVK_ANSI_V) // 'V' key
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerCallback: EventHandlerUPP = { _, event, _ -> OSStatus in
            HotKeyManager.shared.onHotKeyTriggered?()
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handlerCallback, 1, &eventType, nil, &eventHandler)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    public func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    deinit {
        unregisterHotKey()
    }
}
