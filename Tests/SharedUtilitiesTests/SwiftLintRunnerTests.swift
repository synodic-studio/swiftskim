import Foundation
import Testing

@testable import SharedUtilities

struct SwiftLintRunnerTests {
    @Test("Directory lint passes every scoped file, never directories, to strict SwiftLint")
    func scopedFilesInBatches() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let excluded = root.appendingPathComponent(".build")
        try FileManager.default.createDirectory(at: excluded, withIntermediateDirectories: true)
        try write(".build/Excluded.swift", in: root)
        var expected: [String] = []
        for index in 0 ..< 65 {
            let name = "File \(index).swift"
            try write(name, in: root)
            expected.append(root.appendingPathComponent(name).path)
        }
        var checked: [String] = []
        var calls = 0
        let config = root.appendingPathComponent(".swiftlint.yml")
        let result = try SwiftLintRunner.run(target: root, config: config) { arguments in
            calls += 1
            #expect(arguments.suffix(3) == ["--config", config.path, "--strict"])
            let files = Array(arguments.dropFirst().dropLast(3))
            #expect(!files.isEmpty && files.count <= 64)
            #expect(files.allSatisfy { $0.hasSuffix(".swift") })
            checked += files
            return 0
        }
        #expect(result == 0)
        #expect(calls == 2)
        let canonicalChecked = checked.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
        let canonicalExpected = expected.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
        #expect(canonicalChecked.sorted() == canonicalExpected.sorted())
    }

    @Test("A later batch failure cannot become success")
    func laterFailurePropagates() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0 ..< 65 {
            try write("File\(index).swift", in: root)
        }
        var calls = 0
        let result = try SwiftLintRunner.run(target: root, config: root.appendingPathComponent(".swiftlint.yml")) { _ in
            calls += 1
            return calls == 2 ? 17 : 0
        }
        #expect(result == 17)
    }

    @Test("Inclusions select nested sources without pruning their ancestors")
    func inclusionsPreserveAncestors() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let sources = root.appendingPathComponent("Sources/Nested")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        try write("Selected.swift", in: sources)
        try write("Unselected.swift", in: root)
        let scope = LintScope(root: root, included: ["Sources/Nested"])
        let files = try SwiftLintRunner.files(in: root, scope: scope)
        #expect(files.map(\.lastPathComponent) == ["Selected.swift"])
    }

    @Test("Symlink directory cycles do not duplicate files or recurse indefinitely")
    func directoryCycle() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("Source.swift", in: root)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
        let files = try SwiftLintRunner.files(in: root, scope: LintScope(root: root))
        #expect(files.count == 1)
        #expect(files[0].lastPathComponent == "Source.swift")
    }

    @Test("Unreadable or missing input must fail instead of passing partial or empty coverage")
    func missingInputFails() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: (any Error).self) {
            try SwiftLintRunner.files(in: root.appendingPathComponent("Missing"), scope: LintScope(root: root))
        }
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("Broken.swift"),
            withDestinationURL: root.appendingPathComponent("Missing.swift"),
        )
        #expect(throws: (any Error).self) {
            try SwiftLintRunner.files(in: root, scope: LintScope(root: root))
        }
    }

    @Test("An empty directory must not invoke SwiftLint with implicit current-directory scope")
    func emptyInputFails() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: (any Error).self) {
            try SwiftLintRunner.run(target: root, config: root.appendingPathComponent(".swiftlint.yml")) { _ in
                Issue.record("SwiftLint must not run without explicit files")
                return 0
            }
        }
    }
}
