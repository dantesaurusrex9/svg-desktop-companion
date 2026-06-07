import AppKit
import Foundation

enum CompanionBubblePlacement: String, Codable, CaseIterable {
    case automatic
    case above
    case right
    case left

    var title: String {
        switch self {
        case .automatic:
            "Automatic"
        case .above:
            "Above"
        case .right:
            "Right"
        case .left:
            "Left"
        }
    }
}

enum CompanionAnimationPreset: String, Codable, CaseIterable {
    case idleOnly
    case wholeObjectReaction
    case legoSmash

    var title: String {
        switch self {
        case .idleOnly:
            "Idle Only"
        case .wholeObjectReaction:
            "Whole Object"
        case .legoSmash:
            "LEGO Smash"
        }
    }
}

struct CompanionAnchor: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat

    var point: NSPoint {
        NSPoint(x: x, y: y)
    }

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    init(point: NSPoint) {
        self.x = point.x
        self.y = point.y
    }
}

struct CompanionPackage: Equatable {
    let id: String
    let displayName: String
    let folderURL: URL
    let svgURL: URL
    let conversationThemesDirectoryURL: URL?
    let speechAnchor: NSPoint
    let bubblePlacement: CompanionBubblePlacement
    let animationPreset: CompanionAnimationPreset
}

struct CompanionPackageSummary: Equatable {
    let id: String
    let displayName: String
}

enum CompanionPackageLoader {
    static let selectedPackageDefaultsKey = "desktopCompanion.packageID"
    static let legacyUserPackageID = "desktop-companion-user-override"
    private static let maxManifestByteCount: UInt64 = 64_000

    static var userPackagesDirectory: URL? {
        DesktopCompanionPaths.applicationSupportDirectoryURL?
            .appendingPathComponent("Companions", isDirectory: true)
    }

    static var legacyUserSVGURL: URL? {
        DesktopCompanionPaths.applicationSupportDirectoryURL?
            .appendingPathComponent("companion.svg", isDirectory: false)
    }

    static func selectedPackage(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> CompanionPackage? {
        let packages = availablePackages(fileManager: fileManager)
        if let selectedID = userDefaults.string(forKey: selectedPackageDefaultsKey),
           let selectedPackage = packages.first(where: { $0.id == selectedID }) {
            return selectedPackage
        }

        if let legacyPackage = packages.first(where: { $0.id == legacyUserPackageID }) {
            return legacyPackage
        }

        if let bundledPackage = bundledPackages(fileManager: fileManager).first {
            return bundledPackage
        }

        return packages.first
    }

    static func saveSelectedPackageID(_ packageID: String, userDefaults: UserDefaults = .standard) {
        userDefaults.set(packageID, forKey: selectedPackageDefaultsKey)
    }

    static func availablePackageSummaries() -> [CompanionPackageSummary] {
        availablePackages().map {
            CompanionPackageSummary(id: $0.id, displayName: $0.displayName)
        }
    }

    static func package(id packageID: String, fileManager: FileManager = .default) -> CompanionPackage? {
        availablePackages(fileManager: fileManager).first { $0.id == packageID }
    }

    static func availablePackages(fileManager: FileManager = .default) -> [CompanionPackage] {
        var packages: [CompanionPackage] = []
        if let legacyPackage = legacyUserPackage(fileManager: fileManager) {
            packages.append(legacyPackage)
        }
        packages.append(contentsOf: userPackages(fileManager: fileManager))
        packages.append(contentsOf: bundledPackages(fileManager: fileManager))

        return packages.reduce(into: []) { uniquePackages, package in
            if !uniquePackages.contains(where: { $0.id == package.id }) {
                uniquePackages.append(package)
            }
        }
    }

    static func libraryPackages(fileManager: FileManager = .default) -> [CompanionPackage] {
        availablePackages(fileManager: fileManager).filter { $0.id != legacyUserPackageID }
    }

    static func loadPackage(from folderURL: URL, fileManager: FileManager = .default) throws -> CompanionPackage {
        let manifestURL = folderURL.appendingPathComponent("companion.json", isDirectory: false)
        let manifestData = try dataIfSmall(from: manifestURL, maxBytes: maxManifestByteCount, fileManager: fileManager)
        let manifest = try JSONDecoder().decode(CompanionPackageManifest.self, from: manifestData)

        guard manifest.schemaVersion == 1,
              isValidPackageID(manifest.id),
              !manifest.displayName.isEmpty,
              let svgURL = childURL(named: manifest.companionSVG, in: folderURL, isDirectory: false),
              fileManager.fileExists(atPath: svgURL.path),
              let markup = try? CompanionAsset.safeSVGMarkup(from: svgURL, fileManager: fileManager),
              CompanionAsset.isUsableCompanionSVG(markup) else {
            throw CompanionPackageError.invalidManifest
        }

        let speechAnchor = try resolvedSpeechAnchor(from: manifest.speechAnchor, markup: markup)
        let themesDirectoryURL = try manifest.conversationThemesDirectory.map { directoryName in
            guard let directoryURL = childURL(named: directoryName, in: folderURL, isDirectory: true),
                  isDirectory(directoryURL) else {
                throw CompanionPackageError.invalidManifest
            }

            return directoryURL
        }

        return CompanionPackage(
            id: manifest.id,
            displayName: manifest.displayName,
            folderURL: folderURL,
            svgURL: svgURL,
            conversationThemesDirectoryURL: themesDirectoryURL,
            speechAnchor: speechAnchor,
            bubblePlacement: manifest.bubblePlacement ?? .automatic,
            animationPreset: manifest.animationPreset ?? .wholeObjectReaction
        )
    }

    private static func legacyUserPackage(fileManager: FileManager) -> CompanionPackage? {
        guard let svgURL = legacyUserSVGURL,
              fileManager.fileExists(atPath: svgURL.path),
              let markup = try? CompanionAsset.safeSVGMarkup(from: svgURL, fileManager: fileManager),
              CompanionAsset.isUsableCompanionSVG(markup) else {
            return nil
        }

        return CompanionPackage(
            id: legacyUserPackageID,
            displayName: "User SVG Override",
            folderURL: svgURL.deletingLastPathComponent(),
            svgURL: svgURL,
            conversationThemesDirectoryURL: nil,
            speechAnchor: CompanionAsset.mouthAnchor(from: markup),
            bubblePlacement: .automatic,
            animationPreset: .wholeObjectReaction
        )
    }

    private static func userPackages(fileManager: FileManager) -> [CompanionPackage] {
        guard let userPackagesDirectory else {
            return []
        }

        return packages(in: userPackagesDirectory, fileManager: fileManager)
    }

    private static func bundledPackages(fileManager: FileManager) -> [CompanionPackage] {
        guard let bundledPackagesDirectory = Bundle.module.resourceURL?
            .appendingPathComponent("Companions", isDirectory: true) else {
            return []
        }

        return packages(in: bundledPackagesDirectory, fileManager: fileManager)
    }

    private static func packages(in directoryURL: URL, fileManager: FileManager) -> [CompanionPackage] {
        guard let folderURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return folderURLs
            .filter { isDirectory($0) }
            .compactMap { folderURL in
                do {
                    return try loadPackage(from: folderURL, fileManager: fileManager)
                } catch {
                    AppLogger.packages.error("Ignoring invalid companion package: \(folderURL.lastPathComponent, privacy: .public)")
                    return nil
                }
            }
            .sorted { lhs, rhs in
                if lhs.folderURL.lastPathComponent == "default" {
                    return true
                }
                if rhs.folderURL.lastPathComponent == "default" {
                    return false
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    static func childURL(named path: String, in folderURL: URL, isDirectory: Bool) -> URL? {
        guard !path.isEmpty,
              !path.hasPrefix("/") else {
            return nil
        }

        let rootURL = folderURL.resolvingSymlinksInPath().standardizedFileURL
        let childURL = folderURL
            .appendingPathComponent(path, isDirectory: isDirectory)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard childURL.path.hasPrefix(rootURL.path + "/") else {
            return nil
        }

        return childURL
    }

    private static func isValidPackageID(_ packageID: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard !packageID.isEmpty,
              packageID.first != "-",
              packageID.last != "-" else {
            return false
        }

        return packageID.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func resolvedSpeechAnchor(from manifestAnchor: CompanionAnchor?, markup: String) throws -> NSPoint {
        if let manifestAnchor {
            let point = manifestAnchor.point
            guard CompanionAsset.isValidAnchor(point) else {
                throw CompanionPackageError.invalidManifest
            }

            return point
        }

        return CompanionAsset.mouthAnchor(from: markup)
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func dataIfSmall(from url: URL, maxBytes: UInt64, fileManager: FileManager) throws -> Data {
        if let fileSize = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber,
           fileSize.uint64Value > maxBytes {
            throw CompanionPackageError.invalidManifest
        }

        let data = try Data(contentsOf: url)
        guard data.count <= maxBytes else {
            throw CompanionPackageError.invalidManifest
        }

        return data
    }
}

enum CompanionPackageError: Error, Equatable {
    case invalidManifest
}

private struct CompanionPackageManifest: Codable {
    let schemaVersion: Int
    let id: String
    let displayName: String
    let companionSVG: String
    let conversationThemesDirectory: String?
    let speechAnchor: CompanionAnchor?
    let bubblePlacement: CompanionBubblePlacement?
    let animationPreset: CompanionAnimationPreset?
}

enum CompanionPackageInstaller {
    private static let maxPackageFileCount = 200
    private static let maxPackageTotalBytes: UInt64 = 10_000_000

    static func installSVGPackage(
        sourceSVGURL: URL,
        displayName: String,
        speechAnchor: NSPoint,
        bubblePlacement: CompanionBubblePlacement,
        animationPreset: CompanionAnimationPreset,
        fileManager: FileManager = .default
    ) throws -> CompanionPackage {
        let markup = try CompanionAsset.safeSVGMarkup(from: sourceSVGURL, fileManager: fileManager)
        guard CompanionAsset.isUsableCompanionSVG(markup),
              CompanionAsset.isValidAnchor(speechAnchor) else {
            throw CompanionPackageError.invalidManifest
        }

        let packageID = uniquePackageID(baseID: slug(from: displayName), fileManager: fileManager)
        let packageDirectory = try userPackagesDirectory(fileManager: fileManager)
            .appendingPathComponent(packageID, isDirectory: true)
        try fileManager.createDirectory(at: packageDirectory, withIntermediateDirectories: true)

        let svgURL = packageDirectory.appendingPathComponent("companion.svg", isDirectory: false)
        if fileManager.fileExists(atPath: svgURL.path) {
            try fileManager.removeItem(at: svgURL)
        }
        try fileManager.copyItem(at: sourceSVGURL, to: svgURL)
        try writeManifest(
            to: packageDirectory,
            id: packageID,
            displayName: displayName,
            speechAnchor: speechAnchor,
            bubblePlacement: bubblePlacement,
            animationPreset: animationPreset
        )

        return try CompanionPackageLoader.loadPackage(from: packageDirectory, fileManager: fileManager)
    }

    static func installPackageFolder(
        sourceFolderURL: URL,
        fileManager: FileManager = .default,
        packagesDirectory destinationPackagesDirectory: URL? = nil
    ) throws -> CompanionPackage {
        try validatePackageFolderHygiene(sourceFolderURL, fileManager: fileManager)
        let sourcePackage = try CompanionPackageLoader.loadPackage(from: sourceFolderURL, fileManager: fileManager)
        let packagesDirectory: URL
        if let destinationPackagesDirectory {
            packagesDirectory = destinationPackagesDirectory
        } else {
            packagesDirectory = try userPackagesDirectory(fileManager: fileManager)
        }
        let destinationURL = packagesDirectory.appendingPathComponent(sourcePackage.id, isDirectory: true)

        if sourceFolderURL.resolvingSymlinksInPath().standardizedFileURL.path == destinationURL.resolvingSymlinksInPath().standardizedFileURL.path {
            return sourcePackage
        }

        try fileManager.createDirectory(at: packagesDirectory, withIntermediateDirectories: true)
        let temporaryURL = packagesDirectory
            .appendingPathComponent(".\(sourcePackage.id)-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
            try copyDeclaredPackageFiles(
                sourcePackage: sourcePackage,
                sourceRootURL: sourceFolderURL,
                destinationRootURL: temporaryURL,
                fileManager: fileManager
            )
            try replacePackage(at: destinationURL, with: temporaryURL, fileManager: fileManager)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }

        return try CompanionPackageLoader.loadPackage(from: destinationURL, fileManager: fileManager)
    }

    private static func userPackagesDirectory(fileManager: FileManager) throws -> URL {
        let directory = try DesktopCompanionPaths.applicationSupportDirectory(fileManager: fileManager, create: true)
            .appendingPathComponent("Companions", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func writeManifest(
        to packageDirectory: URL,
        id: String,
        displayName: String,
        speechAnchor: NSPoint,
        bubblePlacement: CompanionBubblePlacement,
        animationPreset: CompanionAnimationPreset
    ) throws {
        let manifest = CompanionPackageManifest(
            schemaVersion: 1,
            id: id,
            displayName: displayName,
            companionSVG: "companion.svg",
            conversationThemesDirectory: nil,
            speechAnchor: CompanionAnchor(point: speechAnchor),
            bubblePlacement: bubblePlacement,
            animationPreset: animationPreset
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: packageDirectory.appendingPathComponent("companion.json", isDirectory: false))
    }

    private static func validatePackageFolderHygiene(_ folderURL: URL, fileManager: FileManager) throws {
        guard isDirectory(folderURL),
              try !isSymlinkOrAlias(folderURL) else {
            throw CompanionPackageError.invalidManifest
        }

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .isAliasFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw CompanionPackageError.invalidManifest
        }

        var fileCount = 0
        var totalBytes: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard try !isSymlinkOrAlias(fileURL) else {
                throw CompanionPackageError.invalidManifest
            }

            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }

            fileCount += 1
            totalBytes += UInt64(values.fileSize ?? 0)
            guard fileCount <= maxPackageFileCount,
                  totalBytes <= maxPackageTotalBytes else {
                throw CompanionPackageError.invalidManifest
            }
        }
    }

    private static func copyDeclaredPackageFiles(
        sourcePackage: CompanionPackage,
        sourceRootURL: URL,
        destinationRootURL: URL,
        fileManager: FileManager
    ) throws {
        try copyDeclaredFile(
            sourceURL: sourceRootURL.appendingPathComponent("companion.json", isDirectory: false),
            sourceRootURL: sourceRootURL,
            destinationRootURL: destinationRootURL,
            fileManager: fileManager
        )
        try copyDeclaredFile(
            sourceURL: sourcePackage.svgURL,
            sourceRootURL: sourceRootURL,
            destinationRootURL: destinationRootURL,
            fileManager: fileManager
        )

        guard let themesDirectoryURL = sourcePackage.conversationThemesDirectoryURL else {
            return
        }

        for theme in ConversationThemeLoader.themes(in: themesDirectoryURL, fileManager: fileManager) {
            try copyDeclaredFile(
                sourceURL: theme.folderURL.appendingPathComponent("theme.json", isDirectory: false),
                sourceRootURL: sourceRootURL,
                destinationRootURL: destinationRootURL,
                fileManager: fileManager
            )
            try copyDeclaredFile(
                sourceURL: theme.bubbleSVGURL,
                sourceRootURL: sourceRootURL,
                destinationRootURL: destinationRootURL,
                fileManager: fileManager
            )
        }
    }

    private static func copyDeclaredFile(
        sourceURL: URL,
        sourceRootURL: URL,
        destinationRootURL: URL,
        fileManager: FileManager
    ) throws {
        guard try !isSymlinkOrAlias(sourceURL),
              isRegularFile(sourceURL),
              let relativePath = relativePath(of: sourceURL, under: sourceRootURL) else {
            throw CompanionPackageError.invalidManifest
        }

        let destinationURL = destinationRootURL.appendingPathComponent(relativePath, isDirectory: false)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private static func replacePackage(at destinationURL: URL, with temporaryURL: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            return
        }

        let backupURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent)-backup-\(UUID().uuidString)", isDirectory: true)
        try fileManager.moveItem(at: destinationURL, to: backupURL)
        do {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            try? fileManager.removeItem(at: backupURL)
        } catch {
            try? fileManager.moveItem(at: backupURL, to: destinationURL)
            throw error
        }
    }

    private static func relativePath(of fileURL: URL, under rootURL: URL) -> String? {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else {
            return nil
        }

        return String(filePath.dropFirst(rootPath.count + 1))
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private static func isSymlinkOrAlias(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isAliasFileKey])
        return values.isSymbolicLink == true || values.isAliasFile == true
    }

    private static func uniquePackageID(baseID: String, fileManager: FileManager) -> String {
        let rootID = baseID.isEmpty ? "companion" : baseID
        let existingIDs = Set(CompanionPackageLoader.availablePackages(fileManager: fileManager).map(\.id))
        guard let packagesDirectory = CompanionPackageLoader.userPackagesDirectory else {
            return existingIDs.contains(rootID) ? "\(rootID)-2" : rootID
        }

        var candidate = rootID
        var suffix = 2
        while existingIDs.contains(candidate)
            || fileManager.fileExists(atPath: packagesDirectory.appendingPathComponent(candidate, isDirectory: true).path) {
            candidate = "\(rootID)-\(suffix)"
            suffix += 1
        }
        return candidate
    }

    private static func slug(from value: String) -> String {
        let lowercased = value.lowercased()
        var slug = ""
        var previousWasSeparator = false
        for scalar in lowercased.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                slug.append("-")
                previousWasSeparator = true
            }
        }

        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
