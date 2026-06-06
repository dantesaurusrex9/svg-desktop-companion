import AppKit

@MainActor
enum AppTheme {
    static let background = NSColor(calibratedRed: 0x29 / 255, green: 0x29 / 255, blue: 0x29 / 255, alpha: 1)
    static let backgroundDark = NSColor(calibratedRed: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255, alpha: 1)
    static let border = NSColor(calibratedRed: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255, alpha: 1)
    static let row = NSColor(calibratedRed: 0x3D / 255, green: 0x3D / 255, blue: 0x3D / 255, alpha: 1)
    static let rowSecondary = NSColor(calibratedRed: 0x54 / 255, green: 0x54 / 255, blue: 0x54 / 255, alpha: 1)
    static let text = NSColor(calibratedRed: 0xF8 / 255, green: 0xF8 / 255, blue: 0xF2 / 255, alpha: 1)
    static let secondaryText = NSColor(calibratedRed: 0xD2 / 255, green: 0xD3 / 255, blue: 0xD3 / 255, alpha: 1)
    static let accent = NSColor(calibratedRed: 0xFC / 255, green: 0xBA / 255, blue: 0x03 / 255, alpha: 1)

    static func label(_ text: String, font: NSFont, color: NSColor = AppTheme.text) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    static func button(_ title: String, target: AnyObject?, action: Selector?) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        return button
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
        layer?.cornerRadius = 8
    }
}
