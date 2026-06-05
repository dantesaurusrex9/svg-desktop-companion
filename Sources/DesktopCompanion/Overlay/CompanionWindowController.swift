import AppKit

final class CompanionWindowController: NSWindowController {
    private let content = CompanionContentView(frame: NSRect(origin: .zero, size: CompanionWindowMetrics.size))

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
        content.onReloadSVG = { [weak content] in
            content?.reloadSVG()
        }
        content.onPositionChanged = { origin in
            PositionStore.save(origin)
        }
        content.onLayerModeChanged = { [weak self] layerMode in
            self?.setLayerMode(layerMode)
        }

        window.contentView = content
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
