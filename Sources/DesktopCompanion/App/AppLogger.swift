import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.ptapayan.DesktopCompanion"

    static let input = Logger(subsystem: subsystem, category: "input")
    static let hotKey = Logger(subsystem: subsystem, category: "hotkey")
    static let conversation = Logger(subsystem: subsystem, category: "conversation")
    static let packages = Logger(subsystem: subsystem, category: "packages")
}
