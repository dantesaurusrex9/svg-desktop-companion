import OSLog

enum AppLogger {
    static let input = Logger(subsystem: "com.ptapayan.DesktopCompanion", category: "input")
    static let hotKey = Logger(subsystem: "com.ptapayan.DesktopCompanion", category: "hotkey")
}
