import AppKit
import Testing
@testable import DesktopCompanion

struct CompanionPackageTests {
    @Test
    func testCompanionAssetParsesMouthAnchorAttribute() {
        let anchor = CompanionAsset.mouthAnchor(
            from: #"<svg viewBox="0 0 220 220" data-mouth-anchor="121 94"></svg>"#
        )

        #expect(anchor == NSPoint(x: 121, y: 94))
    }

    @Test
    func testCompanionAssetParsesMouthXYAttributes() {
        let anchor = CompanionAsset.mouthAnchor(
            from: #"<svg viewBox="0 0 220 220" data-mouth-x="118" data-mouth-y="90"></svg>"#
        )

        #expect(anchor == NSPoint(x: 118, y: 90))
    }

    @Test
    func testCompanionAssetFallsBackForInvalidMouthAnchor() {
        let anchor = CompanionAsset.mouthAnchor(
            from: #"<svg viewBox="0 0 220 220" data-mouth-anchor="500 90"></svg>"#
        )

        #expect(anchor == CompanionAsset.defaultMouthAnchor)
    }

    @Test
    func testCompanionPackageLoadsValidManifest() throws {
        let package = try makeCompanionPackage(includeThemes: true)

        #expect(package.id == "test-companion")
        #expect(package.displayName == "Test Companion")
        #expect(package.svgURL.lastPathComponent == "companion.svg")
        #expect(package.conversationThemesDirectoryURL?.lastPathComponent == "ConversationThemes")
        #expect(package.speechAnchor == NSPoint(x: 108, y: 89))
        #expect(package.bubblePlacement == .right)
        #expect(package.animationPreset == .wholeObjectReaction)
    }

    @Test
    func testCompanionPackageRejectsInvalidSVGBounds() throws {
        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                svg: #"<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg"></svg>"#
            )
        }
    }

    @Test
    func testCompanionPackageRejectsOversizedManifest() throws {
        let padding = String(repeating: " ", count: 65_000)

        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "oversized-companion",
                  "displayName": "Oversized Companion",
                  "companionSVG": "companion.svg"
                }
                \(padding)
                """
            )
        }
    }

    @Test
    func testCompanionPackageRejectsOversizedSVG() throws {
        let padding = String(repeating: " ", count: CompanionAsset.maxSVGByteCount)

        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                svg: #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"></svg>"# + padding
            )
        }
    }

    @Test
    func testCompanionPackageRejectsEscapedSVGPath() throws {
        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "bad-companion",
                  "displayName": "Bad Companion",
                  "companionSVG": "../companion.svg"
                }
                """
            )
        }
    }

    @Test
    func testCompanionPackageRejectsUnsafeSVGFeatures() throws {
        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                svg: #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>"#
            )
        }

        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                svg: #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/a.png"/></svg>"#
            )
        }

        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                svg: #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"><style>@import "https://example.com/theme.css";</style></svg>"#
            )
        }
    }

    @Test
    func testCompanionPackageRejectsUnsafePackageID() throws {
        #expect(throws: CompanionPackageError.invalidManifest) {
            try makeCompanionPackage(
                manifest: """
                {
                  "schemaVersion": 1,
                  "id": "../bad-companion",
                  "displayName": "Bad Companion",
                  "companionSVG": "companion.svg"
                }
                """
            )
        }
    }

    @Test
    func testCompanionPackageInstallerCopiesOnlyDeclaredFiles() throws {
        let package = try makeCompanionPackage(includeThemes: true)
        let unusedURL = package.folderURL.appendingPathComponent("unused.txt", isDirectory: false)
        try "do not install".write(to: unusedURL, atomically: true, encoding: .utf8)

        let installRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-install-test-\(UUID().uuidString)", isDirectory: true)
        let installed = try CompanionPackageInstaller.installPackageFolder(
            sourceFolderURL: package.folderURL,
            packagesDirectory: installRootURL
        )

        #expect(installed.id == package.id)
        #expect(FileManager.default.fileExists(atPath: installed.folderURL.appendingPathComponent("companion.json").path))
        #expect(FileManager.default.fileExists(atPath: installed.svgURL.path))
        #expect(FileManager.default.fileExists(atPath: installed.folderURL.appendingPathComponent("ConversationThemes/package-cloud/theme.json").path))
        #expect(!FileManager.default.fileExists(atPath: installed.folderURL.appendingPathComponent("unused.txt").path))
    }

    @Test
    func testCompanionPackageInstallerRejectsDuplicatePackageIDByDefault() throws {
        let package = try makeCompanionPackage()
        let installRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-install-test-\(UUID().uuidString)", isDirectory: true)
        _ = try CompanionPackageInstaller.installPackageFolder(
            sourceFolderURL: package.folderURL,
            packagesDirectory: installRootURL
        )

        #expect(throws: CompanionPackageError.packageAlreadyInstalled(package.id)) {
            try CompanionPackageInstaller.installPackageFolder(
                sourceFolderURL: package.folderURL,
                packagesDirectory: installRootURL
            )
        }
    }

    @Test
    func testSVGPackageInstallerUsesASCIIPackageIDSlug() throws {
        let sourceFolderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-svg-install-source-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolderURL, withIntermediateDirectories: true)
        let sourceSVGURL = sourceFolderURL.appendingPathComponent("companion.svg", isDirectory: false)
        try #"<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg"></svg>"#
            .write(to: sourceSVGURL, atomically: true, encoding: .utf8)
        let installRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-svg-install-test-\(UUID().uuidString)", isDirectory: true)

        let installed = try CompanionPackageInstaller.installSVGPackage(
            sourceSVGURL: sourceSVGURL,
            displayName: "Café Bot!",
            speechAnchor: NSPoint(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .wholeObjectReaction,
            packagesDirectory: installRootURL
        )

        #expect(installed.id == "cafe-bot")
        #expect(FileManager.default.fileExists(atPath: installRootURL.appendingPathComponent("cafe-bot/companion.json").path))
    }

    @Test
    func testCompanionPackageInstallerRejectsSymlinks() throws {
        let package = try makeCompanionPackage()
        let linkURL = package.folderURL.appendingPathComponent("linked.txt", isDirectory: false)
        try FileManager.default.createSymbolicLink(
            at: linkURL,
            withDestinationURL: URL(fileURLWithPath: "/tmp/desktop-companion-linked.txt")
        )

        let installRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("desktop-companion-install-test-\(UUID().uuidString)", isDirectory: true)

        #expect(throws: CompanionPackageError.invalidManifest) {
            try CompanionPackageInstaller.installPackageFolder(
                sourceFolderURL: package.folderURL,
                packagesDirectory: installRootURL
            )
        }
    }

    @Test
    func testCompanionAssetLoadsPackageSVG() throws {
        let package = try makeCompanionPackage(
            svg: #"<svg viewBox="0 0 220 220" data-mouth-anchor="82 71" xmlns="http://www.w3.org/2000/svg"></svg>"#
        )
        let asset = CompanionAsset.load(package: package)

        #expect(asset.mouthAnchor == NSPoint(x: 108, y: 89))
        #expect(asset.markup.contains("data-mouth-anchor=\"82 71\""))
    }

    @Test
    func testCompanionPackageFallsBackToSVGAnchorWhenManifestAnchorIsMissing() throws {
        let package = try makeCompanionPackage(
            manifest: """
            {
              "schemaVersion": 1,
              "id": "svg-anchor-companion",
              "displayName": "SVG Anchor Companion",
              "companionSVG": "companion.svg"
            }
            """,
            svg: #"<svg viewBox="0 0 220 220" data-mouth-anchor="82 71" xmlns="http://www.w3.org/2000/svg"></svg>"#
        )

        #expect(package.speechAnchor == NSPoint(x: 82, y: 71))
        #expect(package.bubblePlacement == .automatic)
        #expect(package.animationPreset == .wholeObjectReaction)
    }

    @Test

    func testInstanceStoreSavesAndRestoresMultipleCompanions() throws {
        let suiteName = "DesktopCompanionInstances-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let first = CompanionInstance(
            id: "one",
            packageID: "lego-vader",
            origin: CompanionAnchor(x: 10, y: 20),
            layerMode: .desktop,
            speechAnchor: CompanionAnchor(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .legoSmash
        )
        let second = CompanionInstance(
            id: "two",
            packageID: "cloud-cat",
            origin: CompanionAnchor(x: 30, y: 40),
            layerMode: .floating,
            speechAnchor: CompanionAnchor(x: 80, y: 70),
            bubblePlacement: .left,
            animationPreset: .idleOnly
        )

        CompanionInstanceStore.save([first, second], userDefaults: defaults)

        #expect(CompanionInstanceStore.load(userDefaults: defaults) == [first, second])
    }

    @Test

    func testNewCompanionInstancesDefaultToAlwaysOnTop() throws {
        let package = try makeCompanionPackage()
        let instance = CompanionInstance.make(package: package, existingCount: 0)

        #expect(instance.layerMode == .alwaysOnTop)
    }

    @Test
    func testInstanceStoreRoundTripsConversationBubbleSize() throws {
        let suiteName = "DesktopCompanionBubbleSize-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let instance = CompanionInstance(
            id: "one",
            packageID: "lego-vader",
            origin: CompanionAnchor(x: 10, y: 20),
            layerMode: .desktop,
            speechAnchor: CompanionAnchor(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .legoSmash,
            conversationBubbleSize: ConversationBubbleSize(width: 480, height: 340)
        )

        CompanionInstanceStore.save([instance], userDefaults: defaults)

        #expect(CompanionInstanceStore.load(userDefaults: defaults) == [instance])
    }

    @Test
    func testInstanceStoreRoundTripsConversationBubbleOffset() throws {
        let suiteName = "DesktopCompanionBubbleOffset-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let instance = CompanionInstance(
            id: "one",
            packageID: "lego-vader",
            origin: CompanionAnchor(x: 10, y: 20),
            layerMode: .desktop,
            speechAnchor: CompanionAnchor(x: 121, y: 94),
            bubblePlacement: .automatic,
            animationPreset: .legoSmash,
            conversationBubbleOffset: CompanionAnchor(x: -80, y: 44)
        )

        CompanionInstanceStore.save([instance], userDefaults: defaults)

        #expect(CompanionInstanceStore.load(userDefaults: defaults) == [instance])
    }

    @Test
    func testInstanceStoreLoadsLegacyInstancesWithoutConversationBubbleSize() throws {
        let suiteName = "DesktopCompanionLegacyBubbleSize-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let data = """
        [
          {
            "id": "legacy",
            "packageID": "lego-vader",
            "origin": { "x": 10, "y": 20 },
            "layerMode": "desktop",
            "speechAnchor": { "x": 121, "y": 94 },
            "bubblePlacement": "automatic",
            "animationPreset": "legoSmash"
          }
        ]
        """.data(using: .utf8)
        defaults.set(data, forKey: "desktopCompanion.instances")

        let instances = CompanionInstanceStore.load(userDefaults: defaults)

        #expect(instances.count == 1)
        #expect(instances.first?.id == "legacy")
        #expect(instances.first?.conversationBubbleSize == nil)
        #expect(instances.first?.conversationBubbleOffset == nil)
    }

    @Test
    func testInstanceStoreIgnoresMalformedConversationBubbleSize() throws {
        let suiteName = "DesktopCompanionMalformedBubbleSize-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let data = """
        [
          {
            "id": "bad-size",
            "packageID": "lego-vader",
            "origin": { "x": 10, "y": 20 },
            "layerMode": "desktop",
            "speechAnchor": { "x": 121, "y": 94 },
            "bubblePlacement": "automatic",
            "animationPreset": "legoSmash",
            "conversationBubbleSize": { "width": "wide", "height": 340 }
          }
        ]
        """.data(using: .utf8)
        defaults.set(data, forKey: "desktopCompanion.instances")

        let instances = CompanionInstanceStore.load(userDefaults: defaults)

        #expect(instances.count == 1)
        #expect(instances.first?.conversationBubbleSize == nil)
    }

    @Test
    func testInstanceStoreIgnoresMalformedConversationBubbleOffset() throws {
        let suiteName = "DesktopCompanionMalformedBubbleOffset-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let data = """
        [
          {
            "id": "bad-offset",
            "packageID": "lego-vader",
            "origin": { "x": 10, "y": 20 },
            "layerMode": "desktop",
            "speechAnchor": { "x": 121, "y": 94 },
            "bubblePlacement": "automatic",
            "animationPreset": "legoSmash",
            "conversationBubbleOffset": { "x": "left", "y": 44 }
          }
        ]
        """.data(using: .utf8)
        defaults.set(data, forKey: "desktopCompanion.instances")

        let instances = CompanionInstanceStore.load(userDefaults: defaults)

        #expect(instances.count == 1)
        #expect(instances.first?.conversationBubbleOffset == nil)
    }

    @Test
    func testInstanceStoreIgnoresInvalidConversationBubbleSize() throws {
        let suiteName = "DesktopCompanionInvalidBubbleSize-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let data = """
        [
          {
            "id": "invalid-size",
            "packageID": "lego-vader",
            "origin": { "x": 10, "y": 20 },
            "layerMode": "desktop",
            "speechAnchor": { "x": 121, "y": 94 },
            "bubblePlacement": "automatic",
            "animationPreset": "legoSmash",
            "conversationBubbleSize": { "width": -20, "height": 0 }
          }
        ]
        """.data(using: .utf8)
        defaults.set(data, forKey: "desktopCompanion.instances")

        let instances = CompanionInstanceStore.load(userDefaults: defaults)

        #expect(instances.count == 1)
        #expect(instances.first?.conversationBubbleSize == nil)
    }
}
