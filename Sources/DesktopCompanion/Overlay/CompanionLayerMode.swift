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

enum CompanionLayerModeStore {
    private static let key = "desktopCompanion.layerMode"

    static func load() -> CompanionLayerMode {
        guard let rawValue = UserDefaults.standard.string(forKey: key),
              let layerMode = CompanionLayerMode(rawValue: rawValue) else {
            return .desktop
        }

        return layerMode
    }

    static func save(_ layerMode: CompanionLayerMode) {
        UserDefaults.standard.set(layerMode.rawValue, forKey: key)
    }
}
