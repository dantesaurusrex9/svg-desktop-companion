import AppKit

final class CompanionLibraryWindowController: NSWindowController {
    var onSpawnPackage: ((CompanionPackage) -> Void)?
    var onImportSVG: (() -> Void)?
    var onImportPackage: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let packageStack = NSStackView()
    private let activeLabel = AppTheme.label("", font: AppTypography.sidebarStatus, color: AppTheme.secondaryText)
    private var packages: [CompanionPackage] = []
    private var instances: [CompanionInstance] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppCopy.libraryTitle
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.minSize = NSSize(width: 720, height: 460)
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = AppTheme.background

        super.init(window: window)

        window.contentView = makeContentView()
        window.center()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reload(packages: [CompanionPackage], instances: [CompanionInstance]) {
        self.packages = packages.filter { $0.id != CompanionPackageLoader.legacyUserPackageID }
        self.instances = instances.filter { $0.packageID != CompanionPackageLoader.legacyUserPackageID }
        activeLabel.stringValue = activeText(count: self.instances.count)
        rebuildPackageRows(instances: self.instances)
    }

    func reloadTheme() {
        packageStack.removeFromSuperview()
        window?.backgroundColor = AppTheme.background
        window?.contentView = makeContentView()
        reload(packages: packages, instances: instances)
    }

    private func makeContentView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = AppTheme.background.cgColor

        let sidebar = makeSidebarView()
        let mainContent = makeMainContentView()

        root.addSubview(sidebar)
        root.addSubview(mainContent)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: AppLayout.sidebarWidth),

            mainContent.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            mainContent.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            mainContent.topAnchor.constraint(equalTo: root.topAnchor),
            mainContent.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        return root
    }

    private func makeSidebarView() -> NSView {
        let sidebar = NSView()
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = AppTheme.backgroundDark.cgColor
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        activeLabel.textColor = AppTheme.secondaryText
        let titleLabel = AppTheme.label(AppCopy.libraryTitle, font: AppTypography.sidebarHeader)
        let companionItem = AppTheme.sidebarButton(
            title: AppCopy.companionsTitle,
            systemSymbolName: "square.grid.2x2",
            target: nil,
            action: nil
        )
        let marketplaceLabel = AppTheme.label(AppCopy.marketplaceTitle, font: AppTypography.sectionLabel, color: AppTheme.secondaryText)
        let uploadButton = AppTheme.sidebarButton(
            title: AppCopy.uploadAction,
            systemSymbolName: "square.and.arrow.up",
            target: self,
            action: #selector(uploadRequested(_:))
        )
        let browseButton = AppTheme.sidebarButton(
            title: AppCopy.browseAction,
            systemSymbolName: "bag",
            target: nil,
            action: nil,
            isEnabled: false
        )
        browseButton.toolTip = AppCopy.marketplaceComingSoonTooltip

        let topStack = NSStackView(views: [titleLabel, activeLabel, companionItem, marketplaceLabel, uploadButton, browseButton])
        topStack.orientation = .vertical
        topStack.alignment = .leading
        topStack.spacing = AppLayout.sidebarStackSpacing
        topStack.setCustomSpacing(AppLayout.sidebarStatusSpacing, after: activeLabel)
        topStack.setCustomSpacing(AppLayout.sidebarSectionSpacing, after: companionItem)
        topStack.translatesAutoresizingMaskIntoConstraints = false

        let accountButton = AppTheme.sidebarButton(
            title: AppCopy.accountAction,
            systemSymbolName: "person.crop.circle",
            target: nil,
            action: nil,
            isEnabled: false,
            fillColor: AppTheme.backgroundDark
        )
        accountButton.toolTip = AppCopy.accountComingSoonTooltip
        let settingsButton = AppTheme.sidebarButton(
            title: AppCopy.settingsAction,
            systemSymbolName: "gearshape",
            target: self,
            action: #selector(settingsRequested),
            fillColor: AppTheme.backgroundDark
        )
        let utilityStack = NSStackView(views: [accountButton, settingsButton])
        utilityStack.orientation = .vertical
        utilityStack.alignment = .leading
        utilityStack.spacing = AppLayout.utilityItemSpacing
        utilityStack.translatesAutoresizingMaskIntoConstraints = false

        sidebar.addSubview(topStack)
        sidebar.addSubview(utilityStack)

        NSLayoutConstraint.activate([
            topStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: AppLayout.sidebarHorizontalInset),
            topStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -AppLayout.sidebarHorizontalInset),
            topStack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: AppLayout.sidebarTopInset),

            utilityStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: AppLayout.sidebarHorizontalInset),
            utilityStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -AppLayout.sidebarHorizontalInset),
            utilityStack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -AppLayout.sidebarBottomInset),

            companionItem.widthAnchor.constraint(equalTo: topStack.widthAnchor),
            uploadButton.widthAnchor.constraint(equalTo: topStack.widthAnchor),
            browseButton.widthAnchor.constraint(equalTo: topStack.widthAnchor),
            accountButton.widthAnchor.constraint(equalTo: utilityStack.widthAnchor),
            settingsButton.widthAnchor.constraint(equalTo: utilityStack.widthAnchor)
        ])

        return sidebar
    }

    private func makeMainContentView() -> NSView {
        let mainContent = NSView()
        mainContent.wantsLayer = true
        mainContent.layer?.backgroundColor = AppTheme.background.cgColor
        mainContent.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = AppTheme.label(AppCopy.companionsTitle, font: AppTypography.pageTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        packageStack.orientation = .vertical
        packageStack.alignment = .leading
        packageStack.spacing = AppLayout.cardStackSpacing
        packageStack.translatesAutoresizingMaskIntoConstraints = false

        let documentView = FlippedDocumentView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(packageStack)
        scrollView.documentView = documentView

        mainContent.addSubview(titleLabel)
        mainContent.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: AppLayout.contentHorizontalInset),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: mainContent.trailingAnchor, constant: -AppLayout.contentHorizontalInset),
            titleLabel.topAnchor.constraint(equalTo: mainContent.topAnchor, constant: AppLayout.contentTopInset),

            scrollView.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: AppLayout.contentHorizontalInset),
            scrollView.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -AppLayout.contentHorizontalInset),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppLayout.titleToListSpacing),
            scrollView.bottomAnchor.constraint(equalTo: mainContent.bottomAnchor, constant: -AppLayout.contentBottomInset),

            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),

            packageStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            packageStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            packageStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            packageStack.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor),
            packageStack.widthAnchor.constraint(equalTo: documentView.widthAnchor)
        ])

        return mainContent
    }

    private func activeText(count: Int) -> String {
        AppCopy.activeCount(count)
    }

    private func rebuildPackageRows(instances: [CompanionInstance]) {
        packageStack.arrangedSubviews.forEach { view in
            packageStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if packages.isEmpty {
            let emptyLabel = AppTheme.label(AppCopy.emptyLibrary, font: AppTypography.sidebarHeader, color: AppTheme.secondaryText)
            packageStack.addArrangedSubview(emptyLabel)
            return
        }

        let activeCounts = Dictionary(grouping: instances, by: \.packageID).mapValues { $0.count }
        for package in packages {
            let card = makePackageCard(for: package, activeCount: activeCounts[package.id, default: 0])
            packageStack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: packageStack.widthAnchor).isActive = true
        }
    }

    private func makePackageCard(for package: CompanionPackage, activeCount: Int) -> CompanionPackageCardView {
        let card = CompanionPackageCardView(package: package, activeCount: activeCount)
        card.onSpawn = { [weak self] package in
            self?.onSpawnPackage?(package)
        }
        return card
    }

    @objc private func uploadRequested(_ sender: NSButton) {
        let menu = NSMenu()
        let importSVGItem = NSMenuItem(title: AppCopy.importSVGAction, action: #selector(importSVGRequested), keyEquivalent: "")
        importSVGItem.target = self
        menu.addItem(importSVGItem)

        let importPackageItem = NSMenuItem(title: AppCopy.importPackageAction, action: #selector(importPackageRequested), keyEquivalent: "")
        importPackageItem.target = self
        menu.addItem(importPackageItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY + 4), in: sender)
    }

    @objc private func importSVGRequested() {
        onImportSVG?()
    }

    @objc private func importPackageRequested() {
        onImportPackage?()
    }

    @objc private func settingsRequested() {
        onOpenSettings?()
    }
}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private final class CompanionPackageCardView: RoundedPanelView {
    var onSpawn: ((CompanionPackage) -> Void)?
    private let package: CompanionPackage
    private let previewView: SVGCompanionView

    init(package: CompanionPackage, activeCount: Int) {
        self.package = package
        self.previewView = SVGCompanionView(package: package, animationPreset: package.animationPreset)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup(activeCount: activeCount)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup(activeCount: Int) {
        fillColor = AppTheme.backgroundDark

        let nameLabel = AppTheme.label(package.displayName, font: AppTypography.cardTitle)
        let detailLabel = AppTheme.label(detailText, font: AppTypography.cardDetail, color: AppTheme.secondaryText)
        let activeBadge = badge(text: activeText(count: activeCount))
        let previewView = self.previewView

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = AppLayout.cardTextSpacing
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(detailLabel)

        let previewStack = NSStackView()
        previewStack.orientation = .horizontal
        previewStack.alignment = .centerY
        previewStack.spacing = 6
        previewStack.translatesAutoresizingMaskIntoConstraints = false

        let supportedStates = previewView.supportedAnimationStates
        for state in CompanionAnimationState.allCases {
            let button = AppTheme.button(state.title, target: self, action: #selector(previewRequested(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(state.rawValue)
            button.isEnabled = supportedStates.contains(state)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 78).isActive = true
            previewStack.addArrangedSubview(button)
        }

        let spawnButton = AppTheme.primaryButton(AppCopy.spawnAction, target: self, action: #selector(spawnRequested))
        spawnButton.translatesAutoresizingMaskIntoConstraints = false
        previewView.translatesAutoresizingMaskIntoConstraints = false

        let actionStack = NSStackView(views: [activeBadge, previewStack, spawnButton])
        actionStack.orientation = .vertical
        actionStack.alignment = .trailing
        actionStack.spacing = AppLayout.actionStackSpacing
        actionStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textStack)
        addSubview(previewView)
        addSubview(actionStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: AppLayout.cardMinimumHeight),

            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AppLayout.cardTextLeadingInset),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: previewView.leadingAnchor, constant: -AppLayout.cardPreviewSpacing),

            previewView.trailingAnchor.constraint(equalTo: actionStack.leadingAnchor, constant: -AppLayout.cardActionSpacing),
            previewView.centerYAnchor.constraint(equalTo: centerYAnchor),
            previewView.widthAnchor.constraint(equalToConstant: AppLayout.cardPreviewSize),
            previewView.heightAnchor.constraint(equalToConstant: AppLayout.cardPreviewSize),

            actionStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AppLayout.cardActionTrailingInset),
            actionStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            spawnButton.widthAnchor.constraint(equalToConstant: AppLayout.actionColumnWidth),
            spawnButton.heightAnchor.constraint(equalToConstant: AppLayout.buttonHeight)
        ])
    }

    private var detailText: String {
        "\(sourceText) - \(package.animationPreset.title)"
    }

    private func activeText(count: Int) -> String {
        AppCopy.activeCount(count)
    }

    private func badge(text: String) -> NSView {
        let badge = RoundedPanelView()
        badge.fillColor = AppTheme.row
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label = AppTheme.label(text, font: AppTypography.badge, color: AppTheme.secondaryText)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        badge.addSubview(label)

        NSLayoutConstraint.activate([
            badge.heightAnchor.constraint(equalToConstant: AppLayout.activeBadgeHeight),
            badge.widthAnchor.constraint(equalToConstant: AppLayout.actionColumnWidth),

            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: AppLayout.activeBadgeHorizontalInset),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -AppLayout.activeBadgeHorizontalInset),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor)
        ])

        return badge
    }

    private var sourceText: String {
        if package.id == CompanionPackageLoader.legacyUserPackageID {
            return "Legacy Override"
        }

        if package.folderURL.path.contains("/Application Support/") {
            return "Installed"
        }

        return "Bundled"
    }

    @objc private func spawnRequested() {
        onSpawn?(package)
    }

    @objc private func previewRequested(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let state = CompanionAnimationState(rawValue: rawValue) else {
            return
        }

        previewView.playAnimation(state)
    }
}
