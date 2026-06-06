import AppKit
import QuartzCore

final class ConversationBubbleWindowController: NSWindowController, NSWindowDelegate {
    private let runner: CodexConversationRunner
    private let rootView = NSView()
    private let hoverView = NSView()
    private let connectorView = ConversationConnectorView()
    private let bubbleView = NSView()
    private let backgroundImageView = NSImageView()
    private let scrollView = NSScrollView()
    private let transcriptView = ConversationTranscriptView()
    private let inputContainerView = NSView()
    private let inputField = NSTextField()
    private let closeButton = NSButton()
    private let package: CompanionPackage?
    private let bubblePlacement: CompanionBubblePlacement
    private var theme: ConversationTheme
    private var themeConstraints: [NSLayoutConstraint] = []
    private var lastAnchor: NSPoint?
    private var lastCompanionFrame: NSRect?
    private var history: [CodexConversationTurn] = []
    private var pendingQuestion: String?
    private var isRunning = false
    private let hoverAnimationKey = "desktopCompanionConversationHover"

    init(
        package: CompanionPackage? = CompanionPackageLoader.selectedPackage(),
        bubblePlacement: CompanionBubblePlacement = .automatic,
        runner: CodexConversationRunner = CodexConversationRunner()
    ) {
        self.package = package
        self.bubblePlacement = bubblePlacement
        self.runner = runner
        self.theme = ConversationThemeLoader.selectedTheme(package: package)

        let panel = ConversationBubblePanel(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(width: theme.metrics.width, height: theme.metrics.minHeight)
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        super.init(window: panel)

        panel.delegate = self
        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(anchoredAt mouthScreenPoint: NSPoint, companionFrame: NSRect, level: NSWindow.Level) {
        guard let window else {
            return
        }

        window.level = bubbleLevel(for: level)
        lastAnchor = mouthScreenPoint
        lastCompanionFrame = companionFrame
        applyLayout(companionFrame: companionFrame)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        startHoverAnimation()
        inputField.becomeFirstResponder()
    }

    func move(anchoredAt mouthScreenPoint: NSPoint, companionFrame: NSRect) {
        lastAnchor = mouthScreenPoint
        lastCompanionFrame = companionFrame
        guard let window, window.isVisible else {
            return
        }

        applyLayout(companionFrame: companionFrame)
        window.orderFrontRegardless()
    }

    func closeBubble() {
        runner.cancel()
        stopHoverAnimation()
        window?.orderOut(nil)
    }

    func reloadTheme() {
        theme = ConversationThemeLoader.selectedTheme(package: package)
        applyTheme()
    }

    func selectTheme(id themeID: String) {
        ConversationThemeLoader.saveSelectedThemeID(themeID, package: package)
        reloadTheme()
    }

    var selectedThemeID: String {
        theme.id
    }

    var availableThemes: [ConversationThemeSummary] {
        ConversationThemeLoader.availableThemeSummaries(package: package)
    }

    func windowWillClose(_ notification: Notification) {
        runner.cancel()
        stopHoverAnimation()
    }

    static func frame(
        anchoredAt mouthScreenPoint: NSPoint,
        theme: ConversationTheme,
        companionFrame: NSRect,
        visibleFrame: NSRect? = nil
    ) -> NSRect {
        let frameToUse = visibleFrame ?? NSScreen.screens
            .first(where: { $0.visibleFrame.contains(mouthScreenPoint) })?
            .visibleFrame ?? NSScreen.main?.visibleFrame

        guard let frameToUse else {
            return NSRect(
                x: mouthScreenPoint.x - theme.metrics.tailAnchor.x,
                y: mouthScreenPoint.y - theme.metrics.tailAnchor.y,
                width: theme.metrics.width,
                height: theme.metrics.minHeight
            )
        }

        return ConversationBubbleLayout.layout(
            metrics: theme.metrics,
            transcriptHeight: 1,
            anchoredAt: mouthScreenPoint,
            companionFrame: companionFrame,
            visibleFrame: frameToUse
        ).frame
    }

    private func setupViews() {
        guard let window else {
            return
        }

        hoverView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        connectorView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        transcriptView.translatesAutoresizingMaskIntoConstraints = true
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        inputField.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        hoverView.wantsLayer = true
        hoverView.layer?.backgroundColor = NSColor.clear.cgColor
        bubbleView.wantsLayer = true
        bubbleView.layer?.backgroundColor = NSColor.clear.cgColor
        connectorView.wantsLayer = true
        connectorView.layer?.backgroundColor = NSColor.clear.cgColor

        backgroundImageView.imageScaling = .scaleAxesIndependently
        backgroundImageView.imageAlignment = .alignCenter

        transcriptView.items = ConversationTranscriptViewModel(
            history: [],
            pendingQuestion: nil,
            status: nil
        ).items

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = transcriptView

        inputContainerView.wantsLayer = true
        inputContainerView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.86).cgColor
        inputContainerView.layer?.borderColor = NSColor.black.withAlphaComponent(0.10).cgColor
        inputContainerView.layer?.borderWidth = 1
        inputContainerView.layer?.cornerRadius = 21

        inputField.font = NSFont.systemFont(ofSize: 15)
        inputField.placeholderString = "Ask anything"
        inputField.isBezeled = false
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.target = self
        inputField.action = #selector(submitRequested)
        inputField.cell?.wraps = false
        inputField.cell?.isScrollable = true

        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.imageScaling = .scaleProportionallyUpOrDown
        closeButton.contentTintColor = NSColor.secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeRequested)

        rootView.addSubview(hoverView)
        hoverView.addSubview(bubbleView)
        hoverView.addSubview(connectorView, positioned: .below, relativeTo: bubbleView)
        bubbleView.addSubview(backgroundImageView)
        bubbleView.addSubview(scrollView)
        bubbleView.addSubview(inputContainerView)
        inputContainerView.addSubview(inputField)
        bubbleView.addSubview(closeButton)
        window.contentView = rootView

        NSLayoutConstraint.activate([
            hoverView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            hoverView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            hoverView.topAnchor.constraint(equalTo: rootView.topAnchor),
            hoverView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            connectorView.leadingAnchor.constraint(equalTo: hoverView.leadingAnchor),
            connectorView.trailingAnchor.constraint(equalTo: hoverView.trailingAnchor),
            connectorView.topAnchor.constraint(equalTo: hoverView.topAnchor),
            connectorView.bottomAnchor.constraint(equalTo: hoverView.bottomAnchor),

            backgroundImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            backgroundImageView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -28),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 22),

            inputField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 14),
            inputField.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -14),
            inputField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 22)
        ])

        applyTheme()
    }

    @objc private func submitRequested() {
        let question = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isRunning else {
            return
        }

        pendingQuestion = question
        isRunning = true
        inputField.stringValue = ""
        inputField.isEnabled = false
        renderTranscript(status: "Thinking...")

        runner.run(question: question, history: history) { [weak self] result in
            guard let self else {
                return
            }

            self.isRunning = false
            self.inputField.isEnabled = true
            self.inputField.becomeFirstResponder()

            switch result {
            case .success(let answer):
                if let pendingQuestion = self.pendingQuestion {
                    self.history.append(CodexConversationTurn(question: pendingQuestion, answer: answer))
                }
                self.pendingQuestion = nil
                self.renderTranscript()
            case .failure(let error):
                self.renderTranscript(status: error.userMessage)
            }
        }
    }

    @objc private func closeRequested() {
        closeBubble()
    }

    private func renderTranscript(status: String? = nil) {
        let model = ConversationTranscriptViewModel(
            history: history,
            pendingQuestion: pendingQuestion,
            status: status
        )
        transcriptView.items = model.items
        applyLayout()
        scrollTranscriptToBottom()
    }

    private func bubbleLevel(for companionLevel: NSWindow.Level) -> NSWindow.Level {
        NSWindow.Level(rawValue: max(companionLevel.rawValue, NSWindow.Level.floating.rawValue) + 1)
    }

    private func applyTheme() {
        backgroundImageView.image = theme.bubbleImage
        connectorView.fillColor = theme.tailStyle.fillColor
        connectorView.strokeColor = theme.tailStyle.strokeColor
        applyLayout()
    }

    private func applyLayout(companionFrame: NSRect? = nil) {
        let anchor = lastAnchor ?? NSPoint(x: theme.metrics.tailAnchor.x, y: theme.metrics.tailAnchor.y)
        let companionFrame = companionFrame ?? lastCompanionFrame ?? NSRect(
            x: anchor.x - 1,
            y: anchor.y - 1,
            width: 2,
            height: 2
        )
        let visibleFrame = visibleFrame(containing: anchor)
        let transcriptHeight = measuredTranscriptHeight(
            width: ConversationBubbleLayout.contentWidth(metrics: theme.metrics, visibleFrame: visibleFrame)
        )
        let layout = ConversationBubbleLayout.layout(
            metrics: theme.metrics,
            transcriptHeight: transcriptHeight,
            anchoredAt: anchor,
            companionFrame: companionFrame,
            visibleFrame: visibleFrame,
            placement: bubblePlacement
        )

        connectorView.connectorStart = layout.connectorStart
        connectorView.connectorEnd = layout.connectorEnd
        connectorView.needsDisplay = true
        scrollView.hasVerticalScroller = layout.isTranscriptScrollable
        inputContainerView.layer?.cornerRadius = layout.inputRect.height / 2
        transcriptView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: layout.transcriptRect.width,
                height: max(layout.transcriptRect.height, transcriptHeight)
            )
        )
        transcriptView.needsLayout = true

        NSLayoutConstraint.deactivate(themeConstraints)
        themeConstraints = [
            bubbleView.leadingAnchor.constraint(equalTo: hoverView.leadingAnchor, constant: layout.bodyRect.minX),
            bubbleView.topAnchor.constraint(equalTo: hoverView.topAnchor, constant: layout.bodyRect.minY),
            bubbleView.widthAnchor.constraint(equalToConstant: layout.bodyRect.width),
            bubbleView.heightAnchor.constraint(equalToConstant: layout.bodyRect.height),

            scrollView.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: layout.transcriptRect.minX - layout.bodyRect.minX
            ),
            scrollView.topAnchor.constraint(
                equalTo: bubbleView.topAnchor,
                constant: layout.transcriptRect.minY - layout.bodyRect.minY
            ),
            scrollView.widthAnchor.constraint(equalToConstant: layout.transcriptRect.width),
            scrollView.heightAnchor.constraint(equalToConstant: layout.transcriptRect.height),

            inputContainerView.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: layout.inputRect.minX - layout.bodyRect.minX
            ),
            inputContainerView.topAnchor.constraint(
                equalTo: bubbleView.topAnchor,
                constant: layout.inputRect.minY - layout.bodyRect.minY
            ),
            inputContainerView.widthAnchor.constraint(equalToConstant: layout.inputRect.width),
            inputContainerView.heightAnchor.constraint(equalToConstant: layout.inputRect.height)
        ]
        NSLayoutConstraint.activate(themeConstraints)

        guard let window else {
            return
        }

        if window.frame != layout.frame {
            window.setFrame(layout.frame, display: true)
        }
    }

    private func measuredTranscriptHeight(width: CGFloat) -> CGFloat {
        transcriptView.measuredHeight(width: width)
    }

    private func scrollTranscriptToBottom() {
        let visibleHeight = scrollView.contentView.bounds.height
        let nextY = max(transcriptView.frame.height - visibleHeight, 0)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: nextY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func visibleFrame(containing point: NSPoint) -> NSRect {
        NSScreen.screens
            .first(where: { $0.visibleFrame.contains(point) })?
            .visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func startHoverAnimation() {
        guard let layer = hoverView.layer,
              layer.animation(forKey: hoverAnimationKey) == nil else {
            return
        }

        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animation.values = [0, -4, 0, 3, 0]
        animation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        animation.duration = 3.8
        animation.repeatCount = .infinity
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        layer.add(animation, forKey: hoverAnimationKey)
    }

    private func stopHoverAnimation() {
        hoverView.layer?.removeAnimation(forKey: hoverAnimationKey)
    }
}

private final class ConversationBubblePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

private final class ConversationTranscriptView: NSView {
    var items: [ConversationTranscriptItem] = [.emptyPrompt("Ask me anything.")] {
        didSet {
            rebuildRows()
        }
    }
    private var rowViews: [TranscriptRowView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        rebuildRows()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    func measuredHeight(width: CGFloat) -> CGFloat {
        let rows = rowLayouts(width: width)
        guard let lastRow = rows.last else {
            return 1
        }

        return ceil(lastRow.frame.maxY)
    }

    override func layout() {
        super.layout()
        layoutRows(width: bounds.width)
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func rebuildRows() {
        for rowView in rowViews {
            rowView.removeFromSuperview()
        }

        rowViews = items.map { TranscriptRowView(item: $0) }
        for rowView in rowViews {
            addSubview(rowView)
        }
        needsLayout = true
    }

    private func layoutRows(width: CGFloat) {
        let rows = rowLayouts(width: width)
        for (rowView, row) in zip(rowViews, rows) {
            rowView.apply(row: row)
        }
    }

    private func rowLayouts(width: CGFloat) -> [RowLayout] {
        let width = max(width, 1)
        var rows: [RowLayout] = []
        var y: CGFloat = 0

        for item in items {
            let attributedText = attributedString(for: item)
            let isBubble = item.isMessage
            let maxTextWidth = isBubble ? max((width * 0.78) - 24, 1) : width
            let textBounds = attributedText.boundingRect(
                with: NSSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            let textSize = NSSize(width: ceil(textBounds.width), height: ceil(textBounds.height))

            if isBubble {
                let maxBubbleWidth = max(width * 0.78, 1)
                let bubbleWidth = min(max(max(textSize.width + 24, 56), 1), maxBubbleWidth)
                let bubbleHeight = textSize.height + 16
                let bubbleX = item.isUserMessage ? width - bubbleWidth : 0
                let bubbleRect = NSRect(x: bubbleX, y: y, width: bubbleWidth, height: bubbleHeight)
                rows.append(
                    RowLayout(
                        item: item,
                        frame: NSRect(x: 0, y: y, width: width, height: bubbleHeight),
                        bubbleRect: bubbleRect,
                        textRect: NSRect(
                            x: bubbleRect.minX + 12,
                            y: bubbleRect.minY + 8,
                            width: bubbleRect.width - 24,
                            height: textSize.height
                        ),
                        attributedText: attributedText
                    )
                )
                y += bubbleHeight + 10
            } else {
                rows.append(
                    RowLayout(
                        item: item,
                        frame: NSRect(x: 0, y: y, width: width, height: textSize.height),
                        bubbleRect: .zero,
                        textRect: NSRect(x: 0, y: y, width: width, height: textSize.height),
                        attributedText: attributedText
                    )
                )
                y += textSize.height + 10
            }
        }

        return rows
    }

    private func attributedString(for item: ConversationTranscriptItem) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let font: NSFont
        let color: NSColor
        switch item {
        case .emptyPrompt:
            font = NSFont.systemFont(ofSize: 16, weight: .medium)
            color = .labelColor
        case .status:
            font = NSFont.systemFont(ofSize: 13)
            color = .secondaryLabelColor
        case .user, .assistant:
            font = NSFont.systemFont(ofSize: 14)
            color = .labelColor
        }

        return NSAttributedString(
            string: item.text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )
    }
}

private final class TranscriptRowView: NSView {
    private let item: ConversationTranscriptItem
    private let textView = NSTextView()

    init(item: ConversationTranscriptItem) {
        self.item = item
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    func apply(row: RowLayout) {
        if item.isMessage {
            frame = row.bubbleRect
            textView.frame = NSRect(
                x: 12,
                y: 8,
                width: max(row.bubbleRect.width - 24, 1),
                height: row.textRect.height
            )
        } else {
            frame = row.textRect
            textView.frame = bounds
        }

        textView.textContainer?.containerSize = NSSize(
            width: max(textView.frame.width, 1),
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = item.bubbleFillColor?.cgColor ?? NSColor.clear.cgColor
        layer?.borderColor = item.bubbleFillColor == nil ? NSColor.clear.cgColor : NSColor.black.withAlphaComponent(0.05).cgColor
        layer?.borderWidth = item.bubbleFillColor == nil ? 0 : 1
        layer?.cornerRadius = item.bubbleFillColor == nil ? 0 : 14

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.font = item.font
        textView.textColor = item.textColor
        textView.string = item.text
        textView.setAccessibilityLabel(item.text)

        addSubview(textView)
    }
}

private struct RowLayout {
    let item: ConversationTranscriptItem
    let frame: NSRect
    let bubbleRect: NSRect
    let textRect: NSRect
    let attributedText: NSAttributedString
}

private extension ConversationTranscriptItem {
    var text: String {
        switch self {
        case .emptyPrompt(let text), .user(let text), .assistant(let text), .status(let text):
            text
        }
    }

    var isMessage: Bool {
        switch self {
        case .user, .assistant:
            true
        case .emptyPrompt, .status:
            false
        }
    }

    var isUserMessage: Bool {
        switch self {
        case .user:
            true
        case .assistant, .emptyPrompt, .status:
            false
        }
    }

    var bubbleFillColor: NSColor? {
        switch self {
        case .user:
            NSColor.systemBlue.withAlphaComponent(0.14)
        case .assistant:
            NSColor.black.withAlphaComponent(0.06)
        case .emptyPrompt, .status:
            nil
        }
    }

    var font: NSFont {
        switch self {
        case .emptyPrompt:
            NSFont.systemFont(ofSize: 16, weight: .medium)
        case .status:
            NSFont.systemFont(ofSize: 13)
        case .user, .assistant:
            NSFont.systemFont(ofSize: 14)
        }
    }

    var textColor: NSColor {
        switch self {
        case .status:
            .secondaryLabelColor
        case .emptyPrompt, .user, .assistant:
            .labelColor
        }
    }
}

private final class ConversationConnectorView: NSView {
    var connectorStart: NSPoint = .zero
    var connectorEnd: NSPoint = .zero
    var fillColor: NSColor = ConversationTailStyle.defaultStyle.fillColor {
        didSet {
            needsDisplay = true
        }
    }
    var strokeColor: NSColor = ConversationTailStyle.defaultStyle.strokeColor {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let delta = NSPoint(
            x: connectorEnd.x - connectorStart.x,
            y: connectorEnd.y - connectorStart.y
        )
        let length = max(hypot(delta.x, delta.y), 1)
        let halfWidth: CGFloat = 12
        let normal = NSPoint(
            x: -delta.y / length * halfWidth,
            y: delta.x / length * halfWidth
        )

        let path = NSBezierPath()
        path.move(to: NSPoint(x: connectorStart.x + normal.x, y: connectorStart.y + normal.y))
        path.line(to: connectorEnd)
        path.line(to: NSPoint(x: connectorStart.x - normal.x, y: connectorStart.y - normal.y))
        path.close()

        fillColor.setFill()
        path.fill()
        strokeColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
