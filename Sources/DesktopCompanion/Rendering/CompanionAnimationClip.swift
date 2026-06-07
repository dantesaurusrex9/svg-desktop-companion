import AppKit
import Foundation
import QuartzCore

struct CompanionAnimationFrame {
    let image: NSImage
    let delay: TimeInterval
}

struct CompanionAnimationClip {
    let resting: NSImage
    let frames: [CompanionAnimationFrame]
    let duration: TimeInterval
    let layerAnimation: CAKeyframeAnimation?

    var isEmpty: Bool {
        frames.isEmpty && layerAnimation == nil
    }

    static func states(for preset: CompanionAnimationPreset) -> [CompanionAnimationState] {
        switch preset {
        case .idleOnly:
            []
        case .wholeObjectReaction, .legoSmash:
            CompanionAnimationState.allCases
        }
    }

    static func clip(
        markup: String,
        preset: CompanionAnimationPreset,
        state: CompanionAnimationState,
        renderer: (String) -> NSImage
    ) -> CompanionAnimationClip? {
        guard states(for: preset).contains(state) else {
            return nil
        }

        switch state {
        case .typing:
            return typingClip(markup: markup, preset: preset, renderer: renderer)
        case .thinking:
            return thinkingClip(markup: markup, preset: preset, renderer: renderer)
        }
    }

    private static func typingClip(
        markup: String,
        preset: CompanionAnimationPreset,
        renderer: (String) -> NSImage
    ) -> CompanionAnimationClip {
        let restingMarkup = restingMarkup(from: markup, preset: preset)
        let windUpMarkup: String
        let strikeMarkup: String
        let flareMarkup: String

        switch preset {
        case .idleOnly, .wholeObjectReaction:
            windUpMarkup = markup
            strikeMarkup = markup
            flareMarkup = markup
        case .legoSmash:
            windUpMarkup = frameMarkup(from: markup, armRotation: -160, impactOpacity: 0)
            strikeMarkup = frameMarkup(from: markup, armRotation: 15, impactOpacity: 1)
            flareMarkup = frameMarkup(from: markup, armRotation: -22, impactOpacity: 1)
        }

        return CompanionAnimationClip(
            resting: renderer(restingMarkup),
            frames: [
                CompanionAnimationFrame(image: renderer(windUpMarkup), delay: 0),
                CompanionAnimationFrame(image: renderer(strikeMarkup), delay: 0.07),
                CompanionAnimationFrame(image: renderer(flareMarkup), delay: 0.16)
            ],
            duration: 0.30,
            layerAnimation: typingLayerAnimation()
        )
    }

    private static func thinkingClip(
        markup: String,
        preset: CompanionAnimationPreset,
        renderer: (String) -> NSImage
    ) -> CompanionAnimationClip {
        let restingMarkup = restingMarkup(from: markup, preset: preset)
        return CompanionAnimationClip(
            resting: renderer(restingMarkup),
            frames: [CompanionAnimationFrame(image: renderer(restingMarkup), delay: 0)],
            duration: 1.25,
            layerAnimation: thinkingLayerAnimation()
        )
    }

    static func restingMarkup(from markup: String, preset: CompanionAnimationPreset) -> String {
        switch preset {
        case .idleOnly, .wholeObjectReaction:
            markup
        case .legoSmash:
            frameMarkup(from: markup, armRotation: -145, impactOpacity: 0)
        }
    }

    private static func frameMarkup(from markup: String, armRotation: Int, impactOpacity: Int) -> String {
        var frame = markup
        frame = setGroupAttribute(
            in: frame,
            className: "lego-smash-arm",
            attributeName: "transform",
            value: "rotate(\(armRotation) 88 116)"
        )
        frame = setGroupAttribute(
            in: frame,
            className: "floor-crack",
            attributeName: "opacity",
            value: "\(impactOpacity)"
        )
        frame = setGroupAttribute(
            in: frame,
            className: "impact-lines",
            attributeName: "opacity",
            value: "\(impactOpacity)"
        )
        frame = setGroupAttribute(
            in: frame,
            className: "pixel-fire",
            attributeName: "opacity",
            value: "\(impactOpacity)"
        )
        frame = setGroupAttribute(
            in: frame,
            className: "pixel-sparks",
            attributeName: "opacity",
            value: "\(impactOpacity)"
        )
        return frame
    }

    private static func typingLayerAnimation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = [
            transform(y: 0, rotation: 0, scaleY: 1),
            transform(y: -10, rotation: 3, scaleY: 1),
            transform(y: 19, rotation: -5, scaleY: 0.94),
            transform(y: 0, rotation: 0, scaleY: 1)
        ]
        animation.keyTimes = [0, 0.2, 0.48, 1]
        animation.duration = 0.30
        animation.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.18, 0.9, 0.28, 1),
            CAMediaTimingFunction(controlPoints: 0.22, 0.84, 0.26, 1),
            CAMediaTimingFunction(name: .easeOut)
        ]
        return animation
    }

    private static func thinkingLayerAnimation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = [
            transform(y: 0, rotation: 0, scaleY: 1),
            transform(y: -7, rotation: -2, scaleY: 1.02),
            transform(y: -2, rotation: 2, scaleY: 0.99),
            transform(y: -5, rotation: -1, scaleY: 1.01),
            transform(y: 0, rotation: 0, scaleY: 1)
        ]
        animation.keyTimes = [0, 0.24, 0.52, 0.76, 1]
        animation.duration = 1.25
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        return animation
    }

    private static func transform(y: CGFloat, rotation degrees: CGFloat, scaleY: CGFloat) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, 0, y, 0)
        transform = CATransform3DRotate(transform, degrees * .pi / 180, 0, 0, 1)
        transform = CATransform3DScale(transform, 1, scaleY, 1)
        return transform
    }

    private static func setGroupAttribute(
        in markup: String,
        className: String,
        attributeName: String,
        value: String
    ) -> String {
        let escapedClassName = NSRegularExpression.escapedPattern(for: className)
        let pattern = #"<g\b(?=[^>]*\bclass=["'][^"']*\b"# + escapedClassName + #"\b[^"']*["'])[^>]*>"#

        guard let groupRegex = try? NSRegularExpression(pattern: pattern) else {
            return markup
        }

        let matches = groupRegex.matches(
            in: markup,
            range: NSRange(markup.startIndex..<markup.endIndex, in: markup)
        )

        guard !matches.isEmpty else {
            return markup
        }

        let attributePattern = #"\s+"# + NSRegularExpression.escapedPattern(for: attributeName) + #"=["'][^"']*["']"#
        var updatedMarkup = markup
        for match in matches.reversed() {
            guard let range = Range(match.range, in: updatedMarkup) else {
                continue
            }

            let originalTag = String(updatedMarkup[range])
            let trimmedTag = String(originalTag.dropLast())
            let cleanedTag = trimmedTag.replacingOccurrences(
                of: attributePattern,
                with: "",
                options: .regularExpression
            )
            updatedMarkup.replaceSubrange(range, with: #"\#(cleanedTag) \#(attributeName)="\#(value)">"#)
        }

        return updatedMarkup
    }
}
