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

        #expect(menu?.items.contains { $0.title == "Preview Animation" } == true)
        #expect(menu?.items.contains { $0.title == "Test Bash" } == false)
        #expect(menu?.items.contains { $0.title == "Conversate" } == true)
        #expect(menu?.items.contains { $0.title == "Reload Bubble Theme" } == true)
        #expect(menu?.items.contains { $0.title == "Companion Package" } == false)
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

    @Test
    func testCompanionPackageLoadsValidManifest() throws {
        let package = try makeCompanionPackage(includeThemes: true)

        #expect(package.id == "test-companion")
        #expect(package.displayName == "Test Companion")
        #expect(package.svgURL.lastPathComponent == "companion.svg")
        #expect(package.conversationThemesDirectoryURL?.lastPathComponent == "ConversationThemes")
        #expect(package.speechAnchor == NSPoint(x: 108, y: 89))
        #expect(package.bubblePlacement == .right)
        #expect(package.animationPreset == .wholeObjectReaction)
    }

    @Test
    func testCompanionPackageRejectsInvalidSVGBounds() throws {
        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                svg: #"<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"></svg>"#
            )
        }
    }

    @Test
    func testCompanionPackageRejectsEscapedSVGPath() throws {
        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "bad-companion",
                  "displayName": "Bad Companion",
                  "companionSVG": "../companion.svg"
                }
                """
            )
        }
    }

    @Test
    func testCompanionPackageRejectsUnsafeSVGFeatures() throws {
        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                svg: #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>"#
            )
        }

        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                svg: #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/a.png"/></svg>"#
            )
        }
    }

    @Test
    func testCompanionPackageRejectsUnsafePackageID() throws {
        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "../bad-companion",
                  "displayName": "Bad Companion",
                  "companionSVG": "companion.svg"
                }
                """
            )
        }
    }

    @Test
    func testCompanionPackageInstallerCopiesOnlyDeclaredFiles() throws {
        let package = try makeCompanionPackage(includeThemes: true)
        let unusedURL = package.folderURL.appendingPathComponent("unused.txt", isDirectory: false)
        try "do not install".write(to: unusedURL, atomically: true, encoding: .utf8)

        let installRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-install-test-\(UUID().uuidString)", isDirectory: true)
        let installed = try CompanionPackageInstaller.installPackageFolder(
            sourceFolderURL: package.folderURL,
            packagesDirectory: installRootURL
        )

        #expect(installed.id == package.id)
        #expect(FileManager.default.fileExists(atPath: installed.folderURL.appendingPathComponent("companion.json").path))
        #expect(FileManager.default.fileExists(atPath: installed.svgURL.path))
        #expect(FileManager.default.fileExists(atPath: installed.folderURL.appendingPathComponent("ConversationThemes/package-cloud/theme.json").path))
        #expect(!FileManager.default.fileExists(atPath: installed.folderURL.appendingPathComponent("unused.txt").path))
    }

    @Test
    func testCompanionPackageInstallerRejectsSymlinks() throws {
        let package = try makeCompanionPackage()
        let linkURL = package.folderURL.appendingPathComponent("linked.txt", isDirectory: false)
        try FileManager.default.createSymbolicLink(
            at: linkURL,
            withDestinationURL: URL(fileURLWithPath: "/tmp/desktop-companion-linked.txt")
        )

        let installRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-install-test-\(UUID().uuidString)", isDirectory: true)

        #expect(throws: CompanionPackageError.invalidManifest) {
            try CompanionPackageInstaller.installPackageFolder(
                sourceFolderURL: package.folderURL,
                packagesDirectory: installRootURL
            )
        }
    }

    @Test
    func testCompanionAssetLoadsPackageSVG() throws {
        let package = try makeCompanionPackage(
            svg: #"<svg viewBox="0 0 220 220" data-mouth-anchor="82 71" xmlns="http://www.w3.org/2000/svg"></svg>"#
        )
        let asset = CompanionAsset.load(package: package)

        #expect(asset.mouthAnchor == NSPoint(x: 108, y: 89))
        #expect(asset.markup.contains("data-mouth-anchor=\"82 71\""))
    }

    @Test
    func testCompanionPackageFallsBackToSVGAnchorWhenManifestAnchorIsMissing() throws {
        let package = try makeCompanionPackage(
            manifest: """
            {
              "schemaVersion": 1,
              "id": "svg-anchor-companion",
              "displayName": "SVG Anchor Companion",
              "companionSVG": "companion.svg"
            }
            """,
            svg: #"<svg viewBox="0 0 220 220" data-mouth-anchor="82 71" xmlns="http://www.w3.org/2000/svg"></svg>"#
        )

        #expect(package.speechAnchor == NSPoint(x: 82, y: 71))
        #expect(package.bubblePlacement == .automatic)
        #expect(package.animationPreset == .wholeObjectReaction)
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
    func testInstanceStoreSavesAndRestoresMultipleCompanions() throws {
        let suiteName = "DesktopCompanionInstances-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let first = CompanionInstance(
            id: "one",
            packageID: "lego-vader",
            origin: CompanionAnchor(x: 10, y: 20),
            layerMode: .desktop,
            speechAnchor: CompanionAnchor(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .legoSmash
        )
        let second = CompanionInstance(
            id: "two",
            packageID: "cloud-cat",
            origin: CompanionAnchor(x: 30, y: 40),
            layerMode: .floating,
            speechAnchor: CompanionAnchor(x: 80, y: 70),
            bubblePlacement: .left,
            animationPreset: .idleOnly
        )

        CompanionInstanceStore.save([first, second], userDefaults: defaults)

        #expect(CompanionInstanceStore.load(userDefaults: defaults) == [first, second])
    }

    @Test
    func testConversationLayoutHonorsExplicitRightPlacement() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 130, y: 200),
            companionFrame: NSRect(x: 100, y: 100, width: 80, height: 80),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            placement: .right
        )

        #expect(bodyScreenRect(from: layout).minX == 192)
    }

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

    private func makeThemeFolder(
        manifest: String,
        bubbleSVG: String = #"<svg viewBox="0 0 420 300" xmlns="http://www.w3.org/2000/svg"></svg>"#
    ) throws -> ConversationTheme {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-theme-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try manifest.write(to: folderURL.appendingPathComponent("theme.json"), atomically: true, encoding: .utf8)
        try bubbleSVG.write(to: folderURL.appendingPathComponent("bubble.svg"), atomically: true, encoding: .utf8)
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

    private func makeCompanionPackage(
        manifest: String? = nil,
        svg: String = #"<svg viewBox="0 0 220 220" data-mouth-anchor="108 89" xmlns="http://www.w3.org/2000/svg"></svg>"#,
        includeThemes: Bool = false
    ) throws -> CompanionPackage {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-package-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let manifestText = manifest ?? """
        {
          "schemaVersion": 1,
          "id": "test-companion",
          "displayName": "Test Companion",
          "companionSVG": "companion.svg",
          \(includeThemes ? #""conversationThemesDirectory": "ConversationThemes","# : "")
          "speechAnchor": { "x": 108, "y": 89 },
          "bubblePlacement": "right",
          "animationPreset": "wholeObjectReaction"
        }
        """
        try manifestText.write(to: folderURL.appendingPathComponent("companion.json"), atomically: true, encoding: .utf8)
        try svg.write(to: folderURL.appendingPathComponent("companion.svg"), atomically: true, encoding: .utf8)

        if includeThemes {
            let themeFolderURL = folderURL
                .appendingPathComponent("ConversationThemes", isDirectory: true)
                .appendingPathComponent("package-cloud", isDirectory: true)
            try FileManager.default.createDirectory(at: themeFolderURL, withIntermediateDirectories: true)
            try """
            {
              "schemaVersion": 1,
              "id": "package-cloud",
              "displayName": "Package Cloud",
              "bubbleSVG": "bubble.svg",
              "width": 360,
              "minHeight": 190,
              "maxVisibleHeightRatio": 0.5,
              "contentInsets": { "top": 34, "left": 36, "bottom": 26, "right": 36 },
              "inputHeight": 34,
              "transcriptInputSpacing": 12,
              "tailAnchor": { "x": 72, "y": 0 }
            }
            """
                .write(to: themeFolderURL.appendingPathComponent("theme.json"), atomically: true, encoding: .utf8)
            try "<svg viewBox=\"0 0 360 190\" xmlns=\"http://www.w3.org/2000/svg\"></svg>"
                .write(to: themeFolderURL.appendingPathComponent("bubble.svg"), atomically: true, encoding: .utf8)
        }

        return try CompanionPackageLoader.loadPackage(from: folderURL)
    }

    private func testPackage(id: String) -> CompanionPackage {
        CompanionPackage(
            id: id,
            displayName: id,
            folderURL: URL(fileURLWithPath: "/tmp/\(id)", isDirectory: true),
            svgURL: URL(fileURLWithPath: "/tmp/\(id)/companion.svg", isDirectory: false),
            conversationThemesDirectoryURL: nil,
            speechAnchor: NSPoint(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .wholeObjectReaction
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
