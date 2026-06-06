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
    func testConversationLayoutUsesFixedHeightForShortContent() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 24,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(layout.size == NSSize(width: 520, height: 300))
        #expect(!layout.isTranscriptScrollable)
        #expect(layout.inputRect.maxY == 270)
        #expect(layout.inputRect.minY == layout.transcriptRect.maxY + 16)
        #expect(bodyScreenRect(from: layout).minY == testCompanionFrame().maxY + ConversationBubbleLayout.bodyCompanionGap)
        #expect(layout.connectorEnd == NSPoint(x: 94, y: 432))
    }

    @Test
    func testConversationLayoutKeepsFixedHeightForMediumContent() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 220,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(layout.size.height == 300)
        #expect(layout.isTranscriptScrollable)
        #expect(bodyScreenRect(from: layout).minY == testCompanionFrame().maxY + ConversationBubbleLayout.bodyCompanionGap)
    }

    @Test
    func testConversationLayoutKeepsFixedHeightForLongContentAndScrolls() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 900,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(layout.size.height == 300)
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
    func testConversationTranscriptItemsUseChatRowsWithoutSpeakerLabels() {
        let model = ConversationTranscriptViewModel(
            history: [
                CodexConversationTurn(question: "tell me golang is?", answer: "Go is a programming language.")
            ],
            pendingQuestion: "What is concurrency?",
            status: "Thinking..."
        )

        #expect(
            model.items == [
                .user("tell me golang is?"),
                .assistant("Go is a programming language."),
                .user("What is concurrency?"),
                .status("Thinking...")
            ]
        )
        #expect(!transcriptText(model.items).contains("Codex:"))
        #expect(!transcriptText(model.items).contains("You:"))
    }

    @Test
    func testConversationTranscriptShowsPromptWhenEmpty() {
        let model = ConversationTranscriptViewModel(
            history: [],
            pendingQuestion: nil,
            status: nil
        )

        #expect(model.items == [.emptyPrompt("Ask me anything.")])
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
        #expect(theme.metrics.width == 520)
        #expect(theme.metrics.minHeight == 300)
        #expect(theme.metrics.contentInsets.top == 42)
        #expect(theme.metrics.contentInsets.left == 42)
        #expect(theme.metrics.contentInsets.bottom == 30)
        #expect(theme.metrics.contentInsets.right == 42)
        #expect(theme.metrics.inputHeight == 42)
        #expect(theme.metrics.transcriptInputSpacing == 16)
        #expect(theme.metrics.tailAnchor == NSPoint(x: 94, y: 0))
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

        #expect(theme.bubbleImage.size == NSSize(width: 520, height: 300))
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
    func testConversationErrorMessagesAvoidCodexLabel() {
        #expect(!CodexConversationError.codexNotFound.userMessage.contains("Codex"))
        #expect(!CodexConversationError.launchFailed("boom").userMessage.contains("Codex"))
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
            width: 520,
            minHeight: 300,
            maxVisibleHeightRatio: 0.5,
            contentInsets: NSEdgeInsets(top: 42, left: 42, bottom: 30, right: 42),
            inputHeight: 42,
            transcriptInputSpacing: 16,
            tailAnchor: NSPoint(x: 94, y: 0)
        )
    }

    private func transcriptText(_ items: [ConversationTranscriptItem]) -> String {
        items.map { item in
            switch item {
            case .emptyPrompt(let text), .user(let text), .assistant(let text), .status(let text):
                text
            }
        }.joined(separator: "\n")
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
