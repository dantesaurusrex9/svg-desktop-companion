import AppKit

enum AppCopy {
    static let libraryTitle = "LIBRARY"
    static let companionsTitle = "COMPANIONS"
    static let marketplaceTitle = "MARKETPLACE"
    static let uploadAction = "UPLOAD"
    static let browseAction = "BROWSE"
    static let accountAction = "ACCOUNT"
    static let settingsAction = "SETTINGS"
    static let spawnAction = "SPAWN"
    static let importSVGAction = "IMPORT SVG"
    static let importPackageAction = "IMPORT PACKAGE FOLDER"
    static let appearanceTitle = "APPEARANCE"
    static let themeLabel = "THEME"
    static let doneAction = "DONE"
    static let cancelAction = "CANCEL"
    static let saveAction = "SAVE"
    static let nameLabel = "NAME"
    static let speechLabel = "SPEECH"
    static let bubbleLabel = "BUBBLE"
    static let animationLabel = "ANIMATION"
    static let xAxisLabel = "X"
    static let yAxisLabel = "Y"
    static let marketplaceComingSoonTooltip = "MARKETPLACE DOWNLOADS COMING SOON"
    static let accountComingSoonTooltip = "ACCOUNT SUPPORT COMING SOON"
    static let emptyLibrary = "NO COMPANIONS INSTALLED."

    static func activeCount(_ count: Int) -> String {
        count == 1 ? "1 ACTIVE" : "\(count) ACTIVE"
    }
}

enum AppTypography {
    static var pageTitle: NSFont { NSFont.systemFont(ofSize: 22, weight: .semibold) }
    static var sidebarHeader: NSFont { NSFont.systemFont(ofSize: 14, weight: .semibold) }
    static var sidebarStatus: NSFont { NSFont.systemFont(ofSize: 12, weight: .medium) }
    static var sectionLabel: NSFont { NSFont.systemFont(ofSize: 11, weight: .medium) }
    static var modalTitle: NSFont { NSFont.systemFont(ofSize: 16, weight: .semibold) }
    static var formLabel: NSFont { NSFont.systemFont(ofSize: 12, weight: .medium) }
    static var smallLabel: NSFont { NSFont.systemFont(ofSize: 12) }
    static var cardTitle: NSFont { NSFont.systemFont(ofSize: 15, weight: .semibold) }
    static var cardDetail: NSFont { NSFont.systemFont(ofSize: 12) }
    static var badge: NSFont { NSFont.systemFont(ofSize: 11, weight: .medium) }
    static var button: NSFont { NSFont.systemFont(ofSize: 13, weight: .medium) }
    static var primaryButton: NSFont { NSFont.systemFont(ofSize: 13, weight: .semibold) }
    static var field: NSFont { NSFont.systemFont(ofSize: 13) }
}

enum AppLayout {
    static let sidebarWidth: CGFloat = 190
    static let sidebarHorizontalInset: CGFloat = 16
    static let sidebarTopInset: CGFloat = 50
    static let sidebarBottomInset: CGFloat = 18
    static let sidebarItemHeight: CGFloat = 36
    static let sidebarStackSpacing: CGFloat = 12
    static let sidebarStatusSpacing: CGFloat = 14
    static let sidebarSectionSpacing: CGFloat = 18
    static let utilityItemSpacing: CGFloat = 8

    static let contentHorizontalInset: CGFloat = 26
    static let contentTopInset: CGFloat = 44
    static let contentBottomInset: CGFloat = 24
    static let titleToListSpacing: CGFloat = 12

    static let cardMinimumHeight: CGFloat = 112
    static let cardTextLeadingInset: CGFloat = 18
    static let cardPreviewSpacing: CGFloat = 18
    static let cardActionSpacing: CGFloat = 20
    static let cardActionTrailingInset: CGFloat = 18
    static let cardStackSpacing: CGFloat = 10
    static let cardTextSpacing: CGFloat = 6
    static let actionStackSpacing: CGFloat = 8
    static let cardPreviewSize: CGFloat = 82
    static let actionColumnWidth: CGFloat = 92
    static let activeBadgeHeight: CGFloat = 24
    static let activeBadgeHorizontalInset: CGFloat = 9
    static let buttonHeight: CGFloat = 32

    static let roundedCornerRadius: CGFloat = 8
    static let buttonHorizontalPadding: CGFloat = 12
    static let buttonIconSize: CGFloat = 16
    static let buttonImageTitleSpacing: CGFloat = 8
}
