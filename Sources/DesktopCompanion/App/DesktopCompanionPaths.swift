import Foundation

enum DesktopCompanionPaths {
    static let supportDirectoryInfoKey = "DesktopCompanionSupportDirectory"
    static let defaultAppSupportFolderName = "DesktopCompanion"

    static var appSupportFolderName: String {
        Bundle.main.object(forInfoDictionaryKey: supportDirectoryInfoKey) as? String ?? defaultAppSupportFolderName
    }

    static func applicationSupportDirectory(
        fileManager: FileManager = .default,
        create: Bool = false
    ) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        )
        let directory = appSupport.appendingPathComponent(appSupportFolderName, isDirectory: true)

        if create {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    static var applicationSupportDirectoryURL: URL? {
        try? applicationSupportDirectory(create: false)
    }
}
