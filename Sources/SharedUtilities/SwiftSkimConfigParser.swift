import Foundation

/// Parser + discovery for `.swiftskim.yml`. Hand-rolled line parsing (block style only),
/// consistent with `SwiftLintConfigParser` and the zero-dependency stance.
public enum SwiftSkimConfigParser {
    static let configNames = [".swiftskim.yml", ".swiftskim.yaml"]

    /// Load the effective config: `.swiftskim.yml` if one is found walking up from the
    /// working directory, otherwise thresholds from the legacy `.swiftlint.yml` block.
    public static func load() -> SwiftSkimConfig {
        if let config = findConfig() {
            return parse(from: config)
        }
        return SwiftSkimConfig(thresholds: SwiftLintConfigParser.readThresholds())
    }

    /// Walk up from the current directory looking for a `.swiftskim.yml`/`.yaml`.
    private static func findConfig() -> URL? {
        let fileManager = FileManager.default
        var directory = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        for _ in 0 ..< 10 {
            let found = configNames
                .map { directory.appendingPathComponent($0) }
                .first { fileManager.fileExists(atPath: $0.path) }
            if let found { return found }

            let parent = directory.deletingLastPathComponent()
            guard parent.path != directory.path else { break }
            directory = parent
        }
        return nil
    }

    /// Parse a `.swiftskim.yml`. Recognizes two list keys (`only_rules`, `disabled_rules`)
    /// and two scalar int keys (`skimmable_body_max_lines`, `excessive_nesting_max_depth`).
    static func parse(from config: URL) -> SwiftSkimConfig {
        guard let contents = try? String(contentsOf: config, encoding: .utf8) else {
            return SwiftSkimConfig()
        }

        var result = SwiftSkimConfig()
        var only: [String] = []
        var disabled: [String] = []
        var activeList: String? // "only_rules" or "disabled_rules" while inside one

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // A `- item` while inside a list section belongs to that list.
            if let activeList, trimmed.hasPrefix("- ") {
                appendListItem(trimmed, list: activeList, only: &only, disabled: &disabled)
                continue
            }

            // Any other line is a key line and ends the current list section.
            activeList = nil
            if trimmed.hasPrefix("only_rules:") { activeList = "only_rules"
                continue
            }
            if trimmed.hasPrefix("disabled_rules:") { activeList = "disabled_rules"
                continue
            }
            applyScalar(trimmed, to: &result.thresholds)
        }

        result.onlyRules = only.isEmpty ? nil : only
        result.disabledRules = disabled.isEmpty ? nil : disabled
        return result
    }

    /// Append a `- item` line to whichever rule list is active.
    private static func appendListItem(
        _ trimmed: String,
        list: String,
        only: inout [String],
        disabled: inout [String],
    ) {
        let item = String(trimmed.dropFirst(2))
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
        guard !item.isEmpty else { return }
        if list == "only_rules" { only.append(item) } else { disabled.append(item) }
    }

    /// Apply one `key: intValue` threshold line.
    private static func applyScalar(_ trimmed: String, to thresholds: inout RuleThresholds) {
        let parts = trimmed.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let value = Int(parts[1]) else { return }
        switch parts[0] {
        case "skimmable_body_max_lines": thresholds.skimmableBodyMaxLines = value
        case "excessive_nesting_max_depth": thresholds.excessiveNestingMaxDepth = value
        default: break
        }
    }
}
