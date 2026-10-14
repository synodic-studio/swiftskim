import Foundation

/// Configurable custom-rule thresholds, read from a `swiftskim:` block in
/// `.swiftlint.yml`. A `nil` field means "use the engine default".
public struct RuleThresholds: Sendable, Equatable {
    public var skimmableBodyMaxLines: Int?
    public var excessiveNestingMaxDepth: Int?

    public init(skimmableBodyMaxLines: Int? = nil, excessiveNestingMaxDepth: Int? = nil) {
        self.skimmableBodyMaxLines = skimmableBodyMaxLines
        self.excessiveNestingMaxDepth = excessiveNestingMaxDepth
    }

    /// Flags to pass to the rule engine; empty when nothing is overridden.
    public var engineArguments: [String] {
        var args: [String] = []
        if let skimmableBodyMaxLines {
            args += ["--skimmable-body-max", String(skimmableBodyMaxLines)]
        }
        if let excessiveNestingMaxDepth {
            args += ["--nesting-max-depth", String(excessiveNestingMaxDepth)]
        }
        return args
    }
}
