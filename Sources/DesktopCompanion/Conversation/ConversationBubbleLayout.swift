import AppKit
import Foundation

struct ConversationBubbleMetrics: Equatable {
    let width: CGFloat
    let minHeight: CGFloat
    let maxVisibleHeightRatio: CGFloat
    let contentInsets: NSEdgeInsets
    let inputHeight: CGFloat
    let transcriptInputSpacing: CGFloat
    let tailAnchor: NSPoint

    static func == (lhs: ConversationBubbleMetrics, rhs: ConversationBubbleMetrics) -> Bool {
        lhs.width == rhs.width
            && lhs.minHeight == rhs.minHeight
            && lhs.maxVisibleHeightRatio == rhs.maxVisibleHeightRatio
            && lhs.contentInsets.top == rhs.contentInsets.top
            && lhs.contentInsets.left == rhs.contentInsets.left
            && lhs.contentInsets.bottom == rhs.contentInsets.bottom
            && lhs.contentInsets.right == rhs.contentInsets.right
            && lhs.inputHeight == rhs.inputHeight
            && lhs.transcriptInputSpacing == rhs.transcriptInputSpacing
            && lhs.tailAnchor == rhs.tailAnchor
    }
}

struct ConversationBubbleLayoutResult: Equatable {
    let size: NSSize
    let bodyRect: NSRect
    let transcriptRect: NSRect
    let inputRect: NSRect
    let frame: NSRect
    let connectorStart: NSPoint
    let connectorEnd: NSPoint
    let isTranscriptScrollable: Bool
}

enum ConversationBubbleLayout {
    static let screenMargin: CGFloat = 8
    static let bodyCompanionGap: CGFloat = 12
    private static let connectorPadding: CGFloat = 18

    static func layout(
        metrics: ConversationBubbleMetrics,
        transcriptHeight: CGFloat,
        anchoredAt mouthScreenPoint: NSPoint,
        companionFrame: NSRect,
        visibleFrame: NSRect
    ) -> ConversationBubbleLayoutResult {
        let width = bubbleWidth(metrics: metrics, visibleFrame: visibleFrame)
        let availableHeight = max(visibleFrame.height - (screenMargin * 2), 1)
        let minimumUsableHeight = metrics.contentInsets.top
            + 1
            + metrics.transcriptInputSpacing
            + metrics.inputHeight
            + metrics.contentInsets.bottom
        let maxPreferredHeight = min(
            availableHeight,
            max(visibleFrame.height * metrics.maxVisibleHeightRatio, minimumUsableHeight)
        )
        let aboveSpace = max(visibleFrame.maxY - screenMargin - companionFrame.maxY - bodyCompanionGap, 0)
        let shouldPlaceAbove = aboveSpace >= min(metrics.minHeight, minimumUsableHeight)
        let maxHeight = shouldPlaceAbove ? min(maxPreferredHeight, aboveSpace) : maxPreferredHeight
        let minimumHeight = min(metrics.minHeight, maxHeight)
        let desiredHeight = metrics.contentInsets.top
            + max(transcriptHeight, 1)
            + metrics.transcriptInputSpacing
            + metrics.inputHeight
            + metrics.contentInsets.bottom
        let height = min(max(desiredHeight, minimumHeight), maxHeight)
        let transcriptHeightThatFits = max(
            1,
            height
                - metrics.contentInsets.top
                - metrics.transcriptInputSpacing
                - metrics.inputHeight
                - metrics.contentInsets.bottom
        )
        let size = NSSize(width: width, height: height)
        let bodyFrame = bodyFrame(
            size: size,
            metrics: metrics,
            mouthScreenPoint: mouthScreenPoint,
            companionFrame: companionFrame,
            visibleFrame: visibleFrame,
            placeAbove: shouldPlaceAbove
        )
        let connectorStartScreenPoint = connectorStart(
            bodyFrame: bodyFrame,
            metrics: metrics,
            mouthScreenPoint: mouthScreenPoint
        )
        let frame = windowFrame(
            bodyFrame: bodyFrame,
            connectorStart: connectorStartScreenPoint,
            connectorEnd: mouthScreenPoint
        )
        let bodyRect = NSRect(
            x: bodyFrame.minX - frame.minX,
            y: frame.maxY - bodyFrame.maxY,
            width: bodyFrame.width,
            height: bodyFrame.height
        )
        let transcriptRect = NSRect(
            x: bodyRect.minX + metrics.contentInsets.left,
            y: bodyRect.minY + metrics.contentInsets.top,
            width: contentWidth(metrics: metrics, visibleFrame: visibleFrame),
            height: transcriptHeightThatFits
        )
        let inputRect = NSRect(
            x: bodyRect.minX + metrics.contentInsets.left,
            y: bodyRect.minY + height - metrics.contentInsets.bottom - metrics.inputHeight,
            width: transcriptRect.width,
            height: metrics.inputHeight
        )

        return ConversationBubbleLayoutResult(
            size: size,
            bodyRect: bodyRect,
            transcriptRect: transcriptRect,
            inputRect: inputRect,
            frame: frame,
            connectorStart: NSPoint(
                x: connectorStartScreenPoint.x - frame.minX,
                y: frame.maxY - connectorStartScreenPoint.y
            ),
            connectorEnd: NSPoint(
                x: mouthScreenPoint.x - frame.minX,
                y: frame.maxY - mouthScreenPoint.y
            ),
            isTranscriptScrollable: desiredHeight > maxHeight
        )
    }

    static func contentWidth(metrics: ConversationBubbleMetrics, visibleFrame: NSRect) -> CGFloat {
        let width = bubbleWidth(metrics: metrics, visibleFrame: visibleFrame)
        return max(width - metrics.contentInsets.left - metrics.contentInsets.right, 1)
    }

    private static func bodyFrame(
        size: NSSize,
        metrics: ConversationBubbleMetrics,
        mouthScreenPoint: NSPoint,
        companionFrame: NSRect,
        visibleFrame: NSRect,
        placeAbove: Bool
    ) -> NSRect {
        if placeAbove {
            return NSRect(
                x: clamped(
                    mouthScreenPoint.x - effectiveTailAnchor(metrics: metrics, size: size).x,
                    min: visibleFrame.minX + screenMargin,
                    max: visibleFrame.maxX - size.width - screenMargin
                ),
                y: companionFrame.maxY + bodyCompanionGap,
                width: size.width,
                height: size.height
            )
        }

        let rightX = companionFrame.maxX + bodyCompanionGap
        let leftX = companionFrame.minX - bodyCompanionGap - size.width
        let rightSpace = visibleFrame.maxX - screenMargin - rightX
        let leftSpace = leftX - visibleFrame.minX - screenMargin
        let preferredX = rightSpace >= leftSpace ? rightX : leftX

        return NSRect(
            x: clamped(
                preferredX,
                min: visibleFrame.minX + screenMargin,
                max: visibleFrame.maxX - size.width - screenMargin
            ),
            y: clamped(
                mouthScreenPoint.y - (size.height / 2),
                min: visibleFrame.minY + screenMargin,
                max: visibleFrame.maxY - size.height - screenMargin
            ),
            width: size.width,
            height: size.height
        )
    }

    private static func connectorStart(
        bodyFrame: NSRect,
        metrics: ConversationBubbleMetrics,
        mouthScreenPoint: NSPoint
    ) -> NSPoint {
        if mouthScreenPoint.x < bodyFrame.minX {
            return NSPoint(x: bodyFrame.minX, y: clamped(mouthScreenPoint.y, min: bodyFrame.minY + 24, max: bodyFrame.maxY - 24))
        }

        if mouthScreenPoint.x > bodyFrame.maxX {
            return NSPoint(x: bodyFrame.maxX, y: clamped(mouthScreenPoint.y, min: bodyFrame.minY + 24, max: bodyFrame.maxY - 24))
        }

        let tailAnchor = effectiveTailAnchor(metrics: metrics, size: bodyFrame.size)
        return NSPoint(
            x: bodyFrame.minX + tailAnchor.x,
            y: bodyFrame.minY + tailAnchor.y
        )
    }

    private static func windowFrame(
        bodyFrame: NSRect,
        connectorStart: NSPoint,
        connectorEnd: NSPoint
    ) -> NSRect {
        let connectorFrame = NSRect(
            x: min(connectorStart.x, connectorEnd.x) - connectorPadding,
            y: min(connectorStart.y, connectorEnd.y) - connectorPadding,
            width: abs(connectorStart.x - connectorEnd.x) + (connectorPadding * 2),
            height: abs(connectorStart.y - connectorEnd.y) + (connectorPadding * 2)
        )

        return bodyFrame.union(connectorFrame)
    }

    private static func bubbleWidth(metrics: ConversationBubbleMetrics, visibleFrame: NSRect) -> CGFloat {
        let availableWidth = max(visibleFrame.width - (screenMargin * 2), 1)
        return min(metrics.width, availableWidth)
    }

    private static func effectiveTailAnchor(metrics: ConversationBubbleMetrics, size: NSSize) -> NSPoint {
        NSPoint(
            x: min(metrics.tailAnchor.x, max(size.width - screenMargin, 0)),
            y: min(metrics.tailAnchor.y, max(size.height - screenMargin, 0))
        )
    }

    private static func clamped(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), Swift.max(minimum, maximum))
    }
}
