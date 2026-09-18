import AppKit
import Carbon
import OSLog

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    public var onHotKeyTriggered: (@MainActor () -> Void)?

    private init() {}

    /// Registers a global hotkey. Default: Control + Option + C
    public func registerDefaultHotKey(onTrigger: @escaping @MainActor () -> Void) {
        self.onHotKeyTriggered = onTrigger

        // Unregister previous if any
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install Carbon Event Handler
        let handlerResult = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, _) -> OSStatus in
                Task { @MainActor in
                    HotKeyManager.shared.handleHotKeyEvent()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard handlerResult == noErr else {
            AppLog.app.error("Failed to install Carbon event handler: \(handlerResult, privacy: .public)")
            return
        }

        // Register Control + Option + C (kVK_ANSI_C = 0x08)
        let hotKeyID = EventHotKeyID(signature: 0x434F5645, id: 1) // 'COVE', 1
        let modifiers: UInt32 = UInt32(controlKey | optionKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_C)

        let registerResult = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if registerResult == noErr {
            AppLog.app.info("Global hotkey Control+Option+C registered successfully")
        } else {
            AppLog.app.error("Failed to register global hotkey: \(registerResult, privacy: .public)")
        }
    }

    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    private func handleHotKeyEvent() {
        AppLog.app.info("Global hotkey triggered")
        onHotKeyTriggered?()
    }
}
