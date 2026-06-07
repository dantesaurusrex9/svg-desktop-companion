import AppKit
import Testing
@testable import DesktopCompanion

struct ConversationLayoutTests {
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

}
