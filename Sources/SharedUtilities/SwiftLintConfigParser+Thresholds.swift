import Foundation

extension SwiftLintConfigParser {
    /// Read custom-rule thresholds from a `swiftskim:` block in the config.
    /// - Parameter configPath: Explicit config path, or nil to discover one.
    /// - Returns: Thresholds with only the overridden fields set.
    public static func readThresholds(configPath: URL? = nil) -> RuleThresholds {
        let config: URL
        if let configPath {
            config = configPath
        } else if let found = searchDirectoryTreeForSwiftLintConfig() {
            config = found
        } else {
            return RuleThresholds()
        }
        return parseThresholds(from: config)
    }

    /// Parse the `swiftskim:` threshold block from a config file.
    private static func parseThresholds(from config: URL) -> RuleThresholds {
        guard let contents = try? String(contentsOf: config, encoding: .utf8) else {
            return RuleThresholds()
        }

        var thresholds = RuleThresholds()
        var inSection = false

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("swiftskim:") {
                inSection = true
                continue
            }
            guard inSection else { continue }

            // A new non-indented key ends the block.
            if !line.isEmpty, !line.first!.isWhitespace, trimmed.contains(":") {
                break
            }
            applyThresholdLine(trimmed, to: &thresholds)
        }

        return thresholds
    }

    /// Apply one `key: value` line from the `swiftskim:` block.
    private static func applyThresholdLine(_ trimmed: String, to thresholds: inout RuleThresholds) {
        let parts = trimmed.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let value = Int(parts[1]) else { return }

        switch parts[0] {
        case "skimmable_body_max_lines": thresholds.skimmableBodyMaxLines = value
        case "excessive_nesting_max_depth": thresholds.excessiveNestingMaxDepth = value
        default: break
        }
    }
}
