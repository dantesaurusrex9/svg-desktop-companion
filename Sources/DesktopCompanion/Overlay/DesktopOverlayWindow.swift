import AppKit

final class DesktopOverlayWindow: NSPanel {
    private(set) var layerMode: CompanionLayerMode

    init(contentRect: NSRect, layerMode: CompanionLayerMode) {
        self.layerMode = layerMode

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        canHide = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        level = layerMode.windowLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    func applyLayerMode(_ layerMode: CompanionLayerMode) {
        self.layerMode = layerMode
        level = layerMode.windowLevel
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
