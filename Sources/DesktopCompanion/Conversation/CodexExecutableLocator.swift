import Foundation

struct CodexExecutableLocator {
    var environment: [String: String] = ProcessInfo.processInfo.environment
    var isExecutableFile: (String) -> Bool = CodexExecutableLocator.defaultIsExecutableFile

    func locate() -> String? {
        Self.candidatePaths(environment: environment).first(where: isExecutableFile)
    }

    static func candidatePaths(environment: [String: String]) -> [String] {
        var paths: [String] = []

        if let home = environment["HOME"], !home.isEmpty {
            paths.append("\(home)/.local/bin/codex")
        }

        paths.append("/opt/homebrew/bin/codex")
        paths.append("/usr/local/bin/codex")

        if let path = environment["PATH"] {
            paths.append(contentsOf: path
                .split(separator: ":")
                .map { "\($0)/codex" })
        }

        return paths.reduce(into: []) { uniquePaths, path in
            if !uniquePaths.contains(path) {
                uniquePaths.append(path)
            }
        }
    }

    private static func defaultIsExecutableFile(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }
}
