import Foundation
import Testing

@testable import SharedUtilities

extension SwiftLintRunnerTests {
    @Test("A non-Swift symlink cannot hide its in-scope Swift target")
    func nonSwiftAliasPreservesSource() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("Z.swift", in: root)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("A.alias"),
            withDestinationURL: root.appendingPathComponent("Z.swift"),
        )
        let files = try SwiftLintRunner.files(in: root, scope: LintScope(root: root))
        #expect(files.map(\.lastPathComponent) == ["Z.swift"])
    }

    @Test("Long paths are bounded by argument bytes, not only the file count")
    func boundedArgumentBytes() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = String(repeating: "a", count: 200)
        let nested = root.appendingPathComponent("\(folder)/\(folder)/\(folder)")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        for index in 0 ..< 40 {
            try write("\(index)\(String(repeating: "s", count: 180)).swift", in: nested)
        }
        var calls = 0
        var checked = 0
        let result = try SwiftLintRunner.run(target: root, config: root.appendingPathComponent(".swiftlint.yml")) { arguments in
            let paths = arguments.dropFirst().dropLast(3)
            #expect(paths.reduce(0) { $0 + $1.utf8.count + 1 } <= 32000)
            calls += 1
            checked += paths.count
            return 0
        }
        #expect(result == 0)
        #expect(calls == 2)
        #expect(checked == 40)
    }

    @Test("A failed first batch stops the invocation without running later batches")
    func firstFailureStops() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0 ..< 65 {
            try write("File\(index).swift", in: root)
        }
        var calls = 0
        let result = try SwiftLintRunner.run(target: root, config: root.appendingPathComponent(".swiftlint.yml")) { _ in
            calls += 1
            return 4
        }
        #expect(result == 4)
        #expect(calls == 1)
    }

    @Test("A subprocess launch error cannot become lint success")
    func launchFailurePropagates() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("Source.swift", in: root)
        #expect(throws: (any Error).self) {
            try SwiftLintRunner.run(target: root, config: root.appendingPathComponent(".swiftlint.yml")) { _ in
                throw NSError(domain: "SwiftLintLaunchTest", code: 1)
            }
        }
    }
}
