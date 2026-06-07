import AppKit
import Testing
@testable import DesktopCompanion

struct ConversationThemeTests {
    @Test
    func testConversationThemeLoadsValidManifest() throws {
        let theme = try makeThemeFolder(
            manifest: """
            {
              "schemaVersion": 1,
              "id": "downloaded-cloud",
              "displayName": "Downloaded Cloud",
              "bubbleSVG": "bubble.svg",
              "width": 420,
              "minHeight": 260,
              "maxVisibleHeightRatio": 0.55,
              "contentInsets": { "top": 46, "left": 42, "bottom": 34, "right": 42 },
              "inputHeight": 36,
              "transcriptInputSpacing": 14,
              "tailAnchor": { "x": 84, "y": 14 },
              "tailFillColor": "#112233CC",
              "tailStrokeColor": "#445566"
            }
            """
        )

        #expect(theme.id == "downloaded-cloud")
        #expect(theme.displayName == "Downloaded Cloud")
        #expect(theme.metrics.width == 420)
        #expect(theme.metrics.minHeight == 260)
        #expect(theme.metrics.inputHeight == 36)
        #expect(FileManager.default.fileExists(atPath: theme.bubbleSVGURL.path))
    }

    @Test
    func testBundledConversationThemeLoadsSVGAsset() throws {
        let suiteName = "DesktopCompanionTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let theme = ConversationThemeLoader.selectedTheme(userDefaults: defaults)

        #expect(theme.id == "cloud-default")
        #expect(theme.bubbleSVGURL.lastPathComponent == "bubble.svg")
        #expect(theme.bubbleSVGURL.path.contains("ConversationThemes/cloud-default"))
        #expect(theme.metrics.width == 520)
        #expect(theme.metrics.minHeight == 118)
        #expect(theme.metrics.contentInsets.top == 20)
        #expect(theme.metrics.contentInsets.left == 18)
        #expect(theme.metrics.contentInsets.bottom == 12)
        #expect(theme.metrics.contentInsets.right == 18)
        #expect(theme.metrics.inputHeight == 36)
        #expect(theme.metrics.transcriptInputSpacing == 12)
        #expect(theme.metrics.tailAnchor == NSPoint(x: 80, y: 0))
        #expect(FileManager.default.fileExists(atPath: theme.bubbleSVGURL.path))
    }

    @Test
    func testBundledConversationBubbleSVGIsBodyOnly() throws {
        let theme = ConversationThemeLoader.selectedTheme(userDefaults: UserDefaults(suiteName: "DesktopCompanionTests-\(UUID().uuidString)") ?? .standard)
        let markup = try String(contentsOf: theme.bubbleSVGURL, encoding: .utf8)

        #expect(!markup.contains("<ellipse"))
        #expect(!markup.contains("L72 214"))
    }

    @Test
    func testConversationThemeRejectsInvalidGeometry() throws {
        #expect(throws: ConversationThemeError.invalidGeometry) {
            try makeThemeFolder(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "bad-cloud",
                  "displayName": "Bad Cloud",
                  "bubbleSVG": "bubble.svg",
                  "width": 420,
                  "minHeight": 80,
                  "maxVisibleHeightRatio": 0.55,
                  "contentInsets": { "top": 46, "left": 42, "bottom": 34, "right": 42 },
                  "inputHeight": 36,
                  "transcriptInputSpacing": 14,
                  "tailAnchor": { "x": 84, "y": 14 }
                }
                """
            )
        }
    }

    @Test
    func testConversationThemeRejectsInvalidTailColor() throws {
        #expect(throws: ConversationThemeError.invalidGeometry) {
            try makeThemeFolder(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "bad-tail-color",
                  "displayName": "Bad Tail Color",
                  "bubbleSVG": "bubble.svg",
                  "width": 420,
                  "minHeight": 260,
                  "maxVisibleHeightRatio": 0.55,
                  "contentInsets": { "top": 46, "left": 42, "bottom": 34, "right": 42 },
                  "inputHeight": 36,
                  "transcriptInputSpacing": 14,
                  "tailAnchor": { "x": 84, "y": 14 },
                  "tailFillColor": "white"
                }
                """
            )
        }
    }

    @Test
    func testConversationThemeRejectsOversizedManifest() throws {
        let padding = String(repeating: " ", count: 65_000)

        #expect(throws: ConversationThemeError.invalidManifest) {
            try makeThemeFolder(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "oversized-cloud",
                  "displayName": "Oversized Cloud",
                  "bubbleSVG": "bubble.svg",
                  "width": 420,
                  "minHeight": 260,
                  "maxVisibleHeightRatio": 0.55,
                  "contentInsets": { "top": 46, "left": 42, "bottom": 34, "right": 42 },
                  "inputHeight": 36,
                  "transcriptInputSpacing": 14,
                  "tailAnchor": { "x": 84, "y": 14 }
                }
                \(padding)
                """
            )
        }
    }

    @Test
    func testConversationThemeRejectsEscapedBubbleSVGPath() throws {
        #expect(throws: ConversationThemeError.invalidManifest) {
            try makeThemeFolder(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "escaped-cloud",
                  "displayName": "Escaped Cloud",
                  "bubbleSVG": "../bubble.svg",
                  "width": 420,
                  "minHeight": 260,
                  "maxVisibleHeightRatio": 0.55,
                  "contentInsets": { "top": 46, "left": 42, "bottom": 34, "right": 42 },
                  "inputHeight": 36,
                  "transcriptInputSpacing": 14,
                  "tailAnchor": { "x": 84, "y": 14 }
                }
                """
            )
        }
    }

    @Test
    func testConversationThemeRejectsUnsafeBubbleSVG() throws {
        #expect(throws: ConversationThemeError.invalidManifest) {
            try makeThemeFolder(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "unsafe-cloud",
                  "displayName": "Unsafe Cloud",
                  "bubbleSVG": "bubble.svg",
                  "width": 420,
                  "minHeight": 260,
                  "maxVisibleHeightRatio": 0.55,
                  "contentInsets": { "top": 46, "left": 42, "bottom": 34, "right": 42 },
                  "inputHeight": 36,
                  "transcriptInputSpacing": 14,
                  "tailAnchor": { "x": 84, "y": 14 }
                }
                """,
                bubbleSVG: #"<svg viewBox="0 0 420 300" xmlns="http://www.w3.org/2000/svg"><foreignObject x="0" y="0" width="1" height="1"/></svg>"#
            )
        }
    }

    @Test

    func testThemeStoreDefaultsToNotesDark() throws {
        let suiteName = "DesktopCompanionTheme-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        #expect(AppThemeStore.selectedPreset(userDefaults: defaults) == .notesDark)
    }

    @Test
    func testThemeStoreSavesGraphiteDark() throws {
        let suiteName = "DesktopCompanionTheme-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        AppThemeStore.save(.graphiteDark, userDefaults: defaults)

        #expect(AppThemeStore.selectedPreset(userDefaults: defaults) == .graphiteDark)
    }

    @Test
    func testThemeStoreFallsBackForInvalidValue() throws {
        let suiteName = "DesktopCompanionTheme-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("missing-theme", forKey: AppThemeStore.selectedPresetDefaultsKey)

        #expect(AppThemeStore.selectedPreset(userDefaults: defaults) == .notesDark)
    }

    @MainActor

    @Test
    func testConversationThemeSelectionIsScopedByPackage() throws {
        let suiteName = "DesktopCompanionThemes-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let packageA = testPackage(id: "package-a")
        let packageB = testPackage(id: "package-b")

        ConversationThemeLoader.saveSelectedThemeID("theme-a", package: packageA, userDefaults: defaults)
        ConversationThemeLoader.saveSelectedThemeID("theme-b", package: packageB, userDefaults: defaults)

        #expect(defaults.string(forKey: "desktopCompanion.conversationThemeID.package-a") == "theme-a")
        #expect(defaults.string(forKey: "desktopCompanion.conversationThemeID.package-b") == "theme-b")
        #expect(defaults.string(forKey: "desktopCompanion.conversationThemeID") == nil)
    }
}
