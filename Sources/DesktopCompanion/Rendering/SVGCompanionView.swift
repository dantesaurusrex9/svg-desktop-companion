import AppKit

final class SVGCompanionView: NSView {
    private let stageView = NSView()
    private let imageView = NSImageView()
    private let idleAnimationKey = "desktopCompanionIdle"
    private let stateAnimationKey = "desktopCompanionStateAnimation"
    private var animationClips: [CompanionAnimationState: CompanionAnimationClip] = [:]
    private var assetMarkup = ""
    private var activePreset: CompanionAnimationPreset = .wholeObjectReaction
    private var restingImage: NSImage?
    private var pendingFrameChanges: [DispatchWorkItem] = []
    private var queuedTypingCount = 0
    private var isPlayingFiniteAnimation = false
    private var loopingState: CompanionAnimationState?
    private let maxQueuedTypingCount = 1
    private(set) var mouthAnchor = CompanionAsset.defaultMouthAnchor
    private var package: CompanionPackage?
    private var animationPreset: CompanionAnimationPreset?
    private let animateIdle: Bool

    init(
        frame frameRect: NSRect = .zero,
        package: CompanionPackage? = CompanionPackageLoader.selectedPackage(),
        animationPreset: CompanionAnimationPreset? = nil,
        animateIdle: Bool = true
    ) {
        self.package = package
        self.animationPreset = animationPreset
        self.animateIdle = animateIdle
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
        playAnimation(.typing)
    }

    var supportedAnimationStates: [CompanionAnimationState] {
        CompanionAnimationClip.states(for: activePreset)
    }

    func playAnimation(_ state: CompanionAnimationState) {
        guard loopingState == nil,
              supportedAnimationStates.contains(state) else {
            return
        }

        if state == .typing {
            queuedTypingCount = min(queuedTypingCount + 1, maxQueuedTypingCount)
            if !isPlayingFiniteAnimation {
                playNextQueuedTypingAnimation()
            }
        } else {
            playOneShotAnimation(state)
        }
    }

    func setLoopingAnimation(_ state: CompanionAnimationState?) {
        guard loopingState != state else {
            return
        }

        cancelPendingFrameChanges()
        imageView.layer?.removeAnimation(forKey: stateAnimationKey)
        queuedTypingCount = 0
        isPlayingFiniteAnimation = false
        loopingState = state

        guard let state,
              let clip = clip(for: state),
              !clip.isEmpty else {
            imageView.image = restingImage
            return
        }

        applyFrameChanges(clip.frames)
        addLayerAnimation(clip.layerAnimation, repeatCount: .infinity)
    }

    func reloadSVG() {
        let asset = CompanionAsset.load(package: package)
        mouthAnchor = asset.mouthAnchor
        cancelPendingFrameChanges()
        imageView.layer?.removeAnimation(forKey: stateAnimationKey)
        queuedTypingCount = 0
        isPlayingFiniteAnimation = false
        loopingState = nil
        let preset = animationPreset ?? asset.animationPreset
        activePreset = preset
        assetMarkup = asset.markup
        animationClips.removeAll()
        let restingMarkup = CompanionAnimationClip.restingMarkup(from: asset.markup, preset: preset)
        restingImage = image(from: restingMarkup)
        imageView.image = restingImage
    }

    func reloadSVG(package: CompanionPackage?, animationPreset: CompanionAnimationPreset? = nil) {
        self.package = package
        self.animationPreset = animationPreset
        reloadSVG()
    }

    private func playNextQueuedTypingAnimation() {
        guard loopingState == nil,
              let clip = clip(for: .typing) else {
            queuedTypingCount = 0
            isPlayingFiniteAnimation = false
            return
        }

        guard queuedTypingCount > 0 else {
            imageView.image = restingImage
            isPlayingFiniteAnimation = false
            return
        }

        isPlayingFiniteAnimation = true
        queuedTypingCount -= 1
        playClip(clip) { [weak self] in
            self?.playNextQueuedTypingAnimation()
        }
    }

    private func playOneShotAnimation(_ state: CompanionAnimationState) {
        guard let clip = clip(for: state),
              !clip.isEmpty else {
            return
        }

        isPlayingFiniteAnimation = true
        playClip(clip) { [weak self] in
            guard let self else {
                return
            }

            self.imageView.image = self.restingImage
            self.isPlayingFiniteAnimation = false
        }
    }

    private func playClip(_ clip: CompanionAnimationClip, completion: @escaping () -> Void) {
        cancelPendingFrameChanges()
        imageView.layer?.removeAnimation(forKey: stateAnimationKey)
        applyFrameChanges(clip.frames)
        addLayerAnimation(clip.layerAnimation, repeatCount: 0)
        scheduleAnimationStep(after: clip.duration, completion)
    }

    private func clip(for state: CompanionAnimationState) -> CompanionAnimationClip? {
        if let clip = animationClips[state] {
            return clip
        }

        guard let clip = CompanionAnimationClip.clip(
            markup: assetMarkup,
            preset: activePreset,
            state: state,
            renderer: image(from:)
        ) else {
            return nil
        }

        animationClips[state] = clip
        return clip
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

        if animateIdle {
            startIdleAnimation()
        }
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

    private func applyFrameChanges(_ frames: [CompanionAnimationFrame]) {
        for frame in frames {
            if frame.delay <= 0 {
                imageView.image = frame.image
            } else {
                setAnimationFrame(frame.image, after: frame.delay)
            }
        }
    }

    private func addLayerAnimation(_ animation: CAKeyframeAnimation?, repeatCount: Float) {
        guard let layer = imageView.layer,
              let animation = animation?.copy() as? CAKeyframeAnimation else {
            return
        }

        animation.repeatCount = repeatCount
        layer.add(animation, forKey: stateAnimationKey)
    }

    private func setAnimationFrame(_ image: NSImage, after delay: TimeInterval) {
        scheduleAnimationStep(after: delay) { [weak self] in
            self?.imageView.image = image
        }
    }

    private func scheduleAnimationStep(after delay: TimeInterval, _ action: @escaping () -> Void) {
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
}
