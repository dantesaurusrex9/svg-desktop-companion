import AppKit

final class CompanionLibraryWindowController: NSWindowController {
    var onSpawnPackage: ((CompanionPackage) -> Void)?
    var onImportSVG: (() -> Void)?
    var onImportPackage: (() -> Void)?

    private let packageStack = NSStackView()
    private let activeLabel = AppTheme.label("", font: NSFont.systemFont(ofSize: 12), color: AppTheme.secondaryText)
    private var packages: [CompanionPackage] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Desktop Companion"
        window.minSize = NSSize(width: 620, height: 420)
        window.isReleasedWhenClosed = false

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
        self.packages = packages
        activeLabel.stringValue = "\(instances.count) active"
        rebuildPackageRows(instances: instances)
    }

    private func makeContentView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = AppTheme.background.cgColor

        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 12
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = AppTheme.label("Companions", font: NSFont.systemFont(ofSize: 22, weight: .semibold))
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(activeLabel)

        let importSVGButton = AppTheme.button("Import SVG", target: self, action: #selector(importSVGRequested))
        let importPackageButton = AppTheme.button("Import Package", target: self, action: #selector(importPackageRequested))

        headerStack.addArrangedSubview(titleStack)
        headerStack.addArrangedSubview(NSView())
        headerStack.addArrangedSubview(importSVGButton)
        headerStack.addArrangedSubview(importPackageButton)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        packageStack.orientation = .vertical
        packageStack.alignment = .leading
        packageStack.spacing = 10
        packageStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = packageStack

        root.addSubview(headerStack)
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            headerStack.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 18),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -24),

            packageStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            packageStack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            packageStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            packageStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        return root
    }

    private func rebuildPackageRows(instances: [CompanionInstance]) {
        packageStack.arrangedSubviews.forEach { view in
            packageStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if packages.isEmpty {
            let emptyLabel = AppTheme.label("No companions installed.", font: NSFont.systemFont(ofSize: 14), color: AppTheme.secondaryText)
            packageStack.addArrangedSubview(emptyLabel)
            return
        }

        for package in packages {
            let activeCount = instances.filter { $0.packageID == package.id }.count
            let row = CompanionPackageRowView(package: package, activeCount: activeCount)
            row.onSpawn = { [weak self] package in
                self?.onSpawnPackage?(package)
            }
            packageStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: packageStack.widthAnchor).isActive = true
        }
    }

    @objc private func importSVGRequested() {
        onImportSVG?()
    }

    @objc private func importPackageRequested() {
        onImportPackage?()
    }
}

private final class CompanionPackageRowView: RoundedPanelView {
    var onSpawn: ((CompanionPackage) -> Void)?
    private let package: CompanionPackage

    init(package: CompanionPackage, activeCount: Int) {
        self.package = package
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup(activeCount: activeCount)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup(activeCount: Int) {
        fillColor = AppTheme.backgroundDark

        let nameLabel = AppTheme.label(package.displayName, font: NSFont.systemFont(ofSize: 15, weight: .semibold))
        let detailLabel = AppTheme.label(detailText(activeCount: activeCount), font: NSFont.systemFont(ofSize: 12), color: AppTheme.secondaryText)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(detailLabel)

        let spawnButton = AppTheme.button("Spawn", target: self, action: #selector(spawnRequested))
        spawnButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textStack)
        addSubview(spawnButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 68),

            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: spawnButton.leadingAnchor, constant: -16),

            spawnButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            spawnButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            spawnButton.widthAnchor.constraint(equalToConstant: 82)
        ])
    }

    private func detailText(activeCount: Int) -> String {
        let activeText = activeCount == 1 ? "1 active" : "\(activeCount) active"
        return "\(sourceText) - \(package.animationPreset.title) - \(activeText)"
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
}
