import AppKit

enum CompanionWindowMetrics {
    static let size = NSSize(width: 220, height: 220)

    static var defaultOrigin: NSPoint {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(
            x: visibleFrame.maxX - size.width - 48,
            y: visibleFrame.minY + 72
        )
    }
}
