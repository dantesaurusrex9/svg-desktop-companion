import AppKit

final class CompanionWindowController: NSWindowController {
    private var content: CompanionContentView
    private var package: CompanionPackage
    private let conversationController: ConversationBubbleWindowController
    private let onInstanceChanged: (CompanionInstance) -> Void
    private let onInstanceClosed: (String) -> Void
    private(set) var instance: CompanionInstance

    init(
        instance: CompanionInstance,
        package: CompanionPackage,
        onInstanceChanged: @escaping (CompanionInstance) -> Void,
        onInstanceClosed: @escaping (String) -> Void
    ) {
        self.instance = instance
        self.package = package
        self.content = CompanionContentView(
            frame: NSRect(origin: .zero, size: CompanionWindowMetrics.size),
            package: package,
            animationPreset: instance.animationPreset
        )
        self.conversationController = ConversationBubbleWindowController(
            package: package,
            bubblePlacement: instance.bubblePlacement,
            preferredBodySize: instance.conversationBubbleSize?.size,
            bodyOffset: instance.conversationBubbleOffset?.point
        )
        self.onInstanceChanged = onInstanceChanged
        self.onInstanceClosed = onInstanceClosed

        let initialFrame = NSRect(origin: instance.originPoint, size: CompanionWindowMetrics.size)
        let window = DesktopOverlayWindow(contentRect: initialFrame, layerMode: instance.layerMode)

        super.init(window: window)

        content.layerMode = instance.layerMode
        content.onClose = { [weak self] in
            guard let self else {
                return
            }

            self.onInstanceClosed(self.instance.id)
        }
        content.onReloadSVG = { [weak self] in
            self?.reloadPackage()
        }
        content.onConversate = { [weak self] in
            self?.showConversation()
        }
        content.onReloadConversationTheme = { [weak self] in
            self?.reloadConversationTheme()
        }
        content.onConversationThemeSelected = { [weak self] themeID in
            self?.selectConversationTheme(id: themeID)
        }
        content.onPositionChanging = { [weak self] origin in
            self?.moveConversation(companionOrigin: origin)
        }
        content.onPositionChanged = { [weak self] origin in
            self?.setOrigin(origin)
        }
        content.onLayerModeChanged = { [weak self] layerMode in
            self?.setLayerMode(layerMode)
        }
        conversationController.onBodySizeChanged = { [weak self] size in
            self?.setConversationBubbleSize(size)
        }
        conversationController.onBodyOffsetChanged = { [weak self] offset in
            self?.setConversationBubbleOffset(offset)
        }
        conversationController.onRunningStateChanged = { [weak self] isRunning in
            self?.content.setLoopingAnimation(Self.animationState(forConversationRunning: isRunning))
        }

        window.contentView = content
        refreshConversationThemeMenu()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func playTypingReaction() {
        content.playTypingReaction()
    }

    func setKeyboardAccessEnabled(_ isEnabled: Bool) {
        content.setKeyboardAccessEnabled(isEnabled)
    }

    static func animationState(forConversationRunning isRunning: Bool) -> CompanionAnimationState? {
        isRunning ? .thinking : nil
    }

    func closeCompanionWindow() {
        content.setLoopingAnimation(nil)
        conversationController.closeBubble()
        window?.orderOut(nil)
    }

    private func showConversation() {
        guard let window,
              let screenPoint = conversationScreenPoint() else {
            return
        }

        let level = (window as? DesktopOverlayWindow)?.layerMode.windowLevel ?? .floating
        conversationController.show(anchoredAt: screenPoint, companionFrame: window.frame, level: level)
    }

    private func reloadPackage() {
        if let package = CompanionPackageLoader.package(id: instance.packageID) {
            self.package = package
            content.reloadSVG(package: package, animationPreset: instance.animationPreset)
        } else {
            content.reloadSVG(package: package, animationPreset: instance.animationPreset)
        }

        guard let origin = window?.frame.origin else {
            return
        }

        moveConversation(companionOrigin: origin)
    }

    private func reloadConversationTheme() {
        conversationController.reloadTheme()
        refreshConversationThemeMenu()
    }

    private func selectConversationTheme(id themeID: String) {
        conversationController.selectTheme(id: themeID)
        refreshConversationThemeMenu()
    }

    private func moveConversation(companionOrigin: NSPoint) {
        guard let window,
              let screenPoint = conversationScreenPoint(companionOrigin: companionOrigin) else {
            return
        }

        let companionFrame = NSRect(origin: companionOrigin, size: window.frame.size)
        conversationController.move(anchoredAt: screenPoint, companionFrame: companionFrame)
    }

    private func conversationScreenPoint(companionOrigin: NSPoint? = nil) -> NSPoint? {
        guard let window else {
            return nil
        }

        let windowPoint = content.convert(instance.speechAnchorPoint, to: nil)
        let origin = companionOrigin ?? window.frame.origin
        return NSPoint(x: origin.x + windowPoint.x, y: origin.y + windowPoint.y)
    }

    private func refreshConversationThemeMenu() {
        content.conversationThemes = conversationController.availableThemes
        content.selectedConversationThemeID = conversationController.selectedThemeID
    }

    private func setOrigin(_ origin: NSPoint) {
        instance.originPoint = origin
        onInstanceChanged(instance)
    }

    private func setLayerMode(_ layerMode: CompanionLayerMode) {
        content.layerMode = layerMode
        instance.layerMode = layerMode
        onInstanceChanged(instance)

        guard let window = window as? DesktopOverlayWindow else {
            return
        }

        window.applyLayerMode(layerMode)
        window.orderFrontRegardless()
        conversationController.setCompanionLevel(window.level)
    }

    private func setConversationBubbleSize(_ size: NSSize) {
        instance.conversationBubbleSize = ConversationBubbleSize(size: size)
        onInstanceChanged(instance)
    }

    private func setConversationBubbleOffset(_ offset: NSPoint?) {
        instance.conversationBubbleOffset = offset.map { CompanionAnchor(point: $0) }
        onInstanceChanged(instance)
    }
}
