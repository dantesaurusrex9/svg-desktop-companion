import AppKit
import ApplicationServices
import CoreGraphics

if CommandLine.arguments.contains("--diagnose-keyboard-access") {
    let canCreateTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: CGEventMask(1) << CGEventType.keyDown.rawValue,
        callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
        userInfo: nil
    )

    if let canCreateTap {
        CFMachPortInvalidate(canCreateTap)
    }

    print("bundleIdentifier=\(Bundle.main.bundleIdentifier ?? "unknown")")
    print("accessibilityTrusted=\(AXIsProcessTrusted())")
    print("keyboardEventTapAvailable=\(canCreateTap != nil)")
    exit(EXIT_SUCCESS)
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
