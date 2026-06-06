import AppKit
import Testing
@testable import DesktopCompanion

struct CodexConversationCommandTests {
    @MainActor
    @Test
    func testCompanionContextMenuContainsConversate() {
        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ) else {
            Issue.record("Could not create right-click event")
            return
        }

        let view = CompanionContentView(frame: NSRect(origin: .zero, size: CompanionWindowMetrics.size))
        view.conversationThemes = [
            ConversationThemeSummary(id: "cloud-default", displayName: "Cloud Default")
        ]
        view.selectedConversationThemeID = "cloud-default"
        let menu = view.menu(for: event)

        #expect(menu?.items.contains { $0.title == "Conversate" } == true)
        #expect(menu?.items.contains { $0.title == "Reload Bubble Theme" } == true)
        #expect(menu?.items.first(where: { $0.title == "Bubble Theme" })?.submenu?.items.count == 1)
    }

    @MainActor
    @Test
    func testCompanionDragOriginTracksScreenDelta() {
        let origin = CompanionContentView.draggedWindowOrigin(
            dragStartScreenPoint: NSPoint(x: 100, y: 200),
            currentScreenPoint: NSPoint(x: 125, y: 178),
            dragStartWindowOrigin: NSPoint(x: 40, y: 90)
        )

        #expect(origin == NSPoint(x: 65, y: 68))
    }

    @MainActor
    @Test
    func testConversationFrameAnchorsTailToMouthPoint() throws {
        let theme = try makeThemeFolder(
            manifest: """
            {
              "schemaVersion": 1,
              "id": "test-cloud",
              "displayName": "Test Cloud",
              "bubbleSVG": "bubble.svg",
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

        let frame = ConversationBubbleWindowController.frame(
            anchoredAt: NSPoint(x: 300, y: 200),
            theme: theme,
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(frame.origin == NSPoint(x: 216, y: 182))
    }

    @Test
    func testConversationLayoutUsesMinimumHeightForShortContent() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 24,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(layout.size == NSSize(width: 360, height: 190))
        #expect(!layout.isTranscriptScrollable)
        #expect(layout.inputRect.maxY == 164)
        #expect(layout.inputRect.minY == layout.transcriptRect.maxY + 12)
        #expect(bodyScreenRect(from: layout).minY == testCompanionFrame().maxY + ConversationBubbleLayout.bodyCompanionGap)
        #expect(layout.connectorEnd == NSPoint(x: 72, y: 322))
    }

    @Test
    func testConversationLayoutGrowsForMediumContent() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 220,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(layout.size.height == 326)
        #expect(!layout.isTranscriptScrollable)
        #expect(bodyScreenRect(from: layout).minY == testCompanionFrame().maxY + ConversationBubbleLayout.bodyCompanionGap)
    }

    @Test
    func testConversationLayoutCapsLongContentAndScrolls() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 900,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(abs(layout.size.height - 400) < 0.001)
        #expect(layout.isTranscriptScrollable)
        #expect(layout.frame.maxY <= 792)
    }

    @Test
    func testConversationLayoutClampsInsideDisplay() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 80,
            anchoredAt: NSPoint(x: 980, y: 780),
            companionFrame: NSRect(x: 900, y: 660, width: 80, height: 80),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(bodyScreenRect(from: layout).maxX <= 992)
        #expect(bodyScreenRect(from: layout).maxY <= 792)
        #expect(layout.frame.maxX <= 1000)
        #expect(layout.frame.maxY <= 800)
    }

    @Test
    func testConversationLayoutShrinksInsideSmallDisplay() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 900,
            anchoredAt: NSPoint(x: 300, y: 380),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 320, height: 400)
        )

        #expect(layout.size.width == 304)
        #expect(abs(layout.size.height - 200) < 0.001)
        #expect(layout.frame.minX >= 8)
        #expect(bodyScreenRect(from: layout).maxX <= 312)
        #expect(layout.frame.maxX <= 320)
        #expect(layout.frame.maxY <= 400)
        #expect(layout.isTranscriptScrollable)
    }

    @Test
    func testConversationLayoutUsesSidePlacementWhenAboveSpaceIsTooSmall() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 300, y: 380),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 320, height: 400)
        )

        #expect(bodyScreenRect(from: layout).minY < testCompanionFrame().maxY)
        #expect(layout.connectorEnd.x >= 0)
        #expect(layout.connectorEnd.y >= 0)
    }

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
        #expect(theme.tailStyle.fill == "#112233CC")
        #expect(theme.tailStyle.stroke == "#445566")
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
        #expect(theme.metrics.width == 360)
        #expect(theme.metrics.minHeight == 190)
        #expect(theme.metrics.contentInsets.top == 34)
        #expect(theme.metrics.inputHeight == 34)
        #expect(theme.metrics.tailAnchor == NSPoint(x: 72, y: 0))
        #expect(theme.tailStyle == .defaultStyle)
        #expect(FileManager.default.fileExists(atPath: theme.bubbleSVGURL.path))
        #expect(theme.bubbleImage.size.width > 0)
        #expect(theme.bubbleImage.size.height > 0)
    }

    @Test
    func testBundledConversationBubbleSVGIsBodyOnly() throws {
        let theme = ConversationThemeLoader.selectedTheme(userDefaults: UserDefaults(suiteName: "DesktopCompanionTests-\(UUID().uuidString)") ?? .standard)
        let markup = try String(contentsOf: theme.bubbleSVGURL, encoding: .utf8)

        #expect(!markup.contains("<ellipse"))
        #expect(!markup.contains("L72 214"))
    }

    @Test
    func testThemeFallbackStillProvidesVisibleBubbleImage() {
        let theme = ConversationTheme(
            id: "fallback",
            displayName: "Fallback",
            folderURL: URL(fileURLWithPath: "/"),
            bubbleSVGURL: URL(fileURLWithPath: "/missing.svg"),
            metrics: testMetrics(),
            tailStyle: .defaultStyle
        )

        #expect(theme.bubbleImage.size == NSSize(width: 360, height: 190))
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
    func testArgumentsRunCodexExecInReadOnlyGeneralMode() {
        #expect(
            CodexConversationCommand.arguments(workingDirectory: "/tmp/work", outputFile: "/tmp/answer.txt") ==
            [
                "exec",
                "--ephemeral",
                "--skip-git-repo-check",
                "--sandbox", "read-only",
                "--cd", "/tmp/work",
                "--output-last-message", "/tmp/answer.txt",
                "--color", "never",
                "-"
            ]
        )
    }

    @Test
    func testPromptIncludesHistoryAndCurrentQuestion() {
        let prompt = CodexConversationCommand.prompt(
            question: "What is the moon?",
            history: [
                CodexConversationTurn(question: "Hello?", answer: "Hi.")
            ]
        )

        #expect(prompt.contains("Do not inspect, modify, or rely on local files."))
        #expect(prompt.contains("User: Hello?"))
        #expect(prompt.contains("Assistant: Hi."))
        #expect(prompt.contains("User: What is the moon?"))
    }

    @Test
    func testParsedResponseTrimsBlankSpace() {
        #expect(CodexConversationCommand.parsedResponse(from: "\n  Answer. \n") == "Answer.")
        #expect(CodexConversationCommand.parsedResponse(from: "\n \t") == nil)
    }

    @Test
    func testExecutableLocatorPrefersKnownCodexLocationsThenPath() {
        let locator = CodexExecutableLocator(
            environment: [
                "HOME": "/Users/example",
                "PATH": "/bin:/custom/bin:/bin"
            ],
            isExecutableFile: { $0 == "/custom/bin/codex" }
        )

        #expect(locator.locate() == "/custom/bin/codex")
        #expect(
            CodexExecutableLocator.candidatePaths(environment: [
                "HOME": "/Users/example",
                "PATH": "/bin:/custom/bin:/bin"
            ]) ==
            [
                "/Users/example/.local/bin/codex",
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex",
                "/bin/codex",
                "/custom/bin/codex"
            ]
        )
    }

    @Test
    func testCompanionAssetParsesMouthAnchorAttribute() {
        let anchor = CompanionAsset.mouthAnchor(
            from: #"<svg viewBox="0 0 220 220" data-mouth-anchor="121 94"></svg>"#
        )

        #expect(anchor == NSPoint(x: 121, y: 94))
    }

    @Test
    func testCompanionAssetParsesMouthXYAttributes() {
        let anchor = CompanionAsset.mouthAnchor(
            from: #"<svg viewBox="0 0 220 220" data-mouth-x="118" data-mouth-y="90"></svg>"#
        )

        #expect(anchor == NSPoint(x: 118, y: 90))
    }

    @Test
    func testCompanionAssetFallsBackForInvalidMouthAnchor() {
        let anchor = CompanionAsset.mouthAnchor(
            from: #"<svg viewBox="0 0 220 220" data-mouth-anchor="500 90"></svg>"#
        )

        #expect(anchor == CompanionAsset.defaultMouthAnchor)
    }

    private func makeThemeFolder(manifest: String) throws -> ConversationTheme {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-theme-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try manifest.write(to: folderURL.appendingPathComponent("theme.json"), atomically: true, encoding: .utf8)
        try "<svg viewBox=\"0 0 420 300\" xmlns=\"http://www.w3.org/2000/svg\"></svg>"
            .write(to: folderURL.appendingPathComponent("bubble.svg"), atomically: true, encoding: .utf8)
        return try ConversationThemeLoader.loadTheme(from: folderURL)
    }

    private func testMetrics() -> ConversationBubbleMetrics {
        ConversationBubbleMetrics(
            width: 360,
            minHeight: 190,
            maxVisibleHeightRatio: 0.5,
            contentInsets: NSEdgeInsets(top: 34, left: 36, bottom: 26, right: 36),
            inputHeight: 34,
            transcriptInputSpacing: 12,
            tailAnchor: NSPoint(x: 72, y: 0)
        )
    }

    private func testCompanionFrame() -> NSRect {
        NSRect(x: 220, y: 100, width: 220, height: 220)
    }

    private func bodyScreenRect(from layout: ConversationBubbleLayoutResult) -> NSRect {
        NSRect(
            x: layout.frame.minX + layout.bodyRect.minX,
            y: layout.frame.maxY - layout.bodyRect.maxY,
            width: layout.bodyRect.width,
            height: layout.bodyRect.height
        )
    }
}
