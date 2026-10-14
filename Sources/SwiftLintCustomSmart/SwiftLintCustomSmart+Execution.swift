import Foundation
import SharedUtilities

extension SwiftLintCustomSmart {
    /// Print the canonical rule list by delegating to the engine's --list-rules.
    func printRuleList() throws {
        let enginePath = ConfigDiscovery.customRuleEnginePath
        try RuleEngineBuildHelper.ensureBuilt(enginePath)
        let process = Process()
        process.executableURL = enginePath
        process.arguments = ["--list-rules"]
        try process.run()
        process.waitUntilExit()
    }

    /// Run the rule engine over `files`, in parallel by default (sequential with `--sequential`).
    func checkFiles(
        _ files: [URL],
        ruleEngine: URL,
        isXcode: Bool,
        config: SwiftSkimConfig,
    ) async throws -> [CheckResult] {
        if sequential {
            return try files.map {
                try CustomRulesChecker.checkFile($0, ruleEngine: ruleEngine, xcodeFormat: isXcode, onlyRules: config.onlyRules, disabledRules: config.disabledRules, thresholds: config.thresholds)
            }
        }

        // Reason: structured-concurrency TaskGroup is irreducibly closure → for →
        // addTask; the per-file task body cannot be hoisted out of that shape.
        // swiftskim:disable excessive_nesting
        return try await withThrowingTaskGroup(of: CheckResult.self) { group in
            for fileURL in files {
                group.addTask {
                    try CustomRulesChecker.checkFile(fileURL, ruleEngine: ruleEngine, xcodeFormat: isXcode, onlyRules: config.onlyRules, disabledRules: config.disabledRules, thresholds: config.thresholds)
                }
            }
            var results: [CheckResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        // swiftskim:enable excessive_nesting
    }
}
