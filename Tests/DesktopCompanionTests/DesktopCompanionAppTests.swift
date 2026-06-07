import AppKit
import Testing
@testable import DesktopCompanion

struct DesktopCompanionAppTests {
    @MainActor
    @Test
    func testCompanionContextMenuContainsConversate() {
        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ) else {
            Issue.record("Could not create right-click event")
            return
        }

        let view = CompanionContentView(frame: NSRect(origin: .zero, size: CompanionWindowMetrics.size))
        view.conversationThemes = [
            ConversationThemeSummary(id: "cloud-default", displayName: "Cloud Default")
        ]
        view.selectedConversationThemeID = "cloud-default"
        let menu = view.menu(for: event)

        #expect(menu?.items.contains { $0.title == "Preview Animation" } == true)
        #expect(
            menu?.items.first(where: { $0.title == "Preview Animation" })?.submenu?.items.map(\.title) ==
                CompanionAnimationState.allCases.map(\.title)
        )
        #expect(menu?.items.contains { $0.title == "Test Bash" } == false)
        #expect(menu?.items.contains { $0.title == "Conversate" } == true)
        #expect(menu?.items.contains { $0.title == "Reload Overlay Theme" } == true)
        #expect(menu?.items.contains { $0.title == "Companion Package" } == false)
        #expect(menu?.items.first(where: { $0.title == "Overlay Theme" })?.submenu?.items.count == 1)
    }

    @MainActor
    @Test
    func testLibraryCardsShowActiveCountsAndSpawnPackages() throws {
        let firstPackage = testPackage(id: "first-package", displayName: "LEGO Vader")
        let secondPackage = testPackage(id: "second-package", displayName: "Tiny Bot")
        let legacyPackage = testPackage(id: CompanionPackageLoader.legacyUserPackageID, displayName: "User SVG Override")
        let controller = CompanionLibraryWindowController()
        var spawnedPackageIDs: [String] = []
        var didRequestSettings = false
        controller.onSpawnPackage = { package in
            spawnedPackageIDs.append(package.id)
        }
        controller.onOpenSettings = {
            didRequestSettings = true
        }

        controller.reload(
            packages: [legacyPackage, firstPackage, secondPackage],
            instances: [
                testInstance(id: "legacy", packageID: legacyPackage.id),
                testInstance(id: "one", packageID: firstPackage.id),
                testInstance(id: "two", packageID: firstPackage.id),
                testInstance(id: "three", packageID: secondPackage.id)
            ]
        )

        let contentView = try #require(controller.window?.contentView)
        let labels = descendantViews(ofType: NSTextField.self, in: contentView)
        let labelTexts = labels.map(\.stringValue)
        let buttons = descendantViews(ofType: NSButton.self, in: contentView)
        let buttonTitles = buttons.map(\.title)
        let spawnButtons = buttons.filter { $0.title == AppCopy.spawnAction }
        let browseButton = try #require(buttons.first { $0.title == AppCopy.browseAction })
        let accountButton = try #require(buttons.first { $0.title == AppCopy.accountAction })
        let settingsButton = try #require(buttons.first { $0.title == AppCopy.settingsAction })
        let sharedButtonTitles = Set([
            AppCopy.companionsTitle,
            AppCopy.uploadAction,
            AppCopy.browseAction,
            AppCopy.accountAction,
            AppCopy.settingsAction
        ])
        let sharedButtons = buttons.filter { sharedButtonTitles.contains($0.title) }
        let cardActiveLabels = labels.filter { [AppCopy.activeCount(2), AppCopy.activeCount(1)].contains($0.stringValue) }
        let previewViews = descendantViews(ofType: SVGCompanionView.self, in: contentView)

        #expect(labelTexts.contains(AppCopy.libraryTitle))
        #expect(labelTexts.contains(AppCopy.activeCount(3)))
        #expect(labelTexts.contains(AppCopy.activeCount(2)))
        #expect(labelTexts.contains(AppCopy.activeCount(1)))
        #expect(labelTexts.contains(AppCopy.marketplaceTitle))
        #expect(!labelTexts.contains("Desktop Companion"))
        #expect(controller.window?.title == AppCopy.libraryTitle)
        #expect(labelTexts.contains(firstPackage.displayName))
        #expect(labelTexts.contains(secondPackage.displayName))
        #expect(!labelTexts.contains(firstPackage.displayName.uppercased()))
        #expect(!labelTexts.contains(secondPackage.displayName.uppercased()))
        #expect(!labelTexts.contains(legacyPackage.displayName))
        #expect(buttonTitles.contains(AppCopy.uploadAction))
        #expect(buttonTitles.contains(AppCopy.browseAction))
        #expect(buttonTitles.contains(AppCopy.accountAction))
        #expect(buttonTitles.contains(AppCopy.settingsAction))
        #expect(!browseButton.isEnabled)
        #expect(browseButton.toolTip == AppCopy.marketplaceComingSoonTooltip)
        #expect(!accountButton.isEnabled)
        #expect(accountButton.toolTip == AppCopy.accountComingSoonTooltip)
        #expect(spawnButtons.count == 2)
        #expect(sharedButtons.count == sharedButtonTitles.count)
        #expect(sharedButtons.allSatisfy { $0.identifier == AppTheme.roundedButtonIdentifier })
        #expect(spawnButtons.allSatisfy { $0.identifier == AppTheme.roundedButtonIdentifier })
        #expect(spawnButtons.allSatisfy { $0.alignment == .center })
        #expect(sharedButtons.allSatisfy { !$0.isBordered })
        #expect(cardActiveLabels.count == 2)
        #expect(cardActiveLabels.allSatisfy { $0.alignment == .center })
        #expect(previewViews.count == 2)
        #expect(previewViews.allSatisfy { hasIdleAnimation(in: $0) })

        settingsButton.performClick(nil)
        spawnButtons.forEach { $0.performClick(nil) }

        #expect(didRequestSettings)
        #expect(spawnedPackageIDs.count == 2)
        #expect(Set(spawnedPackageIDs) == Set([firstPackage.id, secondPackage.id]))
        controller.close()
    }

    @MainActor
    @Test
    func testCompanionDragOriginTracksScreenDelta() {
        let origin = CompanionContentView.draggedWindowOrigin(
            dragStartScreenPoint: NSPoint(x: 100, y: 200),
            currentScreenPoint: NSPoint(x: 125, y: 178),
            dragStartWindowOrigin: NSPoint(x: 40, y: 90)
        )

        #expect(origin == NSPoint(x: 65, y: 68))
    }

    @MainActor
    @Test
    func testIdleOnlyContextMenuDisablesUnsupportedAnimationStates() {
        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ) else {
            Issue.record("Could not create right-click event")
            return
        }

        let view = CompanionContentView(
            frame: NSRect(origin: .zero, size: CompanionWindowMetrics.size),
            package: nil,
            animationPreset: .idleOnly
        )
        let previewItems = view.menu(for: event)?
            .items
            .first(where: { $0.title == "Preview Animation" })?
            .submenu?
            .items ?? []

        #expect(previewItems.count == CompanionAnimationState.allCases.count)
        #expect(previewItems.allSatisfy { !$0.isEnabled })
    }

    @MainActor
    @Test
    func testConversationRunningStateMapsToThinkingAnimation() {
        #expect(CompanionWindowController.animationState(forConversationRunning: true) == .thinking)
        #expect(CompanionWindowController.animationState(forConversationRunning: false) == nil)
    }

    @MainActor
    @Test
    func testConversationRunningStateNotifiesOnSuccess() throws {
        let submitted = try submittedConversationController()

        #expect(submitted.recorder.values == [true])
        submitted.runner.complete(.success("Done"))
        #expect(submitted.recorder.values == [true, false])
    }

    @MainActor
    @Test
    func testConversationRunningStateNotifiesOnFailure() throws {
        let submitted = try submittedConversationController()

        #expect(submitted.recorder.values == [true])
        submitted.runner.complete(.failure(.missingResponse))
        #expect(submitted.recorder.values == [true, false])
    }

    @MainActor
    @Test
    func testConversationRunningStateNotifiesOnCancel() throws {
        let submitted = try submittedConversationController()

        #expect(submitted.recorder.values == [true])
        submitted.controller.closeBubble()
        #expect(submitted.runner.didCancel)
        #expect(submitted.recorder.values == [true, false])
    }

    @MainActor
    @Test
    func testSettingsThemeSelectionPersistsAndNotifies() throws {
        let suiteName = "DesktopCompanionSettings-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let controller = CompanionSettingsWindowController(userDefaults: defaults)
        var selectedPreset: AppThemePreset?
        controller.onThemeSelected = { preset in
            selectedPreset = preset
        }

        let contentView = try #require(controller.window?.contentView)
        let themePopup = try #require(descendantViews(ofType: NSPopUpButton.self, in: contentView).first)
        themePopup.selectItem(withTitle: AppThemePreset.graphiteDark.title)
        let action = try #require(themePopup.action)
        NSApplication.shared.sendAction(action, to: themePopup.target, from: themePopup)

        #expect(AppThemeStore.selectedPreset(userDefaults: defaults) == .graphiteDark)
        #expect(selectedPreset == .graphiteDark)
        controller.close()
    }
}
