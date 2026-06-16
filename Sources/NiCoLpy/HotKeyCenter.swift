import Foundation
import Carbon.HIToolbox

/// Registers a single global hotkey using the Carbon Hot Key API.
///
/// We use Carbon here because it's the lightest way to get a truly global
/// shortcut that works regardless of which app is frontmost, and it does not
/// require Accessibility permission just to register/observe the key.
final class HotKeyCenter {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handlerID = EventHotKeyID(signature: OSType(0x434C5053), id: 1) // 'CLPS'

    /// Invoked on the main thread when the hotkey fires.
    var onHotKey: (() -> Void)?

    /// Registers Cmd+Shift+V by default.
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_V),
                  modifiers: UInt32 = UInt32(cmdKey | shiftKey)) {
        unregister()

        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            handlerID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("ClipStack: failed to register hotkey (status \(status))")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Pass `self` through as user data so the C callback can call back in.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()

                var firedID = EventHotKeyID()
                let err = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &firedID
                )

                if err == noErr, firedID.id == center.handlerID.id {
                    DispatchQueue.main.async {
                        center.onHotKey?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    deinit {
        unregister()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}
