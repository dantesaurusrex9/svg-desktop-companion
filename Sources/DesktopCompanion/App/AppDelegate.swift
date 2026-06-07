import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var libraryController: CompanionLibraryWindowController?
    private var overlayControllers: [String: CompanionWindowController] = [:]
    private var typingMonitor: TypingActivityMonitor?
    private var hotKeyMonitor: GlobalHotKeyMonitor?
    private var importSheetController: CompanionSVGImportWindowController?
    private var settingsController: CompanionSettingsWindowController?
    private var hasKeyboardAccess = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        let libraryController = CompanionLibraryWindowController()
        libraryController.onSpawnPackage = { [weak self] package in
            self?.spawn(package: package)
        }
        libraryController.onImportSVG = { [weak self] in
            self?.importSVG()
        }
        libraryController.onImportPackage = { [weak self] in
            self?.importPackageFolder()
        }
        libraryController.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        libraryController.show()

        self.libraryController = libraryController
        restoreInstances()
        refreshLibrary()

        let typingMonitor = TypingActivityMonitor(
            onTyping: { [weak self] in
                self?.overlayControllers.values.forEach { $0.playTypingReaction() }
            },
            onKeyboardAccessChanged: { [weak self] hasKeyboardAccess in
                self?.hasKeyboardAccess = hasKeyboardAccess
                self?.overlayControllers.values.forEach {
                    $0.setKeyboardAccessEnabled(hasKeyboardAccess)
                }
            }
        )
        typingMonitor.start()

        let hotKeyMonitor = GlobalHotKeyMonitor {
            NSApp.terminate(nil)
        }
        hotKeyMonitor.start()

        self.typingMonitor = typingMonitor
        self.hotKeyMonitor = hotKeyMonitor
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        libraryController?.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveInstances()
        typingMonitor?.stop()
        hotKeyMonitor?.stop()
    }

    private func restoreInstances() {
        for instance in CompanionInstanceStore.load() {
            guard instance.packageID != CompanionPackageLoader.legacyUserPackageID else {
                continue
            }

            guard let package = CompanionPackageLoader.package(id: instance.packageID) else {
                continue
            }

            spawn(instance: instance, package: package, shouldSave: false)
        }

        saveInstances()
    }

    private func spawn(package: CompanionPackage) {
        let instance = CompanionInstance.make(package: package, existingCount: overlayControllers.count)
        spawn(instance: instance, package: package, shouldSave: true)
    }

    private func spawn(instance: CompanionInstance, package: CompanionPackage, shouldSave: Bool) {
        let controller = CompanionWindowController(
            instance: instance,
            package: package,
            onInstanceChanged: { [weak self] _ in
                self?.saveInstances()
                self?.refreshLibrary()
            },
            onInstanceClosed: { [weak self] instanceID in
                self?.removeInstance(id: instanceID)
            }
        )
        overlayControllers[instance.id] = controller
        controller.show()
        controller.setKeyboardAccessEnabled(hasKeyboardAccess)

        if shouldSave {
            saveInstances()
            refreshLibrary()
        }
    }

    private func removeInstance(id instanceID: String) {
        guard let controller = overlayControllers.removeValue(forKey: instanceID) else {
            return
        }

        controller.closeCompanionWindow()
        saveInstances()
        refreshLibrary()
    }

    private func saveInstances() {
        let instances = overlayControllers.values
            .map(\.instance)
            .sorted { $0.id < $1.id }
        CompanionInstanceStore.save(instances)
    }

    private func refreshLibrary() {
        libraryController?.reload(
            packages: CompanionPackageLoader.libraryPackages(),
            instances: overlayControllers.values.map(\.instance)
        )
    }

    private func openSettings() {
        guard let parentWindow = libraryController?.window else {
            return
        }

        let settingsController = CompanionSettingsWindowController()
        settingsController.onThemeSelected = { [weak self] _ in
            self?.libraryController?.reloadTheme()
            self?.refreshLibrary()
        }
        self.settingsController = settingsController
        settingsController.beginSheet(parentWindow: parentWindow) { [weak self] in
            self?.settingsController = nil
        }
    }

    private func importSVG() {
        guard let parentWindow = libraryController?.window else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let svgType = UTType(filenameExtension: "svg") {
            panel.allowedContentTypes = [svgType]
        }

        panel.beginSheetModal(for: parentWindow) { [weak self] response in
            guard response == .OK,
                  let sourceURL = panel.url else {
                return
            }

            self?.showImportSheet(sourceURL: sourceURL, parentWindow: parentWindow)
        }
    }

    private func showImportSheet(sourceURL: URL, parentWindow: NSWindow) {
        do {
            let markup = try CompanionAsset.safeSVGMarkup(from: sourceURL)
            guard CompanionAsset.isUsableCompanionSVG(markup) else {
                showError("Expected SVG bounds: viewBox=\"0 0 220 220\"")
                return
            }

            let sheet = CompanionSVGImportWindowController(
                defaultName: sourceURL.deletingPathExtension().lastPathComponent,
                defaultAnchor: CompanionAsset.mouthAnchor(from: markup)
            )
            importSheetController = sheet
            sheet.beginSheet(parentWindow: parentWindow) { [weak self] result in
                guard let self else {
                    return
                }

                self.importSheetController = nil
                guard let result else {
                    return
                }

                do {
                    _ = try CompanionPackageInstaller.installSVGPackage(
                        sourceSVGURL: sourceURL,
                        displayName: result.displayName,
                        speechAnchor: result.speechAnchor,
                        bubblePlacement: result.bubblePlacement,
                        animationPreset: result.animationPreset
                    )
                    self.refreshLibrary()
                } catch {
                    self.showError("Could not import SVG.")
                }
            }
        } catch {
            showError("Could not read SVG.")
        }
    }

    private func importPackageFolder() {
        guard let parentWindow = libraryController?.window else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        panel.beginSheetModal(for: parentWindow) { [weak self] response in
            guard response == .OK,
                  let sourceURL = panel.url else {
                return
            }

            do {
                _ = try CompanionPackageInstaller.installPackageFolder(sourceFolderURL: sourceURL)
                self?.refreshLibrary()
            } catch {
                self?.showError("Could not import package.")
            }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        if let window = libraryController?.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
