import AppKit
import CoreGraphics

enum CompanionLayerMode: String, CaseIterable, Codable {
    case desktop
    case floating
    case alwaysOnTop

    var title: String {
        switch self {
        case .desktop:
            "Desktop"
        case .floating:
            "Floating"
        case .alwaysOnTop:
            "Always On Top"
        }
    }

    var windowLevel: NSWindow.Level {
        switch self {
        case .desktop:
            NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .floating:
            .floating
        case .alwaysOnTop:
            .statusBar
        }
    }
}
