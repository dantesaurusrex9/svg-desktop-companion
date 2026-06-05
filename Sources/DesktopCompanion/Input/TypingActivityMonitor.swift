import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class TypingActivityMonitor {
    private let onTyping: @MainActor () -> Void
    private let onKeyboardAccessChanged: @MainActor (Bool) -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var eventTapRetryTimer: Timer?
    private var didLogEventTapFailure = false
    private var lastDeliveredKeyDown = Date.distantPast
    private let duplicateEventWindow: TimeInterval = 0.025

    init(
        onTyping: @escaping @MainActor () -> Void,
        onKeyboardAccessChanged: @escaping @MainActor (Bool) -> Void
    ) {
        self.onTyping = onTyping
        self.onKeyboardAccessChanged = onKeyboardAccessChanged
    }

    func start() {
        stop()
        onKeyboardAccessChanged(requestAccessibilityIfNeeded())
        startFallbackMonitors()
        startEventTap()
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
            self.eventTapRunLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        eventTapRetryTimer?.invalidate()
        eventTapRetryTimer = nil
    }

    fileprivate func handleEventTap(type: CGEventType) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        guard type == .keyDown else {
            return
        }

        handleKeyDown()
    }

    private func startEventTap() {
        guard eventTap == nil else {
            return
        }

        let keyDownMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: keyDownMask,
            callback: typingActivityEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            if !didLogEventTapFailure {
                AppLogger.input.error("Unable to create keyboard event tap; grant Accessibility permission to enable typing reactions")
                didLogEventTapFailure = true
            }
            onKeyboardAccessChanged(false)
            startFallbackMonitors()
            scheduleEventTapRetry()
            return
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            AppLogger.input.error("Unable to create keyboard event tap run loop source")
            onKeyboardAccessChanged(false)
            return
        }

        eventTap = tap
        eventTapRunLoopSource = runLoopSource
        eventTapRetryTimer?.invalidate()
        eventTapRetryTimer = nil
        didLogEventTapFailure = false
        onKeyboardAccessChanged(true)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func scheduleEventTapRetry() {
        guard eventTapRetryTimer == nil else {
            return
        }

        eventTapRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.startEventTap()
            }
        }
    }

    private func startFallbackMonitors() {
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleKeyDown()
                }
            }
        }

        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleKeyDown()
                }
                return event
            }
        }
    }

    private func stopFallbackMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    fileprivate func handleKeyDown() {
        let now = Date()
        guard now.timeIntervalSince(lastDeliveredKeyDown) >= duplicateEventWindow else {
            return
        }

        lastDeliveredKeyDown = now
        onTyping()
    }

    private func requestAccessibilityIfNeeded() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        if !AXIsProcessTrustedWithOptions(options) {
            AppLogger.input.info("Accessibility permission is needed for global typing animation triggers")
            return false
        }

        return true
    }
}

private let typingActivityEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<TypingActivityMonitor>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    Task { @MainActor in
        monitor.handleEventTap(type: type)
    }

    return Unmanaged.passUnretained(event)
}
