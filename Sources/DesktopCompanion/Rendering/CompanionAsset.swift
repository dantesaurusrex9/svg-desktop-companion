import AppKit
import Foundation

struct LoadedCompanionAsset {
    let markup: String
    let mouthAnchor: NSPoint
    let animationPreset: CompanionAnimationPreset
}

enum CompanionAsset {
    static let canvasSize = 220
    static let defaultMouthAnchor = NSPoint(x: 121, y: 94)
    static let maxSVGByteCount = 1_000_000

    static var userSVGURL: URL? {
        CompanionPackageLoader.legacyUserSVGURL
    }

    static func load(package: CompanionPackage? = CompanionPackageLoader.selectedPackage()) -> LoadedCompanionAsset {
        if let package,
           let asset = loadAsset(from: package.svgURL) {
            return LoadedCompanionAsset(
                markup: asset.markup,
                mouthAnchor: package.speechAnchor,
                animationPreset: package.animationPreset
            )
        }

        if package == nil,
           let url = userSVGURL,
           let asset = loadAsset(from: url) {
            return asset
        }

        if let url = Bundle.module.url(forResource: "companion", withExtension: "svg"),
           let asset = loadAsset(from: url) {
            return asset
        }

        return LoadedCompanionAsset(
            markup: fallbackSVG,
            mouthAnchor: mouthAnchor(from: fallbackSVG),
            animationPreset: .wholeObjectReaction
        )
    }

    static func mouthAnchor(from markup: String) -> NSPoint {
        if let anchor = attributeValue(named: "data-mouth-anchor", in: markup)
            .flatMap(pointValue),
            isValid(anchor) {
            return anchor
        }

        if let x = attributeValue(named: "data-mouth-x", in: markup).flatMap(numberValue),
           let y = attributeValue(named: "data-mouth-y", in: markup).flatMap(numberValue) {
            let anchor = NSPoint(x: x, y: y)
            if isValid(anchor) {
                return anchor
            }
        }

        return defaultMouthAnchor
    }

    static func isUsableCompanionSVG(_ markup: String) -> Bool {
        isSafeSVGMarkup(markup)
            && markup.range(
                of: #"viewBox\s*=\s*["']\s*0\s+0\s+220\s+220\s*["']"#,
                options: .regularExpression
            ) != nil
    }

    static func isSafeSVGMarkup(_ markup: String) -> Bool {
        guard markup.utf8.count <= maxSVGByteCount,
              markup.range(of: #"<svg\b"#, options: [.regularExpression, .caseInsensitive]) != nil,
              !matchesAnyUnsafePattern(in: markup),
              !hasUnsafeReference(in: markup, attributeName: "href"),
              !hasUnsafeReference(in: markup, attributeName: "xlink:href"),
              !hasCSSImport(in: markup),
              !hasUnsafeCSSURL(in: markup) else {
            return false
        }

        return true
    }

    static func safeSVGMarkup(from url: URL, fileManager: FileManager = .default) throws -> String {
        let data: Data
        do {
            data = try BoundedFileReader.data(from: url, maxBytes: UInt64(maxSVGByteCount), fileManager: fileManager)
        } catch BoundedFileReaderError.fileTooLarge {
            throw CompanionPackageError.invalidManifest
        } catch {
            throw error
        }

        guard let markup = String(data: data, encoding: .utf8),
              isSafeSVGMarkup(markup) else {
            throw CompanionPackageError.invalidManifest
        }

        return markup
    }

    static func isValidAnchor(_ anchor: NSPoint) -> Bool {
        isValid(anchor)
    }

    private static func loadAsset(from url: URL) -> LoadedCompanionAsset? {
        guard let markup = try? safeSVGMarkup(from: url),
              isUsableCompanionSVG(markup) else {
            return nil
        }

        return LoadedCompanionAsset(
            markup: markup,
            mouthAnchor: mouthAnchor(from: markup),
            animationPreset: .wholeObjectReaction
        )
    }

    private static func attributeValue(named name: String, in markup: String) -> String? {
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: name))\s*=\s*["']([^"']+)["']"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: markup, range: NSRange(markup.startIndex..., in: markup)),
              let range = Range(match.range(at: 1), in: markup) else {
            return nil
        }

        return String(markup[range])
    }

    private static func pointValue(_ value: String) -> NSPoint? {
        let parts = value.split { character in
            character == "," || character == " " || character == "\t" || character == "\n"
        }
        guard parts.count == 2,
              let x = numberValue(String(parts[0])),
              let y = numberValue(String(parts[1])) else {
            return nil
        }

        return NSPoint(x: x, y: y)
    }

    private static func numberValue(_ value: String) -> CGFloat? {
        guard let number = Double(value) else {
            return nil
        }

        return CGFloat(number)
    }

    private static func matchesAnyUnsafePattern(in markup: String) -> Bool {
        let patterns = [
            #"<!DOCTYPE\b"#,
            #"<!ENTITY\b"#,
            #"<script\b"#,
            #"<foreignObject\b"#,
            #"\son[a-zA-Z]+\s*="#
        ]

        return patterns.contains { pattern in
            markup.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func hasUnsafeReference(in markup: String, attributeName: String) -> Bool {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: attributeName) + #"\s*=\s*["']([^"']*)["']"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return true
        }

        let matches = expression.matches(in: markup, range: NSRange(markup.startIndex..., in: markup))
        for match in matches {
            guard let range = Range(match.range(at: 1), in: markup) else {
                return true
            }

            let value = markup[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.hasPrefix("#") {
                return true
            }
        }

        return false
    }

    private static func hasUnsafeCSSURL(in markup: String) -> Bool {
        let pattern = #"url\(\s*['"]?([^'")\s]+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return true
        }

        let matches = expression.matches(in: markup, range: NSRange(markup.startIndex..., in: markup))
        for match in matches {
            guard let range = Range(match.range(at: 1), in: markup) else {
                return true
            }

            let value = markup[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.hasPrefix("#") {
                return true
            }
        }

        return false
    }

    private static func hasCSSImport(in markup: String) -> Bool {
        markup.range(of: #"@import\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isValid(_ anchor: NSPoint) -> Bool {
        anchor.x >= 0
            && anchor.y >= 0
            && anchor.x <= CGFloat(canvasSize)
            && anchor.y <= CGFloat(canvasSize)
    }

    private static let fallbackSVG = """
    <svg viewBox="0 0 220 220" data-mouth-anchor="110 118" role="img" aria-label="Desktop companion">
      <rect x="52" y="52" width="116" height="116" rx="18" fill="#F7D117"/>
      <text x="110" y="118" text-anchor="middle" font-family="-apple-system, sans-serif" font-size="18" fill="#111">SVG</text>
    </svg>
    """
}
