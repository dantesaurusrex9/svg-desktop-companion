import AppKit

enum PositionStore {
    private static let xKey = "desktopCompanion.position.x"
    private static let yKey = "desktopCompanion.position.y"

    static func load() -> NSPoint? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: xKey) != nil,
              defaults.object(forKey: yKey) != nil else {
            return nil
        }

        return NSPoint(
            x: defaults.double(forKey: xKey),
            y: defaults.double(forKey: yKey)
        )
    }

    static func save(_ origin: NSPoint) {
        let defaults = UserDefaults.standard
        defaults.set(origin.x, forKey: xKey)
        defaults.set(origin.y, forKey: yKey)
    }
}
