import Carbon

final class GlobalHotKeyMonitor {
    private static let signature: OSType = 0x4454_4351 // DTCQ
    private static let hotKeyID = UInt32(1)

    private let onQuit: () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    init(onQuit: @escaping () -> Void) {
        self.onQuit = onQuit
    }

    func start() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr,
                      hotKeyID.signature == GlobalHotKeyMonitor.signature,
                      hotKeyID.id == GlobalHotKeyMonitor.hotKeyID else {
                    return noErr
                }

                let monitor = Unmanaged<GlobalHotKeyMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                monitor.onQuit()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard handlerStatus == noErr else {
            AppLogger.hotKey.error("Unable to install hotkey handler: \(handlerStatus)")
            return
        }

        let carbonHotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.hotKeyID
        )

        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_Q),
            UInt32(cmdKey | optionKey | controlKey),
            carbonHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if hotKeyStatus != noErr {
            AppLogger.hotKey.error("Unable to register Control-Option-Command-Q hotkey: \(hotKeyStatus)")
        }
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        stop()
    }
}
