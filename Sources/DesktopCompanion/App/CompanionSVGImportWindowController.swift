import AppKit

struct CompanionSVGImportResult {
    let displayName: String
    let speechAnchor: NSPoint
    let bubblePlacement: CompanionBubblePlacement
    let animationPreset: CompanionAnimationPreset
}

final class CompanionSVGImportWindowController: NSWindowController {
    private let nameField = NSTextField()
    private let anchorXField = NSTextField()
    private let anchorYField = NSTextField()
    private let placementPopup = NSPopUpButton()
    private let animationPopup = NSPopUpButton()
    private var completion: ((CompanionSVGImportResult?) -> Void)?

    init(defaultName: String, defaultAnchor: NSPoint) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 286),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = AppCopy.importSVGAction
        window.isReleasedWhenClosed = false

        super.init(window: window)

        nameField.stringValue = defaultName
        anchorXField.stringValue = String(format: "%.0f", defaultAnchor.x)
        anchorYField.stringValue = String(format: "%.0f", defaultAnchor.y)
        window.contentView = makeContentView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func beginSheet(parentWindow: NSWindow, completion: @escaping (CompanionSVGImportResult?) -> Void) {
        self.completion = completion
        parentWindow.beginSheet(window!) { [weak self] _ in
            self?.completion = nil
        }
    }

    private func makeContentView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = AppTheme.background.cgColor

        AppTheme.styleField(nameField)
        AppTheme.styleField(anchorXField)
        AppTheme.styleField(anchorYField)
        placementPopup.font = AppTypography.field
        animationPopup.font = AppTypography.field

        let formStack = NSStackView()
        formStack.orientation = .vertical
        formStack.spacing = 14
        formStack.translatesAutoresizingMaskIntoConstraints = false

        formStack.addArrangedSubview(row(label: AppCopy.nameLabel, control: nameField))
        formStack.addArrangedSubview(anchorRow())
        formStack.addArrangedSubview(row(label: AppCopy.bubbleLabel, control: placementPopup))
        formStack.addArrangedSubview(row(label: AppCopy.animationLabel, control: animationPopup))

        configurePopups()

        let cancelButton = AppTheme.button(AppCopy.cancelAction, target: self, action: #selector(cancelRequested))
        let saveButton = AppTheme.primaryButton(AppCopy.saveAction, target: self, action: #selector(saveRequested))
        let buttonStack = NSStackView(views: [cancelButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .centerY
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(formStack)
        root.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            formStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            formStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            formStack.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),

            buttonStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            buttonStack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),

            cancelButton.widthAnchor.constraint(equalToConstant: 82),
            saveButton.widthAnchor.constraint(equalToConstant: 82)
        ])

        return root
    }

    private func row(label: String, control: NSControl) -> NSView {
        let labelView = AppTheme.label(label, font: AppTypography.formLabel, color: AppTheme.secondaryText)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            labelView.widthAnchor.constraint(equalToConstant: 74),
            control.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            control.heightAnchor.constraint(equalToConstant: 28)
        ])
        return stack
    }

    private func anchorRow() -> NSView {
        let labelView = AppTheme.label(AppCopy.speechLabel, font: AppTypography.formLabel, color: AppTheme.secondaryText)
        labelView.translatesAutoresizingMaskIntoConstraints = false

        let xLabel = AppTheme.label(AppCopy.xAxisLabel, font: AppTypography.smallLabel, color: AppTheme.secondaryText)
        let yLabel = AppTheme.label(AppCopy.yAxisLabel, font: AppTypography.smallLabel, color: AppTheme.secondaryText)
        anchorXField.translatesAutoresizingMaskIntoConstraints = false
        anchorYField.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [labelView, xLabel, anchorXField, yLabel, anchorYField])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            labelView.widthAnchor.constraint(equalToConstant: 74),
            anchorXField.widthAnchor.constraint(equalToConstant: 70),
            anchorYField.widthAnchor.constraint(equalToConstant: 70),
            anchorXField.heightAnchor.constraint(equalToConstant: 28),
            anchorYField.heightAnchor.constraint(equalToConstant: 28)
        ])
        return stack
    }

    private func configurePopups() {
        for placement in CompanionBubblePlacement.allCases {
            placementPopup.addItem(withTitle: placement.title)
            placementPopup.lastItem?.representedObject = placement.rawValue
        }
        placementPopup.selectItem(withTitle: CompanionBubblePlacement.automatic.title)

        for preset in CompanionAnimationPreset.allCases {
            animationPopup.addItem(withTitle: preset.title)
            animationPopup.lastItem?.representedObject = preset.rawValue
        }
        animationPopup.selectItem(withTitle: CompanionAnimationPreset.wholeObjectReaction.title)
    }

    @objc private func saveRequested() {
        let displayName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty,
              let x = Double(anchorXField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let y = Double(anchorYField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let placementRawValue = placementPopup.selectedItem?.representedObject as? String,
              let placement = CompanionBubblePlacement(rawValue: placementRawValue),
              let presetRawValue = animationPopup.selectedItem?.representedObject as? String,
              let preset = CompanionAnimationPreset(rawValue: presetRawValue) else {
            NSSound.beep()
            return
        }

        let anchor = NSPoint(x: x, y: y)
        guard CompanionAsset.isValidAnchor(anchor) else {
            NSSound.beep()
            return
        }

        complete(
            CompanionSVGImportResult(
                displayName: displayName,
                speechAnchor: anchor,
                bubblePlacement: placement,
                animationPreset: preset
            )
        )
    }

    @objc private func cancelRequested() {
        complete(nil)
    }

    private func complete(_ result: CompanionSVGImportResult?) {
        let completion = completion
        self.completion = nil
        guard let window,
              let sheetParent = window.sheetParent else {
            completion?(result)
            return
        }

        sheetParent.endSheet(window)
        completion?(result)
    }
}
