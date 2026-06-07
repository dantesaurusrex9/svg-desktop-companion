import AppKit

final class CompanionSettingsWindowController: NSWindowController {
    var onThemeSelected: ((AppThemePreset) -> Void)?

    private let themePopup = NSPopUpButton()
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 170),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = AppCopy.settingsAction
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.contentView = makeContentView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func beginSheet(parentWindow: NSWindow, completion: @escaping () -> Void) {
        guard let window else {
            completion()
            return
        }

        parentWindow.beginSheet(window) { _ in
            completion()
        }
    }

    private func makeContentView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = AppTheme.background.cgColor

        let titleLabel = AppTheme.label(AppCopy.appearanceTitle, font: AppTypography.modalTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let themeLabel = AppTheme.label(AppCopy.themeLabel, font: AppTypography.formLabel, color: AppTheme.secondaryText)
        themeLabel.translatesAutoresizingMaskIntoConstraints = false

        configureThemePopup()
        themePopup.translatesAutoresizingMaskIntoConstraints = false

        let themeRow = NSStackView(views: [themeLabel, themePopup])
        themeRow.orientation = .horizontal
        themeRow.alignment = .centerY
        themeRow.spacing = 12
        themeRow.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = AppTheme.primaryButton(AppCopy.doneAction, target: self, action: #selector(doneRequested))
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(titleLabel)
        root.addSubview(themeRow)
        root.addSubview(doneButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -24),
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),

            themeRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            themeRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            themeRow.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 22),

            themeLabel.widthAnchor.constraint(equalToConstant: 72),
            themePopup.heightAnchor.constraint(equalToConstant: 28),

            doneButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            doneButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            doneButton.widthAnchor.constraint(equalToConstant: 82)
        ])

        return root
    }

    private func configureThemePopup() {
        themePopup.removeAllItems()
        for preset in AppThemePreset.allCases {
            themePopup.addItem(withTitle: preset.title)
            themePopup.lastItem?.representedObject = preset.rawValue
        }
        themePopup.selectItem(withTitle: AppThemeStore.selectedPreset(userDefaults: userDefaults).title)
        themePopup.font = AppTypography.field
        themePopup.target = self
        themePopup.action = #selector(themeSelected(_:))
    }

    @objc private func themeSelected(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let preset = AppThemePreset(rawValue: rawValue) else {
            return
        }

        AppThemeStore.save(preset, userDefaults: userDefaults)
        onThemeSelected?(preset)
        window?.contentView?.layer?.backgroundColor = AppTheme.background.cgColor
    }

    @objc private func doneRequested() {
        guard let window else {
            return
        }

        window.sheetParent?.endSheet(window)
    }
}
