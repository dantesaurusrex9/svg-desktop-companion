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
    var conversationBubbleSize: ConversationBubbleSize? = nil
    var conversationBubbleOffset: CompanionAnchor? = nil

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
            layerMode: .alwaysOnTop,
            speechAnchor: CompanionAnchor(point: package.speechAnchor),
            bubblePlacement: package.bubblePlacement,
            animationPreset: package.animationPreset
        )
    }
}

extension CompanionInstance {
    private enum CodingKeys: String, CodingKey {
        case id
        case packageID
        case origin
        case layerMode
        case speechAnchor
        case bubblePlacement
        case animationPreset
        case conversationBubbleSize
        case conversationBubbleOffset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        packageID = try container.decode(String.self, forKey: .packageID)
        origin = try container.decode(CompanionAnchor.self, forKey: .origin)
        layerMode = try container.decode(CompanionLayerMode.self, forKey: .layerMode)
        speechAnchor = try container.decode(CompanionAnchor.self, forKey: .speechAnchor)
        bubblePlacement = try container.decode(CompanionBubblePlacement.self, forKey: .bubblePlacement)
        animationPreset = try container.decode(CompanionAnimationPreset.self, forKey: .animationPreset)
        conversationBubbleSize = (try? container.decodeIfPresent(
            ConversationBubbleSize.self,
            forKey: .conversationBubbleSize
        ))?.usableValue
        conversationBubbleOffset = Self.usableOffset(
            try? container.decodeIfPresent(CompanionAnchor.self, forKey: .conversationBubbleOffset)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(packageID, forKey: .packageID)
        try container.encode(origin, forKey: .origin)
        try container.encode(layerMode, forKey: .layerMode)
        try container.encode(speechAnchor, forKey: .speechAnchor)
        try container.encode(bubblePlacement, forKey: .bubblePlacement)
        try container.encode(animationPreset, forKey: .animationPreset)
        try container.encodeIfPresent(conversationBubbleSize?.usableValue, forKey: .conversationBubbleSize)
        try container.encodeIfPresent(Self.usableOffset(conversationBubbleOffset), forKey: .conversationBubbleOffset)
    }

    private static func usableOffset(_ offset: CompanionAnchor?) -> CompanionAnchor? {
        guard let offset,
              offset.x.isFinite,
              offset.y.isFinite else {
            return nil
        }

        return offset
    }
}

struct ConversationBubbleSize: Codable, Equatable {
    var width: CGFloat
    var height: CGFloat

    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    init(size: NSSize) {
        self.width = size.width
        self.height = size.height
    }

    var size: NSSize {
        NSSize(width: width, height: height)
    }

    var usableValue: ConversationBubbleSize? {
        guard width.isFinite,
              height.isFinite,
              width > 0,
              height > 0 else {
            return nil
        }

        return self
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
