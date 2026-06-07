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
        #expect(
            menu?.items.first(where: { $0.title == "Preview Animation" })?.submenu?.items.map(\.title) ==
                CompanionAnimationState.allCases.map(\.title)
        )
        #expect(menu?.items.contains { $0.title == "Test Bash" } == false)
        #expect(menu?.items.contains { $0.title == "Conversate" } == true)
        #expect(menu?.items.contains { $0.title == "Reload Overlay Theme" } == true)
        #expect(menu?.items.contains { $0.title == "Companion Package" } == false)
        #expect(menu?.items.first(where: { $0.title == "Overlay Theme" })?.submenu?.items.count == 1)
    }

    @MainActor
    @Test
    func testLibraryCardsShowActiveCountsAndSpawnPackages() throws {
        let firstPackage = testPackage(id: "first-package", displayName: "LEGO Vader")
        let secondPackage = testPackage(id: "second-package", displayName: "Tiny Bot")
        let legacyPackage = testPackage(id: CompanionPackageLoader.legacyUserPackageID, displayName: "User SVG Override")
        let controller = CompanionLibraryWindowController()
        var spawnedPackageIDs: [String] = []
        var didRequestSettings = false
        controller.onSpawnPackage = { package in
            spawnedPackageIDs.append(package.id)
        }
        controller.onOpenSettings = {
            didRequestSettings = true
        }

        controller.reload(
            packages: [legacyPackage, firstPackage, secondPackage],
            instances: [
                testInstance(id: "legacy", packageID: legacyPackage.id),
                testInstance(id: "one", packageID: firstPackage.id),
                testInstance(id: "two", packageID: firstPackage.id),
                testInstance(id: "three", packageID: secondPackage.id)
            ]
        )

        let contentView = try #require(controller.window?.contentView)
        let labels = descendantViews(ofType: NSTextField.self, in: contentView)
        let labelTexts = labels.map(\.stringValue)
        let buttons = descendantViews(ofType: NSButton.self, in: contentView)
        let buttonTitles = buttons.map(\.title)
        let spawnButtons = buttons.filter { $0.title == AppCopy.spawnAction }
        let browseButton = try #require(buttons.first { $0.title == AppCopy.browseAction })
        let accountButton = try #require(buttons.first { $0.title == AppCopy.accountAction })
        let settingsButton = try #require(buttons.first { $0.title == AppCopy.settingsAction })
        let sharedButtonTitles = Set([
            AppCopy.companionsTitle,
            AppCopy.uploadAction,
            AppCopy.browseAction,
            AppCopy.accountAction,
            AppCopy.settingsAction
        ])
        let sharedButtons = buttons.filter { sharedButtonTitles.contains($0.title) }
        let cardActiveLabels = labels.filter { [AppCopy.activeCount(2), AppCopy.activeCount(1)].contains($0.stringValue) }
        let previewViews = descendantViews(ofType: SVGCompanionView.self, in: contentView)

        #expect(labelTexts.contains(AppCopy.libraryTitle))
        #expect(labelTexts.contains(AppCopy.activeCount(3)))
        #expect(labelTexts.contains(AppCopy.activeCount(2)))
        #expect(labelTexts.contains(AppCopy.activeCount(1)))
        #expect(labelTexts.contains(AppCopy.marketplaceTitle))
        #expect(!labelTexts.contains("Desktop Companion"))
        #expect(controller.window?.title == AppCopy.libraryTitle)
        #expect(labelTexts.contains(firstPackage.displayName))
        #expect(labelTexts.contains(secondPackage.displayName))
        #expect(!labelTexts.contains(firstPackage.displayName.uppercased()))
        #expect(!labelTexts.contains(secondPackage.displayName.uppercased()))
        #expect(!labelTexts.contains(legacyPackage.displayName))
        #expect(buttonTitles.contains(AppCopy.uploadAction))
        #expect(buttonTitles.contains(AppCopy.browseAction))
        #expect(buttonTitles.contains(AppCopy.accountAction))
        #expect(buttonTitles.contains(AppCopy.settingsAction))
        #expect(!browseButton.isEnabled)
        #expect(browseButton.toolTip == AppCopy.marketplaceComingSoonTooltip)
        #expect(!accountButton.isEnabled)
        #expect(accountButton.toolTip == AppCopy.accountComingSoonTooltip)
        #expect(spawnButtons.count == 2)
        #expect(sharedButtons.count == sharedButtonTitles.count)
        #expect(sharedButtons.allSatisfy { $0.identifier == AppTheme.roundedButtonIdentifier })
        #expect(spawnButtons.allSatisfy { $0.identifier == AppTheme.roundedButtonIdentifier })
        #expect(spawnButtons.allSatisfy { $0.alignment == .center })
        #expect(sharedButtons.allSatisfy { !$0.isBordered })
        #expect(cardActiveLabels.count == 2)
        #expect(cardActiveLabels.allSatisfy { $0.alignment == .center })
        #expect(previewViews.count == 2)
        #expect(previewViews.allSatisfy { hasIdleAnimation(in: $0) })

        settingsButton.performClick(nil)
        spawnButtons.forEach { $0.performClick(nil) }

        #expect(didRequestSettings)
        #expect(spawnedPackageIDs.count == 2)
        #expect(Set(spawnedPackageIDs) == Set([firstPackage.id, secondPackage.id]))
        controller.close()
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

    @Test
    func testAnimationStatesAreSharedAcrossActivePresets() {
        #expect(CompanionAnimationClip.states(for: .wholeObjectReaction) == CompanionAnimationState.allCases)
        #expect(CompanionAnimationClip.states(for: .legoSmash) == CompanionAnimationState.allCases)
        #expect(CompanionAnimationClip.states(for: .idleOnly).isEmpty)
    }

    @MainActor
    @Test
    func testAnimationClipsBuildTypingAndThinkingStates() throws {
        let markup = #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"><g class="lego-smash-arm"></g></svg>"#
        let renderer: (String) -> NSImage = { _ in NSImage(size: NSSize(width: 2, height: 2)) }

        let typing = try #require(CompanionAnimationClip.clip(
            markup: markup,
            preset: .legoSmash,
            state: .typing,
            renderer: renderer
        ))
        let thinking = try #require(CompanionAnimationClip.clip(
            markup: markup,
            preset: .legoSmash,
            state: .thinking,
            renderer: renderer
        ))

        #expect(typing.frames.count == 3)
        #expect(typing.duration == 0.30)
        #expect(thinking.frames.count == 1)
        #expect(thinking.duration == 1.25)
    }

    @MainActor
    @Test
    func testIdleOnlyDoesNotBuildAnimationClips() {
        let renderer: (String) -> NSImage = { _ in NSImage(size: NSSize(width: 2, height: 2)) }

        let clip = CompanionAnimationClip.clip(
            markup: #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"></svg>"#,
            preset: .idleOnly,
            state: .typing,
            renderer: renderer
        )
        if clip != nil {
            Issue.record("Idle-only preset should not build animation clips")
        }
    }

    @MainActor
    @Test
    func testIdleOnlyContextMenuDisablesUnsupportedAnimationStates() {
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

        let view = CompanionContentView(
            frame: NSRect(origin: .zero, size: CompanionWindowMetrics.size),
            package: nil,
            animationPreset: .idleOnly
        )
        let previewItems = view.menu(for: event)?
            .items
            .first(where: { $0.title == "Preview Animation" })?
            .submenu?
            .items ?? []

        #expect(previewItems.count == CompanionAnimationState.allCases.count)
        #expect(previewItems.allSatisfy { !$0.isEnabled })
    }

    @MainActor
    @Test
    func testConversationRunningStateMapsToThinkingAnimation() {
        #expect(CompanionWindowController.animationState(forConversationRunning: true) == .thinking)
        #expect(CompanionWindowController.animationState(forConversationRunning: false) == nil)
    }

    @MainActor
    @Test
    func testConversationRunningStateNotifiesOnSuccess() throws {
        let submitted = try submittedConversationController()

        #expect(submitted.recorder.values == [true])
        submitted.runner.complete(.success("Done"))
        #expect(submitted.recorder.values == [true, false])
    }

    @MainActor
    @Test
    func testConversationRunningStateNotifiesOnFailure() throws {
        let submitted = try submittedConversationController()

        #expect(submitted.recorder.values == [true])
        submitted.runner.complete(.failure(.missingResponse))
        #expect(submitted.recorder.values == [true, false])
    }

    @MainActor
    @Test
    func testConversationRunningStateNotifiesOnCancel() throws {
        let submitted = try submittedConversationController()

        #expect(submitted.recorder.values == [true])
        submitted.controller.closeBubble()
        #expect(submitted.runner.didCancel)
        #expect(submitted.recorder.values == [true, false])
    }

    @MainActor
    @Test
    func testConversationFrameUsesTransparentTextBodyOnly() throws {
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

        #expect(frame.origin == NSPoint(x: 216, y: 332))
        #expect(frame.size == NSSize(width: 420, height: 133))
    }

    @Test
    func testConversationLayoutFitsShortContentWithoutFixedBubbleHeight() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 24,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(layout.size == NSSize(width: 520, height: 160))
        #expect(!layout.isTranscriptScrollable)
        #expect(layout.inputRect.maxY == 130)
        #expect(layout.inputRect.minY == layout.transcriptRect.maxY + 16)
        #expect(bodyScreenRect(from: layout).minY == testCompanionFrame().maxY + ConversationBubbleLayout.bodyCompanionGap)
        #expect(layout.frame == bodyScreenRect(from: layout))
    }

    @Test
    func testConversationLayoutReservesOverlayControlGutters() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 80,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(layout.transcriptRect.minY - layout.bodyRect.minY >= ConversationBubbleLayout.controlTopGutter)
        #expect(layout.bodyRect.maxX - layout.transcriptRect.maxX >= ConversationBubbleLayout.controlRightGutter)
        #expect(layout.bodyRect.maxX - layout.inputRect.maxX >= ConversationBubbleLayout.controlRightGutter)
    }

    @Test
    func testConversationLayoutExpandsForMediumContent() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 220,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(layout.size.height == 356)
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

        #expect(layout.size.height == 460)
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
    func testConversationLayoutUsesPreferredBodySize() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 180,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            preferredBodySize: NSSize(width: 640, height: 380)
        )

        #expect(layout.size == NSSize(width: 640, height: 380))
        #expect(layout.transcriptRect.width == 542)
        #expect(layout.inputRect.width == 542)
        #expect(!layout.isTranscriptScrollable)
    }

    @Test
    func testConversationLayoutClampsPreferredBodySizeToUsableBounds() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            preferredBodySize: NSSize(width: 40, height: 40)
        )

        #expect(layout.size == NSSize(width: 258, height: 176))
        #expect(layout.transcriptRect.width == 160)
    }

    @Test
    func testConversationLayoutClampsLargePreferredBodySizeInsideSmallDisplay() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 900,
            anchoredAt: NSPoint(x: 300, y: 380),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 320, height: 400),
            preferredBodySize: NSSize(width: 900, height: 900)
        )

        #expect(layout.size == NSSize(width: 304, height: 384))
        #expect(layout.frame.maxX <= 320)
        #expect(layout.frame.maxY <= 400)
        #expect(layout.isTranscriptScrollable)
    }

    @Test
    func testConversationLayoutKeepsWindowFrameEqualToTransparentTextBody() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 130, y: 200),
            companionFrame: NSRect(x: 100, y: 100, width: 80, height: 80),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            placement: .right,
            preferredBodySize: NSSize(width: 360, height: 320)
        )

        #expect(layout.size == NSSize(width: 360, height: 320))
        #expect(bodyScreenRect(from: layout).size == layout.size)
        #expect(layout.frame.size == layout.bodyRect.size)
    }

    @Test
    func testConversationLayoutAppliesBodyOffsetFromAutomaticPosition() {
        let baseLayout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )
        let offsetLayout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            bodyOffset: NSPoint(x: 40, y: -25)
        )
        let baseBody = bodyScreenRect(from: baseLayout)
        let offsetBody = bodyScreenRect(from: offsetLayout)

        #expect(offsetLayout.bodyOffset == NSPoint(x: 40, y: -25))
        #expect(offsetBody.origin == NSPoint(x: baseBody.minX + 40, y: baseBody.minY - 25))
        #expect(offsetLayout.connectorEnd.x >= 0)
        #expect(offsetLayout.connectorEnd.y >= 0)
    }

    @Test
    func testConversationLayoutClampsBodyOffsetInsideDisplay() {
        let layout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            bodyOffset: NSPoint(x: 900, y: 900)
        )
        let body = bodyScreenRect(from: layout)

        #expect(body.maxX <= 992)
        #expect(body.maxY <= 792)
        #expect(layout.bodyOffset.x < 900)
        #expect(layout.bodyOffset.y < 900)
    }

    @Test
    func testBottomRightResizeOffsetKeepsTopLeftCornerForLeftPlacement() {
        let startLayout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 430, y: 300),
            companionFrame: NSRect(x: 400, y: 220, width: 80, height: 80),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            placement: .left
        )
        let startBody = bodyScreenRect(from: startLayout)
        let automaticResizedLayout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 430, y: 300),
            companionFrame: NSRect(x: 400, y: 220, width: 80, height: 80),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            placement: .left,
            preferredBodySize: NSSize(width: startLayout.size.width + 80, height: startLayout.size.height + 50)
        )
        let offset = ConversationBubbleWindowController.bodyOffsetForBottomRightResize(
            startBodyFrame: startBody,
            automaticBodyFrame: bodyScreenRect(from: automaticResizedLayout)
        )
        let resizedLayout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 430, y: 300),
            companionFrame: NSRect(x: 400, y: 220, width: 80, height: 80),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            placement: .left,
            preferredBodySize: NSSize(width: startLayout.size.width + 80, height: startLayout.size.height + 50),
            bodyOffset: offset
        )
        let resizedBody = bodyScreenRect(from: resizedLayout)

        #expect(resizedBody.minX == startBody.minX)
        #expect(resizedBody.maxY == startBody.maxY)
        #expect(resizedBody.width == startBody.width + 80)
        #expect(resizedBody.height == startBody.height + 50)
    }

    @Test
    func testBottomRightResizeOffsetKeepsTopLeftCornerForAbovePlacement() {
        let startLayout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            placement: .above
        )
        let startBody = bodyScreenRect(from: startLayout)
        let automaticResizedLayout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            placement: .above,
            preferredBodySize: NSSize(width: startLayout.size.width + 70, height: startLayout.size.height + 40)
        )
        let offset = ConversationBubbleWindowController.bodyOffsetForBottomRightResize(
            startBodyFrame: startBody,
            automaticBodyFrame: bodyScreenRect(from: automaticResizedLayout)
        )
        let resizedLayout = ConversationBubbleLayout.layout(
            metrics: testMetrics(),
            transcriptHeight: 40,
            anchoredAt: NSPoint(x: 300, y: 200),
            companionFrame: testCompanionFrame(),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            placement: .above,
            preferredBodySize: NSSize(width: startLayout.size.width + 70, height: startLayout.size.height + 40),
            bodyOffset: offset
        )
        let resizedBody = bodyScreenRect(from: resizedLayout)

        #expect(resizedBody.minX == startBody.minX)
        #expect(resizedBody.maxY == startBody.maxY)
        #expect(resizedBody.width == startBody.width + 70)
        #expect(resizedBody.height == startBody.height + 40)
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
        #expect(abs(layout.size.height - 384) < 0.001)
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
            streamingAnswer: nil,
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
            streamingAnswer: nil,
            status: nil
        )

        #expect(model.items == [.emptyPrompt("Ask me anything.")])
    }

    @Test
    func testConversationTranscriptShowsStreamingAnswerForPendingQuestion() {
        let model = ConversationTranscriptViewModel(
            history: [],
            pendingQuestion: "Explain buffers.",
            streamingAnswer: "Buffers hold temporary bytes",
            status: nil
        )

        #expect(model.items == [
            .user("Explain buffers."),
            .assistant("Buffers hold temporary bytes")
        ])
    }

    @MainActor
    @Test
    func testAssistantTranscriptRowsUseFullAvailableWidth() {
        let text = Array(repeating: "conversation text should use available width", count: 8)
            .joined(separator: " ")
        let assistantView = ConversationTranscriptView(frame: .zero)
        assistantView.items = [.assistant(text)]
        let userView = ConversationTranscriptView(frame: .zero)
        userView.items = [.user(text)]

        #expect(assistantView.measuredHeight(width: 360) < assistantView.measuredHeight(width: 260))
        #expect(userView.measuredHeight(width: 360) < userView.measuredHeight(width: 260))
    }

    @MainActor
    @Test
    func testConversationTextStyleUpdateChangesTranscriptMeasurement() {
        let text = Array(repeating: "conversation text should reflow after font changes", count: 5)
            .joined(separator: " ")
        let view = ConversationTranscriptView(frame: .zero)
        view.items = [.assistant(text)]
        let originalHeight = view.measuredHeight(width: 280)

        var style = ConversationTranscriptStyle.defaultStyle
        style.assistant.font = NSFont.systemFont(ofSize: 24)
        view.updateTextStyle(style)

        #expect(view.measuredHeight(width: 280) > originalHeight)
    }

    @MainActor
    @Test
    func testConversationTextStyleUsesDistinctUserAndAssistantBackgrounds() {
        let style = ConversationTranscriptStyle.defaultStyle
        let userBackground = rgbaComponents(style.itemStyle(for: .user("hello")).backgroundColor)
        let assistantBackground = rgbaComponents(style.itemStyle(for: .assistant("hello")).backgroundColor)

        #expect(userBackground != assistantBackground)
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
        #expect(theme.metrics.minHeight == 118)
        #expect(theme.metrics.contentInsets.top == 20)
        #expect(theme.metrics.contentInsets.left == 18)
        #expect(theme.metrics.contentInsets.bottom == 12)
        #expect(theme.metrics.contentInsets.right == 18)
        #expect(theme.metrics.inputHeight == 36)
        #expect(theme.metrics.transcriptInputSpacing == 12)
        #expect(theme.metrics.tailAnchor == NSPoint(x: 80, y: 0))
        #expect(theme.tailStyle == ConversationTailStyle(fill: "#FFFFFFFA", stroke: "#0000001A"))
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
                "--json",
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
    func testStreamingParserAccumulatesDeltaEvents() {
        var parser = CodexConversationStreamParser()
        let first = #"{"type":"response.output_text.delta","delta":"Hel"}"#
        let second = #"{"type":"response.output_text.delta","delta":"lo"}"#

        #expect(parser.consume(Data("\(first)\n".utf8)) == "Hel")
        #expect(parser.consume(Data("\(second)\n".utf8)) == "Hello")
    }

    @Test
    func testStreamingParserHandlesMultibyteCharactersSplitAcrossChunks() throws {
        var parser = CodexConversationStreamParser()
        let line = #"{"type":"response.output_text.delta","delta":"Hi 🌕"}"#
        let data = Data("\(line)\n".utf8)
        let emojiStart = try #require(data.firstIndex(of: 0xF0))
        let splitIndex = data.index(after: emojiStart)

        #expect(parser.consume(Data(data[..<splitIndex])) == nil)
        #expect(parser.consume(Data(data[splitIndex...])) == "Hi 🌕")
    }

    @Test
    func testStreamingParserIgnoresNonAnswerOutput() {
        var parser = CodexConversationStreamParser()
        let progress = #"{"type":"response.reasoning_text.delta","delta":"internal thought"}"#
        let status = #"{"type":"turn.status.delta","delta":"working"}"#
        let answer = #"{"type":"response.output_text.delta","delta":"Answer"}"#

        #expect(parser.consume(Data("plain stdout warning\n".utf8)) == nil)
        #expect(parser.consume(Data("\(progress)\n".utf8)) == nil)
        #expect(parser.consume(Data("\(status)\n".utf8)) == nil)
        #expect(parser.consume(Data("\(answer)\n".utf8)) == "Answer")
    }

    @Test
    func testStreamingParserUsesAssistantMessageEvents() {
        var parser = CodexConversationStreamParser()
        let line = """
        {"type":"response_item","item":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Complete answer"}]}}
        """

        #expect(parser.consume(Data("\(line)\n".utf8)) == "Complete answer")
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
    func testSettingsThemeSelectionPersistsAndNotifies() throws {
        let suiteName = "DesktopCompanionSettings-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let controller = CompanionSettingsWindowController(userDefaults: defaults)
        var selectedPreset: AppThemePreset?
        controller.onThemeSelected = { preset in
            selectedPreset = preset
        }

        let contentView = try #require(controller.window?.contentView)
        let themePopup = try #require(descendantViews(ofType: NSPopUpButton.self, in: contentView).first)
        themePopup.selectItem(withTitle: AppThemePreset.graphiteDark.title)
        let action = try #require(themePopup.action)
        NSApplication.shared.sendAction(action, to: themePopup.target, from: themePopup)

        #expect(AppThemeStore.selectedPreset(userDefaults: defaults) == .graphiteDark)
        #expect(selectedPreset == .graphiteDark)
        controller.close()
    }

    @Test
    func testNewCompanionInstancesDefaultToAlwaysOnTop() throws {
        let package = try makeCompanionPackage()
        let instance = CompanionInstance.make(package: package, existingCount: 0)

        #expect(instance.layerMode == .alwaysOnTop)
    }

    @Test
    func testInstanceStoreRoundTripsConversationBubbleSize() throws {
        let suiteName = "DesktopCompanionBubbleSize-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let instance = CompanionInstance(
            id: "one",
            packageID: "lego-vader",
            origin: CompanionAnchor(x: 10, y: 20),
            layerMode: .desktop,
            speechAnchor: CompanionAnchor(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .legoSmash,
            conversationBubbleSize: ConversationBubbleSize(width: 480, height: 340)
        )

        CompanionInstanceStore.save([instance], userDefaults: defaults)

        #expect(CompanionInstanceStore.load(userDefaults: defaults) == [instance])
    }

    @Test
    func testInstanceStoreRoundTripsConversationBubbleOffset() throws {
        let suiteName = "DesktopCompanionBubbleOffset-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let instance = CompanionInstance(
            id: "one",
            packageID: "lego-vader",
            origin: CompanionAnchor(x: 10, y: 20),
            layerMode: .desktop,
            speechAnchor: CompanionAnchor(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .legoSmash,
            conversationBubbleOffset: CompanionAnchor(x: -80, y: 44)
        )

        CompanionInstanceStore.save([instance], userDefaults: defaults)

        #expect(CompanionInstanceStore.load(userDefaults: defaults) == [instance])
    }

    @Test
    func testInstanceStoreLoadsLegacyInstancesWithoutConversationBubbleSize() throws {
        let suiteName = "DesktopCompanionLegacyBubbleSize-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let data = """
        [
          {
            "id": "legacy",
            "packageID": "lego-vader",
            "origin": { "x": 10, "y": 20 },
            "layerMode": "desktop",
            "speechAnchor": { "x": 121, "y": 94 },
            "bubblePlacement": "automatic",
            "animationPreset": "legoSmash"
          }
        ]
        """.data(using: .utf8)
        defaults.set(data, forKey: "desktopCompanion.instances")

        let instances = CompanionInstanceStore.load(userDefaults: defaults)

        #expect(instances.count == 1)
        #expect(instances.first?.id == "legacy")
        #expect(instances.first?.conversationBubbleSize == nil)
        #expect(instances.first?.conversationBubbleOffset == nil)
    }

    @Test
    func testInstanceStoreIgnoresMalformedConversationBubbleSize() throws {
        let suiteName = "DesktopCompanionMalformedBubbleSize-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let data = """
        [
          {
            "id": "bad-size",
            "packageID": "lego-vader",
            "origin": { "x": 10, "y": 20 },
            "layerMode": "desktop",
            "speechAnchor": { "x": 121, "y": 94 },
            "bubblePlacement": "automatic",
            "animationPreset": "legoSmash",
            "conversationBubbleSize": { "width": "wide", "height": 340 }
          }
        ]
        """.data(using: .utf8)
        defaults.set(data, forKey: "desktopCompanion.instances")

        let instances = CompanionInstanceStore.load(userDefaults: defaults)

        #expect(instances.count == 1)
        #expect(instances.first?.conversationBubbleSize == nil)
    }

    @Test
    func testInstanceStoreIgnoresMalformedConversationBubbleOffset() throws {
        let suiteName = "DesktopCompanionMalformedBubbleOffset-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let data = """
        [
          {
            "id": "bad-offset",
            "packageID": "lego-vader",
            "origin": { "x": 10, "y": 20 },
            "layerMode": "desktop",
            "speechAnchor": { "x": 121, "y": 94 },
            "bubblePlacement": "automatic",
            "animationPreset": "legoSmash",
            "conversationBubbleOffset": { "x": "left", "y": 44 }
          }
        ]
        """.data(using: .utf8)
        defaults.set(data, forKey: "desktopCompanion.instances")

        let instances = CompanionInstanceStore.load(userDefaults: defaults)

        #expect(instances.count == 1)
        #expect(instances.first?.conversationBubbleOffset == nil)
    }

    @Test
    func testInstanceStoreIgnoresInvalidConversationBubbleSize() throws {
        let suiteName = "DesktopCompanionInvalidBubbleSize-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let data = """
        [
          {
            "id": "invalid-size",
            "packageID": "lego-vader",
            "origin": { "x": 10, "y": 20 },
            "layerMode": "desktop",
            "speechAnchor": { "x": 121, "y": 94 },
            "bubblePlacement": "automatic",
            "animationPreset": "legoSmash",
            "conversationBubbleSize": { "width": -20, "height": 0 }
          }
        ]
        """.data(using: .utf8)
        defaults.set(data, forKey: "desktopCompanion.instances")

        let instances = CompanionInstanceStore.load(userDefaults: defaults)

        #expect(instances.count == 1)
        #expect(instances.first?.conversationBubbleSize == nil)
    }

    @MainActor
    @Test
    func testConversationBubbleLevelTracksCompanionLevel() {
        for mode in CompanionLayerMode.allCases {
            let companionLevel = mode.windowLevel
            let bubbleLevel = ConversationBubbleWindowController.bubbleLevel(for: companionLevel)
            let expectedRawLevel = max(companionLevel.rawValue, NSWindow.Level.floating.rawValue) + 1

            #expect(bubbleLevel.rawValue == expectedRawLevel)
        }

        #expect(
            ConversationBubbleWindowController
                .bubbleLevel(for: CompanionLayerMode.desktop.windowLevel)
                .rawValue > NSWindow.Level.floating.rawValue
        )
        #expect(
            ConversationBubbleWindowController
                .bubbleLevel(for: CompanionLayerMode.alwaysOnTop.windowLevel)
                .rawValue > CompanionLayerMode.alwaysOnTop.windowLevel.rawValue
        )
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

    private func testPackage(id: String, displayName: String? = nil) -> CompanionPackage {
        CompanionPackage(
            id: id,
            displayName: displayName ?? id,
            folderURL: URL(fileURLWithPath: "/tmp/\(id)", isDirectory: true),
            svgURL: URL(fileURLWithPath: "/tmp/\(id)/companion.svg", isDirectory: false),
            conversationThemesDirectoryURL: nil,
            speechAnchor: NSPoint(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .wholeObjectReaction
        )
    }

    private func testInstance(id: String, packageID: String) -> CompanionInstance {
        CompanionInstance(
            id: id,
            packageID: packageID,
            origin: CompanionAnchor(x: 10, y: 20),
            layerMode: .desktop,
            speechAnchor: CompanionAnchor(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .wholeObjectReaction
        )
    }

    @MainActor
    private func descendantViews<View: NSView>(ofType type: View.Type, in root: NSView) -> [View] {
        let matchingRoot = (root as? View).map { [$0] } ?? []
        return matchingRoot + root.subviews.flatMap { descendantViews(ofType: type, in: $0) }
    }

    @MainActor
    private func hasIdleAnimation(in root: NSView) -> Bool {
        descendantViews(ofType: NSView.self, in: root).contains {
            $0.layer?.animation(forKey: "desktopCompanionIdle") != nil
        }
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

    private func rgbaComponents(_ color: NSColor) -> [CGFloat] {
        let color = color.usingColorSpace(.deviceRGB) ?? color
        return [
            color.redComponent,
            color.greenComponent,
            color.blueComponent,
            color.alphaComponent
        ]
    }
}

@MainActor
private func submittedConversationController() throws -> (
    controller: ConversationBubbleWindowController,
    runner: FakeCodexConversationRunner,
    recorder: RunningStateRecorder
) {
    let runner = FakeCodexConversationRunner()
    let recorder = RunningStateRecorder()
    let controller = ConversationBubbleWindowController(runner: runner)
    controller.onRunningStateChanged = { recorder.values.append($0) }

    let inputField = try #require(firstEditableTextField(in: controller.window?.contentView))
    inputField.stringValue = "What is Go?"
    guard let action = inputField.action else {
        Issue.record("Conversation input did not have a submit action")
        return (controller, runner, recorder)
    }

    #expect(NSApp.sendAction(action, to: inputField.target, from: inputField))
    return (controller, runner, recorder)
}

@MainActor
private func firstEditableTextField(in view: NSView?) -> NSTextField? {
    guard let view else {
        return nil
    }

    if let textField = view as? NSTextField,
       textField.isEditable {
        return textField
    }

    for subview in view.subviews {
        if let textField = firstEditableTextField(in: subview) {
            return textField
        }
    }

    return nil
}

@MainActor
private final class FakeCodexConversationRunner: CodexConversationRunning {
    private var completion: ((Result<String, CodexConversationError>) -> Void)?
    private(set) var didCancel = false

    func run(
        question: String,
        history: [CodexConversationTurn],
        streamUpdate: ((String) -> Void)?,
        completion: @escaping (Result<String, CodexConversationError>) -> Void
    ) {
        self.completion = completion
    }

    func cancel() {
        didCancel = true
    }

    func complete(_ result: Result<String, CodexConversationError>) {
        let completion = completion
        self.completion = nil
        completion?(result)
    }
}

private final class RunningStateRecorder {
    var values: [Bool] = []
}
