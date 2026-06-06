import AppKit
import Foundation

struct CompanionReactionFrames {
    let resting: NSImage
    let windUp: NSImage
    let strike: NSImage
    let flare: NSImage

    init(markup: String, animationPreset: CompanionAnimationPreset, renderer: (String) -> NSImage) {
        switch animationPreset {
        case .idleOnly, .wholeObjectReaction:
            resting = renderer(markup)
            windUp = renderer(markup)
            strike = renderer(markup)
            flare = renderer(markup)
        case .legoSmash:
            resting = renderer(Self.frameMarkup(from: markup, armRotation: -145, impactOpacity: 0))
            windUp = renderer(Self.frameMarkup(from: markup, armRotation: -160, impactOpacity: 0))
            strike = renderer(Self.frameMarkup(from: markup, armRotation: 15, impactOpacity: 1))
            flare = renderer(Self.frameMarkup(from: markup, armRotation: -22, impactOpacity: 1))
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
