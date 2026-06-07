import AppKit

final class CompanionContentView: NSView {
    private let svgView: SVGCompanionView
    private let closeButton = NSButton()
    private let keyboardAccessButton = NSButton()
    private var trackingAreaRef: NSTrackingArea?
    private var dragStartScreenPoint: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    var onClose: (() -> Void)?
    var onPositionChanging: ((NSPoint) -> Void)?
    var onPositionChanged: ((NSPoint) -> Void)?
    var onReloadSVG: (() -> Void)?
    var onConversate: (() -> Void)?
    var onReloadConversationTheme: (() -> Void)?
    var onConversationThemeSelected: ((String) -> Void)?
    var onLayerModeChanged: ((CompanionLayerMode) -> Void)?
    var layerMode: CompanionLayerMode = .desktop
    var conversationThemes: [ConversationThemeSummary] = []
    var selectedConversationThemeID: String?

    init(
        frame frameRect: NSRect,
        package: CompanionPackage? = CompanionPackageLoader.selectedPackage(),
        animationPreset: CompanionAnimationPreset? = nil
    ) {
        self.svgView = SVGCompanionView(package: package, animationPreset: animationPreset)
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func updateTrackingAreas() {
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
        super.updateTrackingAreas()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseEntered(with event: NSEvent) {
        closeButton.alphaValue = 1
        NSCursor.openHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        closeButton.alphaValue = 0
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        dragStartScreenPoint = window.convertPoint(toScreen: event.locationInWindow)
        dragStartWindowOrigin = window.frame.origin
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let dragStartScreenPoint,
              let dragStartWindowOrigin else {
            return
        }

        let currentScreenPoint = window.convertPoint(toScreen: event.locationInWindow)
        let nextOrigin = Self.draggedWindowOrigin(
            dragStartScreenPoint: dragStartScreenPoint,
            currentScreenPoint: currentScreenPoint,
            dragStartWindowOrigin: dragStartWindowOrigin
        )

        window.setFrameOrigin(nextOrigin)
        onPositionChanging?(nextOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartScreenPoint = nil
        dragStartWindowOrigin = nil

        if let origin = window?.frame.origin {
            onPositionChanged?(origin)
        }

        NSCursor.openHand.set()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let previewItem = NSMenuItem(title: "Preview Animation", action: nil, keyEquivalent: "")
        let previewMenu = NSMenu()
        let supportedStates = svgView.supportedAnimationStates
        for state in CompanionAnimationState.allCases {
            let stateItem = NSMenuItem(title: state.title, action: #selector(previewAnimationRequested(_:)), keyEquivalent: "")
            stateItem.target = self
            stateItem.representedObject = state.rawValue
            stateItem.isEnabled = supportedStates.contains(state)
            previewMenu.addItem(stateItem)
        }
        previewItem.submenu = previewMenu
        menu.addItem(previewItem)

        let reloadItem = NSMenuItem(title: "Reload SVG", action: #selector(reloadRequested), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        let conversateItem = NSMenuItem(title: "Conversate", action: #selector(conversateRequested), keyEquivalent: "")
        conversateItem.target = self
        menu.addItem(conversateItem)

        let reloadBubbleThemeItem = NSMenuItem(title: "Reload Overlay Theme", action: #selector(reloadConversationThemeRequested), keyEquivalent: "")
        reloadBubbleThemeItem.target = self
        menu.addItem(reloadBubbleThemeItem)

        let bubbleThemeItem = NSMenuItem(title: "Overlay Theme", action: nil, keyEquivalent: "")
        let bubbleThemeMenu = NSMenu()
        for theme in conversationThemes {
            let themeItem = NSMenuItem(title: theme.displayName, action: #selector(conversationThemeRequested(_:)), keyEquivalent: "")
            themeItem.target = self
            themeItem.representedObject = theme.id
            themeItem.state = theme.id == selectedConversationThemeID ? .on : .off
            bubbleThemeMenu.addItem(themeItem)
        }
        bubbleThemeItem.submenu = bubbleThemeMenu
        menu.addItem(bubbleThemeItem)

        let layerItem = NSMenuItem(title: "Layer", action: nil, keyEquivalent: "")
        let layerMenu = NSMenu()
        for mode in CompanionLayerMode.allCases {
            let modeItem = NSMenuItem(title: mode.title, action: #selector(layerModeRequested(_:)), keyEquivalent: "")
            modeItem.target = self
            modeItem.representedObject = mode.rawValue
            modeItem.state = mode == layerMode ? .on : .off
            layerMenu.addItem(modeItem)
        }
        layerItem.submenu = layerMenu
        menu.addItem(layerItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Remove Companion", action: #selector(closeRequested), keyEquivalent: "w")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    func playTypingReaction() {
        svgView.playAnimation(.typing)
    }

    func setLoopingAnimation(_ state: CompanionAnimationState?) {
        svgView.setLoopingAnimation(state)
    }

    func reloadSVG() {
        svgView.reloadSVG()
    }

    func reloadSVG(package: CompanionPackage?, animationPreset: CompanionAnimationPreset? = nil) {
        svgView.reloadSVG(package: package, animationPreset: animationPreset)
    }

    var mouthAnchor: NSPoint {
        svgView.mouthAnchor
    }

    func setKeyboardAccessEnabled(_ isEnabled: Bool) {
        keyboardAccessButton.isHidden = isEnabled
    }

    static func draggedWindowOrigin(
        dragStartScreenPoint: NSPoint,
        currentScreenPoint: NSPoint,
        dragStartWindowOrigin: NSPoint
    ) -> NSPoint {
        NSPoint(
            x: dragStartWindowOrigin.x + currentScreenPoint.x - dragStartScreenPoint.x,
            y: dragStartWindowOrigin.y + currentScreenPoint.y - dragStartScreenPoint.y
        )
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        svgView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        keyboardAccessButton.translatesAutoresizingMaskIntoConstraints = false

        closeButton.isBordered = false
        closeButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "Quit"
        )
        closeButton.imageScaling = .scaleProportionallyUpOrDown
        closeButton.contentTintColor = NSColor.white.withAlphaComponent(0.95)
        closeButton.toolTip = "Remove Companion"
        closeButton.target = self
        closeButton.action = #selector(closeRequested)
        closeButton.alphaValue = 0

        keyboardAccessButton.isBordered = false
        keyboardAccessButton.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: "Keyboard access required"
        )
        keyboardAccessButton.imageScaling = .scaleProportionallyUpOrDown
        keyboardAccessButton.contentTintColor = NSColor.systemYellow
        keyboardAccessButton.toolTip = "Grant Accessibility permission to enable typing animation"
        keyboardAccessButton.target = self
        keyboardAccessButton.action = #selector(openAccessibilitySettings)
        keyboardAccessButton.isHidden = true

        addSubview(svgView)
        addSubview(keyboardAccessButton)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            svgView.leadingAnchor.constraint(equalTo: leadingAnchor),
            svgView.trailingAnchor.constraint(equalTo: trailingAnchor),
            svgView.topAnchor.constraint(equalTo: topAnchor),
            svgView.bottomAnchor.constraint(equalTo: bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            keyboardAccessButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            keyboardAccessButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            keyboardAccessButton.widthAnchor.constraint(equalToConstant: 24),
            keyboardAccessButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @objc private func closeRequested() {
        onClose?()
    }

    @objc private func reloadRequested() {
        onReloadSVG?()
    }

    @objc private func conversateRequested() {
        onConversate?()
    }

    @objc private func reloadConversationThemeRequested() {
        onReloadConversationTheme?()
    }

    @objc private func conversationThemeRequested(_ sender: NSMenuItem) {
        guard let themeID = sender.representedObject as? String else {
            return
        }

        onConversationThemeSelected?(themeID)
    }

    @objc private func previewAnimationRequested(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let state = CompanionAnimationState(rawValue: rawValue) else {
            return
        }

        svgView.playAnimation(state)
    }

    @objc private func layerModeRequested(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let requestedLayerMode = CompanionLayerMode(rawValue: rawValue) else {
            return
        }

        layerMode = requestedLayerMode
        onLayerModeChanged?(requestedLayerMode)
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
