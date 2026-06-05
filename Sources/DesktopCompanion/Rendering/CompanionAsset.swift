import Foundation

struct LoadedCompanionAsset {
    let markup: String
}

enum CompanionAsset {
    static let canvasSize = 220

    static var userSVGURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("DesktopCompanion", isDirectory: true)
            .appendingPathComponent("companion.svg", isDirectory: false)
    }

    static func load() -> LoadedCompanionAsset {
        if let url = userSVGURL,
           FileManager.default.fileExists(atPath: url.path),
           let markup = try? String(contentsOf: url, encoding: .utf8),
           isUsableCompanionSVG(markup) {
            return LoadedCompanionAsset(markup: markup)
        }

        if let url = Bundle.module.url(forResource: "companion", withExtension: "svg"),
           let markup = try? String(contentsOf: url, encoding: .utf8) {
            return LoadedCompanionAsset(markup: markup)
        }

        return LoadedCompanionAsset(markup: fallbackSVG)
    }

    private static func isUsableCompanionSVG(_ markup: String) -> Bool {
        markup.contains("<svg")
            && markup.range(
                of: #"viewBox\s*=\s*["']\s*0\s+0\s+220\s+220\s*["']"#,
                options: .regularExpression
            ) != nil
    }

    private static let fallbackSVG = """
    <svg viewBox="0 0 220 220" role="img" aria-label="Desktop companion">
      <rect x="52" y="52" width="116" height="116" rx="18" fill="#F7D117"/>
      <text x="110" y="118" text-anchor="middle" font-family="-apple-system, sans-serif" font-size="18" fill="#111">SVG</text>
    </svg>
    """
}
