import Foundation

extension CustomRulesChecker {
    /// Parse violations from rule engine output
    /// Expects formats:
    /// - "⚠️  [rule_id] Line X has message"
    /// - "⚠️  [rule_id] message" (for file-level violations)
    static func parseViolations(from output: String) -> [Violation] {
        output.components(separatedBy: .newlines)
            .filter { $0.contains("⚠️") }
            .compactMap { line in
                parseViolation(from: line)
            }
    }

    /// Parse a single violation line
    private static func parseViolation(from line: String) -> Violation? {
        guard let ruleIDRange = line.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) else {
            return nil
        }

        let ruleID = String(line[ruleIDRange].dropFirst().dropLast())

        // Try to extract line number and message
        if let (lineNumber, message) = extractLineAndMessage(from: line) {
            return Violation(line: lineNumber, ruleID: ruleID, message: message)
        }

        // File-level violation (no line number)
        if let messageStart = ruleIDRange.upperBound.samePosition(in: line) {
            let message = String(line[messageStart...]).trimmingCharacters(in: .whitespaces)
            return Violation(line: 0, ruleID: ruleID, message: message)
        }

        return nil
    }

    /// Extract line number and message from violation text
    private static func extractLineAndMessage(from line: String) -> (Int, String)? {
        // Match two formats:
        // 1. "Line N: message" (new format from view_structure_order)
        // 2. "Line N message" (existing format from other rules)
        guard let lineNumberRange = line.range(of: #"Line (\d+):?"#, options: .regularExpression) else {
            return nil
        }

        let lineNumberMatch = line[lineNumberRange]
        guard let lineNumberStr = lineNumberMatch.split(separator: " ").last,
              let lineNumber = Int(lineNumberStr.replacingOccurrences(of: ":", with: ""))
        else {
            return nil
        }

        // Find where the message starts (after "Line N:" or "Line N ")
        guard let messageStart = line.range(of: #"Line \d+:? "#, options: .regularExpression)?.upperBound else {
            return nil
        }

        let message = String(line[messageStart...])
        return (lineNumber, message)
    }
}
