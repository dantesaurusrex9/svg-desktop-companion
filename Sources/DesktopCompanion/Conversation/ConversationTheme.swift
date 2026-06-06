import AppKit
import Foundation

struct ConversationTheme: Equatable {
    let id: String
    let displayName: String
    let folderURL: URL
    let bubbleSVGURL: URL
    let metrics: ConversationBubbleMetrics
    let tailStyle: ConversationTailStyle

    var bubbleImage: NSImage {
        NSImage(contentsOf: bubbleSVGURL) ?? Self.defaultBubbleImage(size: defaultImageSize)
    }

    private var defaultImageSize: NSSize {
        NSSize(width: metrics.width, height: metrics.minHeight)
    }

    private static func defaultBubbleImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let bodyRect = NSRect(x: 18, y: 30, width: max(size.width - 36, 1), height: max(size.height - 60, 1))
        let bubble = NSBezierPath(roundedRect: bodyRect, xRadius: 30, yRadius: 30)

        NSColor.white.withAlphaComponent(0.96).setFill()
        bubble.fill()

        NSColor.black.withAlphaComponent(0.12).setStroke()
        bubble.lineWidth = 1
        bubble.stroke()

        image.unlockFocus()
        return image
    }
}

struct ConversationTailStyle: Equatable {
    static let defaultFill = "#FFFFFFF5"
    static let defaultStroke = "#0000001F"
    static let defaultStyle = ConversationTailStyle(fill: defaultFill, stroke: defaultStroke)

    let fill: String
    let stroke: String

    var fillColor: NSColor {
        Self.color(from: fill) ?? NSColor.white.withAlphaComponent(0.96)
    }

    var strokeColor: NSColor {
        Self.color(from: stroke) ?? NSColor.black.withAlphaComponent(0.12)
    }

    static func isValid(_ value: String) -> Bool {
        color(from: value) != nil
    }

    private static func color(from value: String) -> NSColor? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else {
            return nil
        }

        let hex = String(trimmed.dropFirst())
        guard (hex.count == 6 || hex.count == 8),
              let number = UInt64(hex, radix: 16) else {
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        if hex.count == 6 {
            red = component(number, shift: 16)
            green = component(number, shift: 8)
            blue = component(number, shift: 0)
            alpha = 1
        } else {
            red = component(number, shift: 24)
            green = component(number, shift: 16)
            blue = component(number, shift: 8)
            alpha = component(number, shift: 0)
        }

        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    private static func component(_ number: UInt64, shift: Int) -> CGFloat {
        CGFloat((number >> UInt64(shift)) & 0xFF) / 255
    }
}

struct ConversationThemeSummary: Equatable {
    let id: String
    let displayName: String
}

enum ConversationThemeLoader {
    static let bundledThemeID = "cloud-default"
    static let selectedThemeDefaultsKey = "desktopCompanion.conversationThemeID"

    static var userThemesDirectory: URL? {
        DesktopCompanionPaths.applicationSupportDirectoryURL?
            .appendingPathComponent("ConversationThemes", isDirectory: true)
    }

    static func selectedTheme(
        package: CompanionPackage? = CompanionPackageLoader.selectedPackage(),
        userDefaults: UserDefaults = .standard
    ) -> ConversationTheme {
        let themes = availableThemes(package: package)
        if let selectedID = userDefaults.string(forKey: selectedThemeDefaultsKey(package: package)),
           let selectedTheme = themes.first(where: { $0.id == selectedID }) {
            return selectedTheme
        }

        if package != nil,
           let selectedID = userDefaults.string(forKey: selectedThemeDefaultsKey),
           let selectedTheme = themes.first(where: { $0.id == selectedID }) {
            return selectedTheme
        }

        return themes.first ?? fallbackTheme()
    }

    static func saveSelectedThemeID(
        _ themeID: String,
        package: CompanionPackage? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(themeID, forKey: selectedThemeDefaultsKey(package: package))
    }

    static func availableThemeSummaries() -> [ConversationThemeSummary] {
        availableThemes().map {
            ConversationThemeSummary(id: $0.id, displayName: $0.displayName)
        }
    }

    static func availableThemeSummaries(package: CompanionPackage?) -> [ConversationThemeSummary] {
        availableThemes(package: package).map {
            ConversationThemeSummary(id: $0.id, displayName: $0.displayName)
        }
    }

    static func availableThemes(package: CompanionPackage? = CompanionPackageLoader.selectedPackage()) -> [ConversationTheme] {
        var themes = packageThemes(package: package)
        themes.append(bundledTheme())
        themes.append(contentsOf: userThemes())

        return themes.reduce(into: []) { uniqueThemes, theme in
            if !uniqueThemes.contains(where: { $0.id == theme.id }) {
                uniqueThemes.append(theme)
            }
        }
    }

    static func loadTheme(from folderURL: URL, fileManager: FileManager = .default) throws -> ConversationTheme {
        let manifestURL = folderURL.appendingPathComponent("theme.json", isDirectory: false)
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(ConversationThemeManifest.self, from: manifestData)

        guard manifest.schemaVersion == 1,
              !manifest.id.isEmpty,
              !manifest.displayName.isEmpty,
              let bubbleSVGURL = CompanionPackageLoader.childURL(named: manifest.bubbleSVG, in: folderURL, isDirectory: false),
              (try? CompanionAsset.safeSVGMarkup(from: bubbleSVGURL, fileManager: fileManager)) != nil,
              manifest.width > 0,
              manifest.minHeight > 0,
              manifest.inputHeight > 0,
              manifest.maxVisibleHeightRatio > 0,
              manifest.maxVisibleHeightRatio <= 1,
              fileManager.fileExists(atPath: bubbleSVGURL.path) else {
            throw ConversationThemeError.invalidManifest
        }

        let insets = manifest.contentInsets.edgeInsets
        let tailAnchor = NSPoint(x: manifest.tailAnchor.x, y: manifest.tailAnchor.y)
        let tailStyle = ConversationTailStyle(
            fill: manifest.tailFillColor ?? ConversationTailStyle.defaultFill,
            stroke: manifest.tailStrokeColor ?? ConversationTailStyle.defaultStroke
        )
        let metrics = ConversationBubbleMetrics(
            width: manifest.width,
            minHeight: manifest.minHeight,
            maxVisibleHeightRatio: manifest.maxVisibleHeightRatio,
            contentInsets: insets,
            inputHeight: manifest.inputHeight,
            transcriptInputSpacing: manifest.transcriptInputSpacing,
            tailAnchor: tailAnchor
        )

        guard insets.left >= 0,
              insets.right >= 0,
              insets.top >= 0,
              insets.bottom >= 0,
              manifest.transcriptInputSpacing >= 0,
              insets.left + insets.right < manifest.width,
              insets.top + insets.bottom + manifest.inputHeight + manifest.transcriptInputSpacing < manifest.minHeight,
              tailAnchor.x >= 0,
              tailAnchor.y >= 0,
              tailAnchor.x <= manifest.width,
              tailAnchor.y <= manifest.minHeight,
              ConversationTailStyle.isValid(tailStyle.fill),
              ConversationTailStyle.isValid(tailStyle.stroke) else {
            throw ConversationThemeError.invalidGeometry
        }

        return ConversationTheme(
            id: manifest.id,
            displayName: manifest.displayName,
            folderURL: folderURL,
            bubbleSVGURL: bubbleSVGURL,
            metrics: metrics,
            tailStyle: tailStyle
        )
    }

    private static func bundledTheme() -> ConversationTheme {
        if let folderURL = Bundle.module.resourceURL?
            .appendingPathComponent("ConversationThemes", isDirectory: true)
            .appendingPathComponent(bundledThemeID, isDirectory: true),
           let theme = try? loadTheme(from: folderURL) {
            return theme
        }

        if let folderURL = Bundle.module.resourceURL,
           let theme = try? loadTheme(from: folderURL) {
            return theme
        }

        return fallbackTheme()
    }

    private static func packageThemes(package: CompanionPackage?, fileManager: FileManager = .default) -> [ConversationTheme] {
        guard let packageThemesDirectory = package?.conversationThemesDirectoryURL else {
            return []
        }

        return themes(in: packageThemesDirectory, fileManager: fileManager)
    }

    private static func userThemes(fileManager: FileManager = .default) -> [ConversationTheme] {
        guard let userThemesDirectory else {
            return []
        }

        return themes(in: userThemesDirectory, fileManager: fileManager)
    }

    static func themes(in directoryURL: URL, fileManager: FileManager = .default) -> [ConversationTheme] {
        guard let folderURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return folderURLs
            .filter { isDirectory($0) }
            .compactMap { folderURL in
                do {
                    return try loadTheme(from: folderURL)
                } catch {
                    AppLogger.conversation.error("Ignoring invalid conversation theme: \(folderURL.lastPathComponent, privacy: .public)")
                    return nil
                }
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func selectedThemeDefaultsKey(package: CompanionPackage?) -> String {
        guard let packageID = package?.id else {
            return selectedThemeDefaultsKey
        }

        return "\(selectedThemeDefaultsKey).\(packageID)"
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func fallbackTheme() -> ConversationTheme {
        ConversationTheme(
            id: bundledThemeID,
            displayName: "Cloud Default",
            folderURL: URL(fileURLWithPath: "/"),
            bubbleSVGURL: URL(fileURLWithPath: "/"),
            metrics: ConversationBubbleMetrics(
                width: 520,
                minHeight: 300,
                maxVisibleHeightRatio: 0.5,
                contentInsets: NSEdgeInsets(top: 42, left: 42, bottom: 30, right: 42),
                inputHeight: 42,
                transcriptInputSpacing: 16,
                tailAnchor: NSPoint(x: 94, y: 0)
            ),
            tailStyle: .defaultStyle
        )
    }
}

enum ConversationThemeError: Error, Equatable {
    case invalidManifest
    case invalidGeometry
}

private struct ConversationThemeManifest: Decodable {
    let schemaVersion: Int
    let id: String
    let displayName: String
    let bubbleSVG: String
    let width: CGFloat
    let minHeight: CGFloat
    let maxVisibleHeightRatio: CGFloat
    let contentInsets: Insets
    let inputHeight: CGFloat
    let transcriptInputSpacing: CGFloat
    let tailAnchor: Point
    let tailFillColor: String?
    let tailStrokeColor: String?

    struct Insets: Decodable {
        let top: CGFloat
        let left: CGFloat
        let bottom: CGFloat
        let right: CGFloat

        var edgeInsets: NSEdgeInsets {
            NSEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        }
    }

    struct Point: Decodable {
        let x: CGFloat
        let y: CGFloat
    }
}
