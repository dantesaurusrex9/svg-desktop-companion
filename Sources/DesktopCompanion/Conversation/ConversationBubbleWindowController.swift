import AppKit
import QuartzCore

final class ConversationBubbleWindowController: NSWindowController, NSWindowDelegate {
    private let runner: CodexConversationRunning
    private let rootView = NSView()
    private let hoverView = NSView()
    private let bubbleView = ConversationBubbleBodyView()
    private let scrollView = NSScrollView()
    private let transcriptView = ConversationTranscriptView()
    private let inputContainerView = NSView()
    private let inputField = NSTextField()
    private let closeButton = NSButton()
    private let dragHandleView = ConversationDragHandleView()
    private let resizeGripView = ConversationResizeGripView()
    private let package: CompanionPackage?
    private let bubblePlacement: CompanionBubblePlacement
    private var theme: ConversationTheme
    private var preferredBodySize: NSSize?
    private var bodyOffset: NSPoint?
    private var themeConstraints: [NSLayoutConstraint] = []
    private var lastAnchor: NSPoint?
    private var lastCompanionFrame: NSRect?
    private var currentLayout: ConversationBubbleLayoutResult?
    private var moveStartScreenPoint: NSPoint?
    private var moveStartBodyOffset: NSPoint?
    private var resizeStartScreenPoint: NSPoint?
    private var resizeStartBodySize: NSSize?
    private var resizeStartBodyFrame: NSRect?
    private var history: [CodexConversationTurn] = []
    private var pendingQuestion: String?
    private var streamingAnswer: String?
    private var isRunning = false
    private let hoverAnimationKey = "desktopCompanionConversationHover"
    var onBodySizeChanged: ((NSSize) -> Void)?
    var onBodyOffsetChanged: ((NSPoint?) -> Void)?
    var onRunningStateChanged: ((Bool) -> Void)?

    init(
        package: CompanionPackage? = CompanionPackageLoader.selectedPackage(),
        bubblePlacement: CompanionBubblePlacement = .automatic,
        preferredBodySize: NSSize? = nil,
        bodyOffset: NSPoint? = nil,
        runner: CodexConversationRunning = CodexConversationRunner()
    ) {
        self.package = package
        self.bubblePlacement = bubblePlacement
        self.preferredBodySize = preferredBodySize
        self.bodyOffset = bodyOffset
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
        panel.hasShadow = false
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

        setCompanionLevel(level)
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
        setRunning(false)
        stopHoverAnimation()
        window?.orderOut(nil)
    }

    func setCompanionLevel(_ companionLevel: NSWindow.Level) {
        guard let window else {
            return
        }

        window.level = Self.bubbleLevel(for: companionLevel)
        if window.isVisible {
            window.orderFrontRegardless()
        }
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

    var conversationTextStyle: ConversationTranscriptStyle {
        transcriptView.textStyle
    }

    func updateConversationTextStyle(_ style: ConversationTranscriptStyle) {
        transcriptView.updateTextStyle(style)
        applyLayout()
        scrollTranscriptToBottom()
    }

    func windowWillClose(_ notification: Notification) {
        runner.cancel()
        setRunning(false)
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
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        transcriptView.translatesAutoresizingMaskIntoConstraints = true
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        inputField.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        dragHandleView.translatesAutoresizingMaskIntoConstraints = false
        resizeGripView.translatesAutoresizingMaskIntoConstraints = false

        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        hoverView.wantsLayer = true
        hoverView.layer?.backgroundColor = NSColor.clear.cgColor
        bubbleView.wantsLayer = true
        bubbleView.layer?.backgroundColor = NSColor.clear.cgColor
        bubbleView.layer?.borderColor = NSColor.clear.cgColor
        bubbleView.layer?.borderWidth = 0
        bubbleView.layer?.cornerRadius = 0
        bubbleView.layer?.masksToBounds = true
        transcriptView.items = ConversationTranscriptViewModel(
            history: [],
            pendingQuestion: nil,
            streamingAnswer: nil,
            status: nil
        ).items

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = transcriptView

        inputContainerView.wantsLayer = true
        inputContainerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.24).cgColor
        inputContainerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.24).cgColor
        inputContainerView.layer?.borderWidth = 1
        inputContainerView.layer?.cornerRadius = 19

        inputField.font = NSFont.systemFont(ofSize: 15)
        inputField.placeholderAttributedString = NSAttributedString(
            string: "Ask anything",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.68),
                .font: NSFont.systemFont(ofSize: 15)
            ]
        )
        inputField.textColor = NSColor.white.withAlphaComponent(0.94)
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
        closeButton.contentTintColor = NSColor.white.withAlphaComponent(0.62)
        closeButton.toolTip = "Close"
        closeButton.target = self
        closeButton.action = #selector(closeRequested)

        dragHandleView.onMoveBegan = { [weak self] point in
            self?.beginMove(at: point)
        }
        dragHandleView.onMoveChanged = { [weak self] point in
            self?.move(to: point)
        }
        dragHandleView.onMoveEnded = { [weak self] in
            self?.finishMove()
        }
        resizeGripView.onResizeBegan = { [weak self] point in
            self?.beginResize(at: point)
        }
        resizeGripView.onResizeChanged = { [weak self] point in
            self?.resize(to: point)
        }
        resizeGripView.onResizeEnded = { [weak self] in
            self?.finishResize()
        }
        bubbleView.onMoveBegan = { [weak self] point in
            self?.beginMove(at: point)
        }
        bubbleView.onMoveChanged = { [weak self] point in
            self?.move(to: point)
        }
        bubbleView.onMoveEnded = { [weak self] in
            self?.finishMove()
        }

        rootView.addSubview(hoverView)
        hoverView.addSubview(bubbleView)
        bubbleView.addSubview(scrollView)
        bubbleView.addSubview(inputContainerView)
        inputContainerView.addSubview(inputField)
        bubbleView.addSubview(dragHandleView)
        bubbleView.addSubview(closeButton)
        bubbleView.addSubview(resizeGripView)
        window.contentView = rootView

        NSLayoutConstraint.activate([
            hoverView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            hoverView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            hoverView.topAnchor.constraint(equalTo: rootView.topAnchor),
            hoverView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -28),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 22),

            dragHandleView.centerXAnchor.constraint(equalTo: bubbleView.centerXAnchor),
            dragHandleView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 6),
            dragHandleView.widthAnchor.constraint(equalToConstant: 116),
            dragHandleView.heightAnchor.constraint(equalToConstant: 28),

            resizeGripView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -6),
            resizeGripView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -4),
            resizeGripView.widthAnchor.constraint(equalToConstant: 44),
            resizeGripView.heightAnchor.constraint(equalToConstant: 44),

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
        streamingAnswer = nil
        setRunning(true)
        inputField.stringValue = ""
        inputField.isEnabled = false
        renderTranscript(status: "Thinking...")

        runner.run(question: question, history: history) { [weak self] streamedText in
            guard let self else {
                return
            }

            self.streamingAnswer = streamedText
            self.renderTranscript()
        } completion: { [weak self] result in
            guard let self else {
                return
            }

            self.setRunning(false)
            self.inputField.isEnabled = true
            self.inputField.becomeFirstResponder()

            switch result {
            case .success(let answer):
                if let pendingQuestion = self.pendingQuestion {
                    self.history.append(CodexConversationTurn(question: pendingQuestion, answer: answer))
                }
                self.pendingQuestion = nil
                self.streamingAnswer = nil
                self.renderTranscript()
            case .failure(let error):
                self.streamingAnswer = nil
                self.renderTranscript(status: error.userMessage)
            }
        }
    }

    private func setRunning(_ isRunning: Bool) {
        guard self.isRunning != isRunning else {
            return
        }

        self.isRunning = isRunning
        onRunningStateChanged?(isRunning)
    }

    @objc private func closeRequested() {
        closeBubble()
    }

    private func renderTranscript(status: String? = nil) {
        let model = ConversationTranscriptViewModel(
            history: history,
            pendingQuestion: pendingQuestion,
            streamingAnswer: streamingAnswer,
            status: status
        )
        transcriptView.items = model.items
        applyLayout()
        scrollTranscriptToBottom()
    }

    static func bubbleLevel(for companionLevel: NSWindow.Level) -> NSWindow.Level {
        NSWindow.Level(rawValue: max(companionLevel.rawValue, NSWindow.Level.floating.rawValue) + 1)
    }

    nonisolated static func bodyOffsetForBottomRightResize(
        startBodyFrame: NSRect,
        automaticBodyFrame: NSRect
    ) -> NSPoint {
        NSPoint(
            x: startBodyFrame.minX - automaticBodyFrame.minX,
            y: startBodyFrame.maxY - automaticBodyFrame.height - automaticBodyFrame.minY
        )
    }

    private func applyTheme() {
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
            width: ConversationBubbleLayout.contentWidth(
                metrics: theme.metrics,
                visibleFrame: visibleFrame,
                preferredBodySize: preferredBodySize
            )
        )
        let layout = ConversationBubbleLayout.layout(
            metrics: theme.metrics,
            transcriptHeight: transcriptHeight,
            anchoredAt: anchor,
            companionFrame: companionFrame,
            visibleFrame: visibleFrame,
            placement: bubblePlacement,
            preferredBodySize: preferredBodySize,
            bodyOffset: bodyOffset
        )
        currentLayout = layout
        bodyOffset = normalizedOffset(layout.bodyOffset)

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

    private func beginResize(at screenPoint: NSPoint) {
        guard let layout = currentLayout else {
            return
        }

        let bodyScreenRect = bodyScreenRect(from: layout)
        resizeStartScreenPoint = screenPoint
        resizeStartBodySize = layout.size
        resizeStartBodyFrame = bodyScreenRect
    }

    private func beginMove(at screenPoint: NSPoint) {
        moveStartScreenPoint = screenPoint
        moveStartBodyOffset = bodyOffset ?? .zero
    }

    private func move(to screenPoint: NSPoint) {
        guard let moveStartScreenPoint,
              let moveStartBodyOffset else {
            return
        }

        let delta = NSPoint(
            x: screenPoint.x - moveStartScreenPoint.x,
            y: screenPoint.y - moveStartScreenPoint.y
        )
        bodyOffset = NSPoint(
            x: moveStartBodyOffset.x + delta.x,
            y: moveStartBodyOffset.y + delta.y
        )
        applyLayout()
    }

    private func finishMove() {
        defer {
            moveStartScreenPoint = nil
            moveStartBodyOffset = nil
        }

        guard let layout = currentLayout else {
            return
        }

        bodyOffset = normalizedOffset(layout.bodyOffset)
        onBodyOffsetChanged?(bodyOffset)
    }

    private func resize(to screenPoint: NSPoint) {
        guard let resizeStartScreenPoint,
              let resizeStartBodySize,
              let resizeStartBodyFrame else {
            return
        }

        let delta = NSPoint(
            x: screenPoint.x - resizeStartScreenPoint.x,
            y: screenPoint.y - resizeStartScreenPoint.y
        )
        let nextPreferredBodySize = NSSize(
            width: max(resizeStartBodySize.width + delta.x, 1),
            height: max(resizeStartBodySize.height - delta.y, 1)
        )
        preferredBodySize = nextPreferredBodySize
        if let automaticBodyFrame = automaticBodyScreenRect(preferredBodySize: nextPreferredBodySize) {
            bodyOffset = Self.bodyOffsetForBottomRightResize(
                startBodyFrame: resizeStartBodyFrame,
                automaticBodyFrame: automaticBodyFrame
            )
        }
        applyLayout()
    }

    private func finishResize() {
        defer {
            resizeStartScreenPoint = nil
            resizeStartBodySize = nil
            resizeStartBodyFrame = nil
        }

        guard let layout = currentLayout else {
            return
        }

        preferredBodySize = layout.size
        bodyOffset = normalizedOffset(layout.bodyOffset)
        onBodySizeChanged?(layout.size)
        onBodyOffsetChanged?(bodyOffset)
    }

    private func automaticBodyScreenRect(preferredBodySize: NSSize) -> NSRect? {
        let anchor = lastAnchor ?? NSPoint(x: theme.metrics.tailAnchor.x, y: theme.metrics.tailAnchor.y)
        let companionFrame = lastCompanionFrame ?? NSRect(
            x: anchor.x - 1,
            y: anchor.y - 1,
            width: 2,
            height: 2
        )
        let visibleFrame = visibleFrame(containing: anchor)
        let transcriptHeight = measuredTranscriptHeight(
            width: ConversationBubbleLayout.contentWidth(
                metrics: theme.metrics,
                visibleFrame: visibleFrame,
                preferredBodySize: preferredBodySize
            )
        )
        let layout = ConversationBubbleLayout.layout(
            metrics: theme.metrics,
            transcriptHeight: transcriptHeight,
            anchoredAt: anchor,
            companionFrame: companionFrame,
            visibleFrame: visibleFrame,
            placement: bubblePlacement,
            preferredBodySize: preferredBodySize
        )

        return bodyScreenRect(from: layout)
    }

    private func bodyScreenRect(from layout: ConversationBubbleLayoutResult) -> NSRect {
        NSRect(
            x: layout.frame.minX + layout.bodyRect.minX,
            y: layout.frame.maxY - layout.bodyRect.maxY,
            width: layout.bodyRect.width,
            height: layout.bodyRect.height
        )
    }

    private func normalizedOffset(_ offset: NSPoint) -> NSPoint? {
        guard offset.x.isFinite,
              offset.y.isFinite,
              abs(offset.x) >= 0.5 || abs(offset.y) >= 0.5 else {
            return nil
        }

        return offset
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

private final class ConversationResizeGripView: NSView {
    var onResizeBegan: ((NSPoint) -> Void)?
    var onResizeChanged: ((NSPoint) -> Void)?
    var onResizeEnded: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        toolTip = "Resize conversation"
        setAccessibilityLabel("Resize conversation bubble")
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.set()
        onResizeBegan?(screenPoint(for: event))
    }

    override func mouseDragged(with event: NSEvent) {
        NSCursor.closedHand.set()
        onResizeChanged?(screenPoint(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        onResizeEnded?()
        NSCursor.openHand.set()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let guideRect = NSRect(x: bounds.maxX - 31, y: bounds.minY + 7, width: 24, height: 24)
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: guideRect.insetBy(dx: -2, dy: -2), xRadius: 6, yRadius: 6).fill()

        NSColor.white.withAlphaComponent(0.68).setStroke()
        for offset in [10.0, 16.0, 22.0] {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bounds.maxX - CGFloat(offset), y: bounds.minY + 8))
            path.line(to: NSPoint(x: bounds.maxX - 8, y: bounds.minY + CGFloat(offset)))
            path.lineWidth = 1.6
            path.stroke()
        }
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        window?.convertPoint(toScreen: event.locationInWindow) ?? .zero
    }
}

private final class ConversationBubbleBodyView: NSView {
    var onMoveBegan: ((NSPoint) -> Void)?
    var onMoveChanged: ((NSPoint) -> Void)?
    var onMoveEnded: (() -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = 0
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLayerChrome()
    }

    override func mouseDown(with event: NSEvent) {
        onMoveBegan?(screenPoint(for: event))
    }

    override func mouseDragged(with event: NSEvent) {
        onMoveChanged?(screenPoint(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        onMoveEnded?()
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        window?.convertPoint(toScreen: event.locationInWindow) ?? .zero
    }

    private func updateLayerChrome() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderColor = NSColor.clear.cgColor
        layer?.borderWidth = 0
        layer?.masksToBounds = true
    }
}

private final class ConversationDragHandleView: NSView {
    var onMoveBegan: ((NSPoint) -> Void)?
    var onMoveChanged: ((NSPoint) -> Void)?
    var onMoveEnded: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        toolTip = "Move conversation"
        setAccessibilityLabel("Move conversation bubble")
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.set()
        onMoveBegan?(screenPoint(for: event))
    }

    override func mouseDragged(with event: NSEvent) {
        NSCursor.closedHand.set()
        onMoveChanged?(screenPoint(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        onMoveEnded?()
        NSCursor.openHand.set()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let hitHint = NSBezierPath(
            roundedRect: NSRect(x: 9, y: 4, width: bounds.width - 18, height: 16),
            xRadius: 8,
            yRadius: 8
        )
        NSColor.black.withAlphaComponent(0.14).setFill()
        hitHint.fill()

        NSColor.white.withAlphaComponent(0.62).setFill()
        let handle = NSBezierPath(
            roundedRect: NSRect(x: 22, y: 9, width: bounds.width - 44, height: 5),
            xRadius: 2.5,
            yRadius: 2.5
        )
        handle.fill()
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        window?.convertPoint(toScreen: event.locationInWindow) ?? .zero
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

final class ConversationTranscriptView: NSView {
    var items: [ConversationTranscriptItem] = [.emptyPrompt("Ask me anything.")] {
        didSet {
            rebuildRows()
        }
    }
    private(set) var textStyle = ConversationTranscriptStyle.defaultStyle
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

    func updateTextStyle(_ style: ConversationTranscriptStyle) {
        textStyle = style
        rebuildRows()
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

        rowViews = items.map {
            TranscriptRowView(item: $0, style: textStyle.itemStyle(for: $0))
        }
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
            let style = textStyle.itemStyle(for: item)
            let maxTextWidth = max(width - style.contentInsets.left - style.contentInsets.right, 1)
            let attributedText = attributedString(for: item, style: style)
            let textBounds = attributedText.boundingRect(
                with: NSSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            let textSize = NSSize(width: ceil(textBounds.width), height: ceil(textBounds.height))
            let chipWidth = min(width, textSize.width + style.contentInsets.left + style.contentInsets.right)
            let chipHeight = textSize.height + style.contentInsets.top + style.contentInsets.bottom
            let rowRect = NSRect(x: 0, y: y, width: width, height: chipHeight)
            let backgroundRect = NSRect(x: 0, y: 0, width: chipWidth, height: chipHeight)
            let textRect = NSRect(
                x: style.contentInsets.left,
                y: style.contentInsets.top,
                width: max(chipWidth - style.contentInsets.left - style.contentInsets.right, 1),
                height: textSize.height
            )
            rows.append(
                RowLayout(
                    item: item,
                    frame: rowRect,
                    backgroundRect: backgroundRect,
                    textRect: textRect,
                    style: style
                )
            )
            y += chipHeight + style.rowSpacing
        }

        return rows
    }

    private func attributedString(
        for item: ConversationTranscriptItem,
        style: ConversationTranscriptItemStyle
    ) -> NSAttributedString {
        item.attributedString(style: style)
    }
}

private final class TranscriptRowView: NSView {
    private let item: ConversationTranscriptItem
    private let style: ConversationTranscriptItemStyle
    private let backgroundView = NSView()
    private let textView = NSTextView()

    init(item: ConversationTranscriptItem, style: ConversationTranscriptItemStyle) {
        self.item = item
        self.style = style
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
        frame = row.frame
        backgroundView.frame = row.backgroundRect
        backgroundView.layer?.backgroundColor = row.style.backgroundColor.cgColor
        backgroundView.layer?.cornerRadius = row.style.cornerRadius
        textView.frame = row.textRect

        textView.textContainer?.containerSize = NSSize(
            width: max(textView.frame.width, 1),
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderColor = NSColor.clear.cgColor
        layer?.borderWidth = 0
        layer?.cornerRadius = 0

        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = style.backgroundColor.cgColor
        backgroundView.layer?.cornerRadius = style.cornerRadius
        backgroundView.layer?.masksToBounds = true

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.textStorage?.setAttributedString(item.attributedString(style: style))
        textView.setAccessibilityLabel(item.text)

        addSubview(backgroundView)
        addSubview(textView)
    }
}

private struct RowLayout {
    let item: ConversationTranscriptItem
    let frame: NSRect
    let backgroundRect: NSRect
    let textRect: NSRect
    let style: ConversationTranscriptItemStyle
}

struct ConversationTranscriptStyle {
    var user: ConversationTranscriptItemStyle
    var assistant: ConversationTranscriptItemStyle
    var status: ConversationTranscriptItemStyle
    var emptyPrompt: ConversationTranscriptItemStyle

    @MainActor static let defaultStyle = ConversationTranscriptStyle(
        user: ConversationTranscriptItemStyle(
            font: NSFont.systemFont(ofSize: 14, weight: .medium),
            textColor: NSColor.white.withAlphaComponent(0.9),
            backgroundColor: NSColor(calibratedRed: 0.99, green: 0.73, blue: 0.01, alpha: 0.22),
            rowSpacing: 8
        ),
        assistant: ConversationTranscriptItemStyle(
            font: NSFont.systemFont(ofSize: 16),
            textColor: NSColor.white.withAlphaComponent(0.96),
            backgroundColor: NSColor.black.withAlphaComponent(0.24),
            rowSpacing: 12
        ),
        status: ConversationTranscriptItemStyle(
            font: NSFont.systemFont(ofSize: 13),
            textColor: NSColor.white.withAlphaComponent(0.72),
            backgroundColor: NSColor.black.withAlphaComponent(0.14),
            rowSpacing: 12
        ),
        emptyPrompt: ConversationTranscriptItemStyle(
            font: NSFont.systemFont(ofSize: 16, weight: .medium),
            textColor: NSColor.white.withAlphaComponent(0.96),
            backgroundColor: NSColor.black.withAlphaComponent(0.18),
            rowSpacing: 12
        )
    )

    func itemStyle(for item: ConversationTranscriptItem) -> ConversationTranscriptItemStyle {
        switch item {
        case .user:
            user
        case .assistant:
            assistant
        case .status:
            status
        case .emptyPrompt:
            emptyPrompt
        }
    }
}

struct ConversationTranscriptItemStyle {
    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor
    var cornerRadius: CGFloat
    var contentInsets: NSEdgeInsets
    var rowSpacing: CGFloat

    init(
        font: NSFont,
        textColor: NSColor,
        backgroundColor: NSColor,
        cornerRadius: CGFloat = 8,
        contentInsets: NSEdgeInsets = NSEdgeInsets(top: 5, left: 8, bottom: 5, right: 8),
        rowSpacing: CGFloat
    ) {
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.contentInsets = contentInsets
        self.rowSpacing = rowSpacing
    }
}

extension ConversationTranscriptItem {
    var text: String {
        switch self {
        case .emptyPrompt(let text), .user(let text), .assistant(let text), .status(let text):
            text
        }
    }

    func attributedString(style: ConversationTranscriptItemStyle) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.72)
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = NSSize(width: 0, height: -1)

        return NSAttributedString(
            string: text,
            attributes: [
                .font: style.font,
                .foregroundColor: style.textColor,
                .paragraphStyle: paragraphStyle,
                .shadow: shadow
            ]
        )
    }
}
