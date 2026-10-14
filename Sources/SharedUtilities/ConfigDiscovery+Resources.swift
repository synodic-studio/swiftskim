import Foundation

extension ConfigDiscovery {
    /// Filename of the rule-engine executable.
    static let engineBinaryName = "swiftskim-engine"

    /// Directory containing the currently running executable (symlinks resolved).
    private static var executableDirectory: URL {
        let path = Bundle.main.executablePath ?? CommandLine.arguments.first ?? ""
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().deletingLastPathComponent()
    }

    /// Root directory holding bundled resources (`Configs/`, the rule engine).
    ///
    /// Resolved without hardcoding any machine path, so the tool stands on its own
    /// wherever it is installed:
    /// 1. `SWIFTSKIM_HOME` if set (explicit override).
    /// 2. Walk up from the executable to the nearest ancestor containing
    ///    `Configs/shared-swiftlint.yml` (covers dev `.build/release` and installs
    ///    that place `Configs/` relative to the binary).
    /// 3. Fall back to the executable's own directory (honest error if Configs/ absent).
    static var resourcesRoot: URL {
        let fileManager = FileManager.default

        if let override = ProcessInfo.processInfo.environment["SWIFTSKIM_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        var directory = executableDirectory
        for _ in 0 ..< 8 {
            let marker = directory.appendingPathComponent("Configs/shared-swiftlint.yml")
            if fileManager.fileExists(atPath: marker.path) {
                return directory
            }
            let parent = directory.deletingLastPathComponent()
            guard parent.path != directory.path else { break }
            directory = parent
        }

        // No env override and no bundled Configs/ found by walking up from the binary:
        // fall back to the executable's own directory so a missing-config error points
        // at the real install location rather than a hardcoded personal path.
        return executableDirectory
    }

    /// Get path to custom rule engine executable.
    ///
    /// 1. `SWIFTSKIM_ENGINE` if set (explicit override).
    /// 2. Beside the running executable (installed layout).
    /// 3. The engine's own build dir under the resources root (dev layout).
    public static var customRuleEnginePath: URL {
        if let override = ProcessInfo.processInfo.environment["SWIFTSKIM_ENGINE"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }

        let sibling = executableDirectory.appendingPathComponent(engineBinaryName)
        if FileManager.default.isExecutableFile(atPath: sibling.path) {
            return sibling
        }

        return resourcesRoot
            .appendingPathComponent(".build")
            .appendingPathComponent("release")
            .appendingPathComponent(engineBinaryName)
    }
}
