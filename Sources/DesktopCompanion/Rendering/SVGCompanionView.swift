import AppKit

final class SVGCompanionView: NSView {
    private let stageView = NSView()
    private let imageView = NSImageView()
    private let idleAnimationKey = "desktopCompanionIdle"
    private let reactionAnimationKey = "desktopCompanionTypingReaction"
    private var reactionFrames: CompanionReactionFrames?
    private var pendingFrameChanges: [DispatchWorkItem] = []
    private var queuedHitCount = 0
    private var isPlayingReaction = false
    private let maxQueuedHitCount = 1
    private(set) var mouthAnchor = CompanionAsset.defaultMouthAnchor

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupImageView()
        reloadSVG()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func playTypingReaction() {
        guard reactionFrames != nil else {
            return
        }

        queuedHitCount = min(queuedHitCount + 1, maxQueuedHitCount)
        if !isPlayingReaction {
            playNextQueuedHit()
        }
    }

    func reloadSVG() {
        let asset = CompanionAsset.load()
        mouthAnchor = asset.mouthAnchor
        cancelPendingFrameChanges()
        queuedHitCount = 0
        isPlayingReaction = false
        let frames = CompanionReactionFrames(markup: asset.markup, renderer: image(from:))
        reactionFrames = frames
        imageView.image = frames.resting
    }

    private func playNextQueuedHit() {
        guard let reactionFrames else {
            queuedHitCount = 0
            isPlayingReaction = false
            return
        }

        guard queuedHitCount > 0 else {
            imageView.image = reactionFrames.resting
            isPlayingReaction = false
            return
        }

        isPlayingReaction = true
        queuedHitCount -= 1
        cancelPendingFrameChanges()

        imageView.image = reactionFrames.windUp
        setReactionFrame(reactionFrames.strike, after: 0.07)
        setReactionFrame(reactionFrames.flare, after: 0.16)
        scheduleReactionStep(after: 0.30) { [weak self] in
            guard let self else {
                return
            }

            self.playNextQueuedHit()
        }

        guard let layer = imageView.layer else {
            return
        }

        layer.removeAnimation(forKey: reactionAnimationKey)

        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = [
            reactionTransform(y: 0, rotation: 0, scaleY: 1),
            reactionTransform(y: -10, rotation: 3, scaleY: 1),
            reactionTransform(y: 19, rotation: -5, scaleY: 0.94),
            reactionTransform(y: 0, rotation: 0, scaleY: 1)
        ]
        animation.keyTimes = [0, 0.2, 0.48, 1]
        animation.duration = 0.30
        animation.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.18, 0.9, 0.28, 1),
            CAMediaTimingFunction(controlPoints: 0.22, 0.84, 0.26, 1),
            CAMediaTimingFunction(name: .easeOut)
        ]
        layer.add(animation, forKey: reactionAnimationKey)
    }

    private func setupImageView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        stageView.translatesAutoresizingMaskIntoConstraints = false
        stageView.wantsLayer = true
        stageView.layer?.backgroundColor = NSColor.clear.cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        imageView.imageAlignment = .alignCenter
        imageView.imageFrameStyle = .none
        imageView.imageScaling = .scaleProportionallyUpOrDown

        addSubview(stageView)
        stageView.addSubview(imageView)

        NSLayoutConstraint.activate([
            stageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stageView.topAnchor.constraint(equalTo: topAnchor),
            stageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.leadingAnchor.constraint(equalTo: stageView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: stageView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: stageView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: stageView.bottomAnchor)
        ])

        startIdleAnimation()
    }

    private func startIdleAnimation() {
        guard let layer = stageView.layer else {
            return
        }

        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = [
            idleTransform(y: 4, rotation: -0.8),
            idleTransform(y: -5, rotation: 0.8),
            idleTransform(y: 4, rotation: -0.8)
        ]
        animation.keyTimes = [0, 0.5, 1]
        animation.duration = 3.6
        animation.repeatCount = .infinity
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        layer.add(animation, forKey: idleAnimationKey)
    }

    private func image(from markup: String) -> NSImage {
        guard let data = markup.data(using: .utf8),
              let image = NSImage(data: data) else {
            return NSImage(size: NSSize(width: CompanionAsset.canvasSize, height: CompanionAsset.canvasSize))
        }

        image.isTemplate = false
        return image
    }

    private func cancelPendingFrameChanges() {
        pendingFrameChanges.forEach { $0.cancel() }
        pendingFrameChanges.removeAll()
    }

    private func setReactionFrame(_ image: NSImage, after delay: TimeInterval) {
        scheduleReactionStep(after: delay) { [weak self] in
            self?.imageView.image = image
        }
    }

    private func scheduleReactionStep(after delay: TimeInterval, _ action: @escaping () -> Void) {
        let workItem = DispatchWorkItem(block: action)
        pendingFrameChanges.append(workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func idleTransform(y: CGFloat, rotation degrees: CGFloat) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, 0, y, 0)
        transform = CATransform3DRotate(transform, degrees * .pi / 180, 0, 0, 1)
        return transform
    }

    private func reactionTransform(y: CGFloat, rotation degrees: CGFloat, scaleY: CGFloat) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, 0, y, 0)
        transform = CATransform3DRotate(transform, degrees * .pi / 180, 0, 0, 1)
        transform = CATransform3DScale(transform, 1, scaleY, 1)
        return transform
    }
}
