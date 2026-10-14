import Foundation

/// Utility for running custom rules checks on files
public enum CustomRulesChecker {
    /// Check a single file for violations
    /// - Parameters:
    ///   - fileURL: URL of file to check
    ///   - ruleEngine: URL of rule engine executable
    ///   - xcodeFormat: Whether to output in Xcode-compatible format
    ///   - onlyRules: Optional list of rule IDs to run (nil = all rules)
    ///   - disabledRules: Optional list of rule IDs to skip (a denylist)
    ///   - thresholds: Configurable rule thresholds (empty = engine defaults)
    /// - Returns: CheckResult with violation status and relative path
    public static func checkFile(
        _ fileURL: URL,
        ruleEngine: URL,
        xcodeFormat: Bool = false,
        onlyRules: [String]? = nil,
        disabledRules: [String]? = nil,
        thresholds: RuleThresholds = RuleThresholds(),
    ) throws -> CheckResult {
        let process = Process()
        process.executableURL = ruleEngine
        var arguments = [fileURL.path]
        if let onlyRules, !onlyRules.isEmpty {
            arguments.append("--only-rules")
            arguments.append(onlyRules.joined(separator: ","))
        }
        if let disabledRules, !disabledRules.isEmpty {
            arguments.append("--disable-rules")
            arguments.append(disabledRules.joined(separator: ","))
        }
        arguments.append(contentsOf: thresholds.engineArguments)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let relativePath = fileURL.path.replacingOccurrences(of: FileManager.default.currentDirectoryPath + "/", with: "")
        let absolutePath = fileURL.path

        // Parse violations from output
        let violations = parseViolations(from: output)

        // Print violations in appropriate format
        if !violations.isEmpty {
            if xcodeFormat {
                printXcodeViolations(violations: violations, absolutePath: absolutePath)
            } else {
                printTerminalViolations(violations: violations, relativePath: relativePath)
            }
        }

        return CheckResult(hasViolations: !violations.isEmpty, relativePath: relativePath, violations: violations)
    }

    /// Print violations in Xcode-compatible format
    /// Format: /absolute/path/file.swift:42: warning: [rule_id] message
    /// File-level violations use line 1 for Xcode clickability
    private static func printXcodeViolations(violations: [Violation], absolutePath: String) {
        for violation in violations {
            let line = violation.line == 0 ? 1 : violation.line
            print("\(absolutePath):\(line): warning: [\(violation.ruleID)] \(violation.message)")
        }
    }

    /// Print violations in terminal format with colors
    private static func printTerminalViolations(violations: [Violation], relativePath: String) {
        print("\(ANSIColor.red.rawValue)\(relativePath):\(ANSIColor.reset.rawValue)")

        for violation in violations {
            if violation.line == 0 {
                // File-level violation
                print("    • [\(violation.ruleID)] \(violation.message)")
            } else {
                print("    • [\(violation.ruleID)] Line \(violation.line): \(violation.message)")
            }
        }
        print("")
    }

    /// Print summary of linting results
    public static func printSummary(totalFiles: Int, violations: Int) {
        print("")
        if violations == 0 {
            Console.success("✓ \(totalFiles) files checked, no violations")
        } else {
            Console.warning("\(violations)/\(totalFiles) files with violations")
        }
    }
}
