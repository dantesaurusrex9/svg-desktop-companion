import AppKit
import Foundation

struct CompanionInstance: Codable, Equatable {
    var id: String
    var packageID: String
    var origin: CompanionAnchor
    var layerMode: CompanionLayerMode
    var speechAnchor: CompanionAnchor
    var bubblePlacement: CompanionBubblePlacement
    var animationPreset: CompanionAnimationPreset

    var originPoint: NSPoint {
        get {
            origin.point
        }
        set {
            origin = CompanionAnchor(point: newValue)
        }
    }

    var speechAnchorPoint: NSPoint {
        get {
            speechAnchor.point
        }
        set {
            speechAnchor = CompanionAnchor(point: newValue)
        }
    }

    static func make(package: CompanionPackage, existingCount: Int) -> CompanionInstance {
        let baseOrigin = CompanionWindowMetrics.defaultOrigin
        let offset = CGFloat(existingCount % 6) * 28
        return CompanionInstance(
            id: UUID().uuidString,
            packageID: package.id,
            origin: CompanionAnchor(point: NSPoint(x: baseOrigin.x - offset, y: baseOrigin.y + offset)),
            layerMode: .desktop,
            speechAnchor: CompanionAnchor(point: package.speechAnchor),
            bubblePlacement: package.bubblePlacement,
            animationPreset: package.animationPreset
        )
    }
}

enum CompanionInstanceStore {
    private static let key = "desktopCompanion.instances"

    static func load(userDefaults: UserDefaults = .standard) -> [CompanionInstance] {
        guard let data = userDefaults.data(forKey: key),
              let instances = try? JSONDecoder().decode([CompanionInstance].self, from: data) else {
            return []
        }

        return instances
    }

    static func save(_ instances: [CompanionInstance], userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(instances) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }
}
