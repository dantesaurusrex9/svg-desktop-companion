import AppKit

final class CompanionWindowController: NSWindowController {
    private let content = CompanionContentView(frame: NSRect(origin: .zero, size: CompanionWindowMetrics.size))
    private let conversationController = ConversationBubbleWindowController()

    init() {
        let savedOrigin = PositionStore.load()
        let savedLayerMode = CompanionLayerModeStore.load()
        let initialFrame = NSRect(origin: savedOrigin ?? CompanionWindowMetrics.defaultOrigin, size: CompanionWindowMetrics.size)
        let window = DesktopOverlayWindow(contentRect: initialFrame, layerMode: savedLayerMode)

        super.init(window: window)

        content.layerMode = savedLayerMode
        content.onClose = {
            NSApp.terminate(nil)
        }
        content.onReloadSVG = { [weak self] in
            self?.reloadSVG()
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
        content.onPositionChanged = { origin in
            PositionStore.save(origin)
        }
        content.onLayerModeChanged = { [weak self] layerMode in
            self?.setLayerMode(layerMode)
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

    private func showConversation() {
        guard let window,
              let screenPoint = conversationScreenPoint() else {
            return
        }

        let level = (window as? DesktopOverlayWindow)?.layerMode.windowLevel ?? .floating
        conversationController.show(anchoredAt: screenPoint, companionFrame: window.frame, level: level)
    }

    private func reloadSVG() {
        content.reloadSVG()
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

        let windowPoint = content.convert(content.mouthAnchor, to: nil)
        let origin = companionOrigin ?? window.frame.origin
        return NSPoint(x: origin.x + windowPoint.x, y: origin.y + windowPoint.y)
    }

    private func refreshConversationThemeMenu() {
        content.conversationThemes = conversationController.availableThemes
        content.selectedConversationThemeID = conversationController.selectedThemeID
    }

    private func setLayerMode(_ layerMode: CompanionLayerMode) {
        content.layerMode = layerMode
        CompanionLayerModeStore.save(layerMode)

        guard let window = window as? DesktopOverlayWindow else {
            return
        }

        window.applyLayerMode(layerMode)
        window.orderFrontRegardless()
    }
}
