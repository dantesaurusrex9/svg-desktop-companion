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
    private let transcriptView = NSTextView()
    private let inputContainerView = NSView()
    private let inputField = NSTextField()
    private let closeButton = NSButton()
    private var theme: ConversationTheme
    private var themeConstraints: [NSLayoutConstraint] = []
    private var lastAnchor: NSPoint?
    private var lastCompanionFrame: NSRect?
    private var history: [CodexConversationTurn] = []
    private var pendingQuestion: String?
    private var isRunning = false
    private let hoverAnimationKey = "desktopCompanionConversationHover"

    init(runner: CodexConversationRunner = CodexConversationRunner()) {
        self.runner = runner
        self.theme = ConversationThemeLoader.selectedTheme()

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
    }

    func reloadTheme() {
        theme = ConversationThemeLoader.selectedTheme()
        applyTheme()
    }

    func selectTheme(id themeID: String) {
        ConversationThemeLoader.saveSelectedThemeID(themeID)
        reloadTheme()
    }

    var selectedThemeID: String {
        theme.id
    }

    var availableThemes: [ConversationThemeSummary] {
        ConversationThemeLoader.availableThemeSummaries()
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

        transcriptView.isEditable = false
        transcriptView.isSelectable = true
        transcriptView.drawsBackground = false
        transcriptView.isHorizontallyResizable = false
        transcriptView.isVerticallyResizable = true
        transcriptView.autoresizingMask = [.width]
        transcriptView.font = NSFont.systemFont(ofSize: 13)
        transcriptView.textColor = .labelColor
        transcriptView.textContainerInset = NSSize(width: 0, height: 0)
        transcriptView.textContainer?.widthTracksTextView = true
        transcriptView.string = "Ask me anything."

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = transcriptView

        inputContainerView.wantsLayer = true
        inputContainerView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.94).cgColor
        inputContainerView.layer?.borderColor = NSColor.black.withAlphaComponent(0.12).cgColor
        inputContainerView.layer?.borderWidth = 1
        inputContainerView.layer?.cornerRadius = 17

        inputField.font = NSFont.systemFont(ofSize: 14)
        inputField.placeholderString = "Ask Codex"
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

            closeButton.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 14),
            closeButton.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -18),
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
        runner.cancel()
        stopHoverAnimation()
        window?.orderOut(nil)
    }

    private func renderTranscript(status: String? = nil) {
        let model = ConversationTranscriptViewModel(
            history: history,
            pendingQuestion: pendingQuestion,
            status: status
        )
        transcriptView.string = model.text
        applyLayout()
        transcriptView.scrollToEndOfDocument(nil)
    }

    private func bubbleLevel(for companionLevel: NSWindow.Level) -> NSWindow.Level {
        if companionLevel.rawValue > NSWindow.Level.floating.rawValue {
            return companionLevel
        }

        return .floating
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
            visibleFrame: visibleFrame
        )

        connectorView.connectorStart = layout.connectorStart
        connectorView.connectorEnd = layout.connectorEnd
        connectorView.needsDisplay = true
        scrollView.hasVerticalScroller = layout.isTranscriptScrollable
        transcriptView.textContainer?.containerSize = NSSize(
            width: layout.transcriptRect.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        transcriptView.frame = NSRect(origin: .zero, size: layout.transcriptRect.size)

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
        let font = transcriptView.font ?? NSFont.systemFont(ofSize: 13)
        let text = transcriptView.string.isEmpty ? "Ask me anything." : transcriptView.string
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: font]
        )
        let bounds = attributed.boundingRect(
            with: NSSize(width: max(width, 1), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        return ceil(bounds.height) + 12
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
