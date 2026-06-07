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
    let bodyOffset: NSPoint
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
    static let controlTopGutter: CGFloat = 48
    static let controlRightGutter: CGFloat = 56

    static func layout(
        metrics: ConversationBubbleMetrics,
        transcriptHeight: CGFloat,
        anchoredAt mouthScreenPoint: NSPoint,
        companionFrame: NSRect,
        visibleFrame: NSRect,
        placement: CompanionBubblePlacement = .automatic,
        preferredBodySize: NSSize? = nil,
        bodyOffset: NSPoint? = nil
    ) -> ConversationBubbleLayoutResult {
        let availableHeight = max(visibleFrame.height - (screenMargin * 2), 1)
        let insets = effectiveContentInsets(metrics: metrics)
        let minimumUsableHeight = insets.top
            + 1
            + metrics.transcriptInputSpacing
            + metrics.inputHeight
            + insets.bottom
        let maxPreferredHeight = max(availableHeight, minimumUsableHeight)
        let aboveSpace = max(visibleFrame.maxY - screenMargin - companionFrame.maxY - bodyCompanionGap, 0)
        let shouldPlaceAbove = placement == .above
            || (placement == .automatic && aboveSpace >= min(metrics.minHeight, minimumUsableHeight))
        let maxHeight = shouldPlaceAbove ? min(maxPreferredHeight, max(aboveSpace, minimumUsableHeight)) : maxPreferredHeight
        let desiredHeight = insets.top
            + max(transcriptHeight, 1)
            + metrics.transcriptInputSpacing
            + metrics.inputHeight
            + insets.bottom
        let size = bodySize(
            metrics: metrics,
            visibleFrame: visibleFrame,
            maxHeight: maxHeight,
            contentHeight: desiredHeight,
            preferredBodySize: preferredBodySize
        )
        let transcriptHeightThatFits = max(
            1,
            size.height
                - insets.top
                - metrics.transcriptInputSpacing
                - metrics.inputHeight
                - insets.bottom
        )
        let automaticBodyFrame = bodyFrame(
            size: size,
            metrics: metrics,
            mouthScreenPoint: mouthScreenPoint,
            companionFrame: companionFrame,
            visibleFrame: visibleFrame,
            placement: placement,
            placeAbove: shouldPlaceAbove
        )
        let bodyFrame = offsetBodyFrame(
            automaticBodyFrame,
            offset: bodyOffset ?? .zero,
            visibleFrame: visibleFrame
        )
        let effectiveBodyOffset = NSPoint(
            x: bodyFrame.minX - automaticBodyFrame.minX,
            y: bodyFrame.minY - automaticBodyFrame.minY
        )
        let connectorStartScreenPoint = connectorStart(
            bodyFrame: bodyFrame,
            metrics: metrics,
            mouthScreenPoint: mouthScreenPoint
        )
        let frame = windowFrame(bodyFrame: bodyFrame)
        let bodyRect = NSRect(
            x: bodyFrame.minX - frame.minX,
            y: frame.maxY - bodyFrame.maxY,
            width: bodyFrame.width,
            height: bodyFrame.height
        )
        let transcriptRect = NSRect(
            x: bodyRect.minX + insets.left,
            y: bodyRect.minY + insets.top,
            width: contentWidth(metrics: metrics, visibleFrame: visibleFrame, preferredBodySize: preferredBodySize),
            height: transcriptHeightThatFits
        )
        let inputRect = NSRect(
            x: bodyRect.minX + insets.left,
            y: bodyRect.minY + size.height - insets.bottom - metrics.inputHeight,
            width: transcriptRect.width,
            height: metrics.inputHeight
        )

        return ConversationBubbleLayoutResult(
            size: size,
            bodyOffset: effectiveBodyOffset,
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
            isTranscriptScrollable: desiredHeight > size.height
        )
    }

    static func contentWidth(
        metrics: ConversationBubbleMetrics,
        visibleFrame: NSRect,
        preferredBodySize: NSSize? = nil
    ) -> CGFloat {
        let width = bodyWidth(metrics: metrics, visibleFrame: visibleFrame, preferredBodySize: preferredBodySize)
        let insets = effectiveContentInsets(metrics: metrics)
        return max(width - insets.left - insets.right, 1)
    }

    static func bodySize(
        metrics: ConversationBubbleMetrics,
        visibleFrame: NSRect,
        maxHeight: CGFloat? = nil,
        contentHeight: CGFloat? = nil,
        preferredBodySize: NSSize? = nil
    ) -> NSSize {
        let heightLimit = maxHeight ?? max(
            visibleFrame.height - (screenMargin * 2),
            minimumUsableHeight(metrics: metrics)
        )
        let minimumHeight = min(minimumUsableHeight(metrics: metrics), heightLimit)
        let desiredHeight = max(
            minimumUsableHeight(metrics: metrics),
            preferredBodySize?.height ?? 0,
            contentHeight ?? 0
        )

        return NSSize(
            width: bodyWidth(metrics: metrics, visibleFrame: visibleFrame, preferredBodySize: preferredBodySize),
            height: clamped(desiredHeight, min: minimumHeight, max: heightLimit)
        )
    }

    private static func offsetBodyFrame(
        _ bodyFrame: NSRect,
        offset: NSPoint,
        visibleFrame: NSRect
    ) -> NSRect {
        NSRect(
            x: clamped(
                bodyFrame.minX + offset.x,
                min: visibleFrame.minX + screenMargin,
                max: visibleFrame.maxX - bodyFrame.width - screenMargin
            ),
            y: clamped(
                bodyFrame.minY + offset.y,
                min: visibleFrame.minY + screenMargin,
                max: visibleFrame.maxY - bodyFrame.height - screenMargin
            ),
            width: bodyFrame.width,
            height: bodyFrame.height
        )
    }

    private static func bodyFrame(
        size: NSSize,
        metrics: ConversationBubbleMetrics,
        mouthScreenPoint: NSPoint,
        companionFrame: NSRect,
        visibleFrame: NSRect,
        placement: CompanionBubblePlacement,
        placeAbove: Bool
    ) -> NSRect {
        if placeAbove {
            return NSRect(
                x: clamped(
                    mouthScreenPoint.x - effectiveTailAnchor(metrics: metrics, size: size).x,
                    min: visibleFrame.minX + screenMargin,
                    max: visibleFrame.maxX - size.width - screenMargin
                ),
                y: clamped(
                    companionFrame.maxY + bodyCompanionGap,
                    min: visibleFrame.minY + screenMargin,
                    max: visibleFrame.maxY - size.height - screenMargin
                ),
                width: size.width,
                height: size.height
            )
        }

        let rightX = companionFrame.maxX + bodyCompanionGap
        let leftX = companionFrame.minX - bodyCompanionGap - size.width
        let rightSpace = visibleFrame.maxX - screenMargin - rightX
        let leftSpace = leftX - visibleFrame.minX - screenMargin
        let preferredX: CGFloat
        switch placement {
        case .left:
            preferredX = leftX
        case .right:
            preferredX = rightX
        case .automatic, .above:
            preferredX = rightSpace >= leftSpace ? rightX : leftX
        }

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

    private static func windowFrame(bodyFrame: NSRect) -> NSRect {
        bodyFrame
    }

    private static func bodyWidth(
        metrics: ConversationBubbleMetrics,
        visibleFrame: NSRect,
        preferredBodySize: NSSize?
    ) -> CGFloat {
        let availableWidth = max(visibleFrame.width - (screenMargin * 2), 1)
        let insets = effectiveContentInsets(metrics: metrics)
        let minimumWidth = min(
            metrics.width,
            max(insets.left + insets.right + 160, 220)
        )
        let desiredWidth = preferredBodySize?.width ?? metrics.width
        return clamped(desiredWidth, min: min(minimumWidth, availableWidth), max: availableWidth)
    }

    private static func minimumUsableHeight(metrics: ConversationBubbleMetrics) -> CGFloat {
        let insets = effectiveContentInsets(metrics: metrics)
        return insets.top
            + 1
            + metrics.transcriptInputSpacing
            + metrics.inputHeight
            + insets.bottom
    }

    private static func effectiveContentInsets(metrics: ConversationBubbleMetrics) -> NSEdgeInsets {
        NSEdgeInsets(
            top: max(metrics.contentInsets.top, controlTopGutter),
            left: metrics.contentInsets.left,
            bottom: metrics.contentInsets.bottom,
            right: max(metrics.contentInsets.right, controlRightGutter)
        )
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
