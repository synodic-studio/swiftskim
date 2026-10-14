import Foundation

/// swiftskim's own project configuration, read from a dedicated `.swiftskim.yml`.
///
/// swiftskim's rules roll up **separately** from SwiftLint and SwiftFormat. Those two
/// each own their file (`.swiftlint.yml`, `.swiftformat`); this file owns swiftskim's
/// custom SwiftUI/Swift AST rules — which of them run, and their two thresholds. File
/// *selection* is deliberately not duplicated here: exclusions stay shared from
/// `.swiftlint.yml`'s `excluded:`, so `.swiftskim.yml` layers swiftskim's rules on top
/// of the file set you already lint.
///
/// Back-compat: with no `.swiftskim.yml`, thresholds fall back to the legacy
/// `swiftskim:` block in `.swiftlint.yml` (rule selection has no legacy equivalent).
public struct SwiftSkimConfig: Sendable, Equatable {
    public var thresholds: RuleThresholds
    /// Allowlist: if non-nil, only these rules run.
    public var onlyRules: [String]?
    /// Denylist: these rules never run.
    public var disabledRules: [String]?

    public init(
        thresholds: RuleThresholds = RuleThresholds(),
        onlyRules: [String]? = nil,
        disabledRules: [String]? = nil,
    ) {
        self.thresholds = thresholds
        self.onlyRules = onlyRules
        self.disabledRules = disabledRules
    }
}
