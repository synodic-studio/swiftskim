import Foundation

/// Parser for SwiftLint configuration files
public enum SwiftLintConfigParser {
    /// Find SwiftLint config file in a directory
    private static func findSwiftLintConfig(in directory: URL, fileManager: FileManager) -> URL? {
        for configName in [".swiftlint.yml", ".swiftlint.yaml"] {
            let configURL = directory.appendingPathComponent(configName)
            if fileManager.fileExists(atPath: configURL.path) {
                return configURL
            }
        }
        return nil
    }

    /// Search directory tree for SwiftLint config file
    public static func searchDirectoryTreeForSwiftLintConfig() -> URL? {
        let fileManager = FileManager.default
        var currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        for _ in 0 ..< 10 {
            if let foundConfig = findSwiftLintConfig(in: currentDir, fileManager: fileManager) {
                return foundConfig
            }

            let parent = currentDir.deletingLastPathComponent()
            guard parent.path != currentDir.path else {
                break // Reached root
            }
            currentDir = parent
        }

        return nil
    }

    /// Exclusions applied when no config file can be found.
    public static let defaultExclusions = [
        ".build",
        "build",
        "Frameworks",
        "DerivedData",
    ]

    /// Read exclusion patterns from SwiftLint configuration file
    /// - Parameter configPath: Path to SwiftLint config file (optional)
    /// - Returns: Array of exclusion patterns found in the config
    public static func readExclusions(configPath: URL? = nil) -> [String] {
        // Try to find SwiftLint config
        let config: URL
        if let configPath {
            config = configPath
        } else {
            // Try to find SwiftLint config in current directory or parent directories
            if let foundConfig = searchDirectoryTreeForSwiftLintConfig() {
                return YAMLPathList.parse(section: "excluded:", from: foundConfig)
            }

            return defaultExclusions
        }

        return YAMLPathList.parse(section: "excluded:", from: config)
    }

    /// Read `included:` patterns from a SwiftLint configuration file.
    ///
    /// An empty result means the config places no inclusion filter on linting.
    /// - Parameter configPath: Path to SwiftLint config file (optional)
    public static func readInclusions(configPath: URL? = nil) -> [String] {
        guard let config = configPath ?? searchDirectoryTreeForSwiftLintConfig() else {
            return []
        }
        return YAMLPathList.parse(section: "included:", from: config)
    }
}
