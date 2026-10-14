import Foundation
import Testing

@testable import SharedUtilities

extension LintScopeTests {
    // MARK: - Boundaries

    @Test("A file outside the config's directory is covered, not silently skipped")
    func fileOutsideConfigRootIsCovered() throws {
        let root = try makeProject(config: Self.scopedConfig)
        defer { cleanup(root) }

        let elsewhere = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)/Scratch.swift")
        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml"))
        #expect(scope.covers(elsewhere))
    }

    @Test("withoutInclusions drops the inclusion filter and keeps exclusions")
    func withoutInclusionsKeepsExclusions() throws {
        let root = try makeProject(config: Self.scopedConfig)
        defer { cleanup(root) }

        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml")).withoutInclusions
        #expect(scope.covers(root.appendingPathComponent("Engine/Rules.swift")))
        #expect(!scope.covers(root.appendingPathComponent("Vendor/Thing.swift")))
    }

    // MARK: - Collector parity

    @Test("A named file and a directory scan agree on the same file")
    func namedFileMatchesDirectoryScan() throws {
        let root = try makeProject(config: Self.scopedConfig)
        defer { cleanup(root) }

        let inScope = root.appendingPathComponent("Sources/App.swift")
        let outOfScope = root.appendingPathComponent("Engine/Rules.swift")
        for file in [inScope, outOfScope] {
            try "struct S {}\n".write(to: file, atomically: true, encoding: .utf8)
        }

        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml"))
        let discovered = SwiftFileCollector.collect(from: root, scope: scope)
        #expect(discovered.map(\.lastPathComponent) == ["App.swift"])
        #expect(SwiftFileCollector.collect(from: inScope, scope: scope) == [inScope])
        #expect(SwiftFileCollector.collect(from: outOfScope, scope: scope).isEmpty)
    }

    @Test("This repo's own engine sources are outside its .swiftlint.yml scope")
    func repoEngineSourcesAreOutOfScope() throws {
        let root = TestSupport.repoRoot
        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml"))
        let engineFile = root.appendingPathComponent(
            "CustomRules/swiftlint-swiftsyntax-integration/rule-engine/Sources/CustomRules/ViewBodyRules.swift",
        )

        #expect(FileManager.default.fileExists(atPath: engineFile.path))
        #expect(!scope.covers(engineFile))
        #expect(scope.covers(root.appendingPathComponent("Sources/SharedUtilities/LintScope.swift")))
        #expect(scope.covers(root.appendingPathComponent("Tests/SharedUtilitiesTests/LintScopeTests.swift")))
    }
}
