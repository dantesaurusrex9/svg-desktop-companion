import AppKit

struct AppThemePalette {
    let background: NSColor
    let backgroundDark: NSColor
    let border: NSColor
    let row: NSColor
    let rowSecondary: NSColor
    let text: NSColor
    let secondaryText: NSColor
    let accent: NSColor
}

enum AppThemePreset: String, CaseIterable {
    case notesDark
    case graphiteDark

    var title: String {
        switch self {
        case .notesDark:
            "Notes Dark"
        case .graphiteDark:
            "Graphite Dark"
        }
    }
}

enum AppThemeStore {
    static let selectedPresetDefaultsKey = "desktopCompanion.libraryThemePreset"

    static func selectedPreset(userDefaults: UserDefaults = .standard) -> AppThemePreset {
        guard let rawValue = userDefaults.string(forKey: selectedPresetDefaultsKey),
              let preset = AppThemePreset(rawValue: rawValue) else {
            return .notesDark
        }

        return preset
    }

    static func save(_ preset: AppThemePreset, userDefaults: UserDefaults = .standard) {
        userDefaults.set(preset.rawValue, forKey: selectedPresetDefaultsKey)
    }
}

@MainActor
enum AppTheme {
    static let roundedButtonIdentifier = NSUserInterfaceItemIdentifier("desktopCompanion.roundedButton")

    static var background: NSColor { palette.background }
    static var backgroundDark: NSColor { palette.backgroundDark }
    static var border: NSColor { palette.border }
    static var row: NSColor { palette.row }
    static var rowSecondary: NSColor { palette.rowSecondary }
    static var text: NSColor { palette.text }
    static var secondaryText: NSColor { palette.secondaryText }
    static var accent: NSColor { palette.accent }

    private static var palette: AppThemePalette {
        palette(for: AppThemeStore.selectedPreset())
    }

    private static func palette(for preset: AppThemePreset) -> AppThemePalette {
        switch preset {
        case .notesDark:
            AppThemePalette(
                background: NSColor(calibratedRed: 0x29 / 255, green: 0x29 / 255, blue: 0x29 / 255, alpha: 1),
                backgroundDark: NSColor(calibratedRed: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255, alpha: 1),
                border: NSColor(calibratedRed: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255, alpha: 1),
                row: NSColor(calibratedRed: 0x3D / 255, green: 0x3D / 255, blue: 0x3D / 255, alpha: 1),
                rowSecondary: NSColor(calibratedRed: 0x54 / 255, green: 0x54 / 255, blue: 0x54 / 255, alpha: 1),
                text: NSColor(calibratedRed: 0xF8 / 255, green: 0xF8 / 255, blue: 0xF2 / 255, alpha: 1),
                secondaryText: NSColor(calibratedRed: 0xD2 / 255, green: 0xD3 / 255, blue: 0xD3 / 255, alpha: 1),
                accent: NSColor(calibratedRed: 0xFC / 255, green: 0xBA / 255, blue: 0x03 / 255, alpha: 1)
            )
        case .graphiteDark:
            AppThemePalette(
                background: NSColor(calibratedRed: 0x24 / 255, green: 0x26 / 255, blue: 0x28 / 255, alpha: 1),
                backgroundDark: NSColor(calibratedRed: 0x1A / 255, green: 0x1D / 255, blue: 0x20 / 255, alpha: 1),
                border: NSColor(calibratedRed: 0x10 / 255, green: 0x12 / 255, blue: 0x14 / 255, alpha: 1),
                row: NSColor(calibratedRed: 0x36 / 255, green: 0x3A / 255, blue: 0x3F / 255, alpha: 1),
                rowSecondary: NSColor(calibratedRed: 0x4A / 255, green: 0x51 / 255, blue: 0x58 / 255, alpha: 1),
                text: NSColor(calibratedRed: 0xF5 / 255, green: 0xF6 / 255, blue: 0xF2 / 255, alpha: 1),
                secondaryText: NSColor(calibratedRed: 0xC8 / 255, green: 0xCD / 255, blue: 0xD0 / 255, alpha: 1),
                accent: NSColor(calibratedRed: 0xFC / 255, green: 0xBA / 255, blue: 0x03 / 255, alpha: 1)
            )
        }
    }

    static func label(_ text: String, font: NSFont, color: NSColor = AppTheme.text) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    static func button(_ title: String, target: AnyObject?, action: Selector?) -> NSButton {
        roundedButton(
            title: title,
            systemSymbolName: nil,
            target: target,
            action: action,
            fillColor: row,
            titleColor: text,
            contentAlignment: .center,
            height: AppLayout.buttonHeight
        )
    }

    static func primaryButton(_ title: String, target: AnyObject?, action: Selector?) -> NSButton {
        roundedButton(
            title: title,
            systemSymbolName: nil,
            target: target,
            action: action,
            fillColor: accent,
            titleColor: backgroundDark,
            contentAlignment: .center,
            font: AppTypography.primaryButton,
            height: AppLayout.buttonHeight
        )
    }

    static func sidebarButton(
        title: String,
        systemSymbolName: String,
        target: AnyObject?,
        action: Selector?,
        isEnabled: Bool = true,
        fillColor: NSColor = AppTheme.row
    ) -> NSButton {
        roundedButton(
            title: title,
            systemSymbolName: systemSymbolName,
            target: target,
            action: action,
            isEnabled: isEnabled,
            fillColor: fillColor,
            titleColor: text,
            disabledTitleColor: secondaryText,
            contentAlignment: .leading,
            height: AppLayout.sidebarItemHeight
        )
    }

    static func iconButton(
        systemSymbolName: String,
        accessibilityDescription: String,
        target: AnyObject?,
        action: Selector?
    ) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: accessibilityDescription) ?? NSImage(), target: target, action: action)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = secondaryText
        button.toolTip = accessibilityDescription
        return button
    }

    static func styleField(_ field: NSTextField) {
        field.font = AppTypography.field
        field.textColor = text
        field.backgroundColor = backgroundDark
        field.drawsBackground = true
        field.isBezeled = true
    }

    private static func roundedButton(
        title: String,
        systemSymbolName: String?,
        target: AnyObject?,
        action: Selector?,
        isEnabled: Bool = true,
        fillColor: NSColor,
        titleColor: NSColor,
        disabledTitleColor: NSColor = AppTheme.secondaryText,
        contentAlignment: AppButtonContentAlignment,
        font: NSFont = AppTypography.button,
        height: CGFloat
    ) -> NSButton {
        let button = NSButton(frame: .zero)
        let cell = AppRoundedButtonCell(textCell: title)
        cell.fillColor = fillColor
        cell.borderColor = border
        cell.titleColor = titleColor
        cell.disabledTitleColor = disabledTitleColor
        cell.contentAlignment = contentAlignment
        cell.font = font

        button.cell = cell
        button.title = title
        button.target = target
        button.action = action
        button.font = font
        button.identifier = roundedButtonIdentifier
        button.image = systemSymbolName.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: title) } ?? NSImage()
        button.imagePosition = systemSymbolName == nil ? .noImage : .imageLeading
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.alignment = contentAlignment.textAlignment
        button.contentTintColor = isEnabled ? titleColor : disabledTitleColor
        button.isEnabled = isEnabled
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: height)
        ])

        return button
    }
}

private enum AppButtonContentAlignment {
    case leading
    case center

    var textAlignment: NSTextAlignment {
        switch self {
        case .leading:
            .left
        case .center:
            .center
        }
    }
}

private final class AppRoundedButtonCell: NSButtonCell {
    var fillColor = NSColor.clear
    var borderColor = NSColor.clear
    var titleColor = NSColor.labelColor
    var disabledTitleColor = NSColor.secondaryLabelColor
    var contentAlignment = AppButtonContentAlignment.center
    var contentInsets = NSEdgeInsets(top: 0, left: AppLayout.buttonHorizontalPadding, bottom: 0, right: AppLayout.buttonHorizontalPadding)
    var iconSize = AppLayout.buttonIconSize
    var imageTitleSpacing = AppLayout.buttonImageTitleSpacing
    var cornerRadius = AppLayout.roundedCornerRadius

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        drawBackground(in: cellFrame)
        drawContent(in: cellFrame, controlView: controlView)
    }

    private func drawBackground(in cellFrame: NSRect) {
        let rect = cellFrame.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        (isHighlighted ? highlightedFillColor : fillColor).setFill()
        path.fill()

        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private var highlightedFillColor: NSColor {
        fillColor.blended(withFraction: 0.08, of: NSColor.white) ?? fillColor
    }

    private func drawContent(in cellFrame: NSRect, controlView: NSView) {
        let contentRect = NSRect(
            x: cellFrame.minX + contentInsets.left,
            y: cellFrame.minY + contentInsets.bottom,
            width: max(0, cellFrame.width - contentInsets.left - contentInsets.right),
            height: max(0, cellFrame.height - contentInsets.top - contentInsets.bottom)
        )
        let iconWidth = image?.isValid == true && imagePosition != .noImage ? iconSize : 0
        let spacing = iconWidth > 0 && !title.isEmpty ? imageTitleSpacing : 0
        let availableTitleWidth = max(0, contentRect.width - iconWidth - spacing)
        let titleWidth = min(titleSize(width: availableTitleWidth).width, availableTitleWidth)
        let contentWidth = iconWidth + spacing + titleWidth
        let contentX: CGFloat
        switch contentAlignment {
        case .leading:
            contentX = contentRect.minX
        case .center:
            contentX = contentRect.minX + max(0, (contentRect.width - contentWidth) / 2)
        }

        var nextX = contentX
        if iconWidth > 0, let image {
            draw(image: image, atX: nextX, in: contentRect)
            nextX += iconWidth + spacing
        }

        drawTitle(atX: nextX, width: titleWidth, in: contentRect)
    }

    private func titleSize(width: CGFloat) -> NSSize {
        attributedButtonTitle().boundingRect(
            with: NSSize(width: max(1, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        ).size
    }

    private func draw(image: NSImage, atX x: CGFloat, in contentRect: NSRect) {
        let iconRect = NSRect(
            x: x,
            y: contentRect.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        let imageCopy = image.copy() as? NSImage ?? image
        imageCopy.isTemplate = true
        (isEnabled ? titleColor : disabledTitleColor).set()
        imageCopy.draw(
            in: iconRect,
            from: .zero,
            operation: .sourceOver,
            fraction: isEnabled ? 1 : 0.62,
            respectFlipped: true,
            hints: nil
        )
    }

    private func drawTitle(atX x: CGFloat, width: CGFloat, in contentRect: NSRect) {
        let attributedTitle = attributedButtonTitle()
        let titleHeight = ceil(attributedTitle.size().height)
        let titleRect = NSRect(
            x: x,
            y: contentRect.midY - titleHeight / 2,
            width: max(0, width),
            height: titleHeight
        )
        attributedTitle.draw(
            with: titleRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
    }

    private func attributedButtonTitle() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = contentAlignment.textAlignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        return NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: isEnabled ? titleColor : disabledTitleColor,
                .font: font ?? AppTypography.button,
                .paragraphStyle: paragraphStyle
            ]
        )
    }
}

class RoundedPanelView: NSView {
    var fillColor: NSColor = AppTheme.row {
        didSet {
            layer?.backgroundColor = fillColor.cgColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = fillColor.cgColor
        layer?.borderColor = AppTheme.border.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = AppLayout.roundedCornerRadius
    }
}
