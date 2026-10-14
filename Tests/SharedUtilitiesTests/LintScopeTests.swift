import Foundation
import Testing

@testable import SharedUtilities

/// A file's verdict must not depend on how the linter reached it. SwiftLint applies
/// `included:`/`excluded:` only to files it discovers itself, so without `LintScope` a
/// path named on the command line — what the post-edit hook always passes — is linted
/// with default scope and blocks on files a repo-wide run never checks.
@Suite("LintScope Tests")
struct LintScopeTests {
    func makeProject(config: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .resolvingSymlinksInPath()
        for directory in ["Sources", "Vendor", "Engine"] {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(directory),
                withIntermediateDirectories: true,
            )
        }
        try config.write(
            to: root.appendingPathComponent(".swiftlint.yml"),
            atomically: true,
            encoding: .utf8,
        )
        return root
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static let scopedConfig = """
    included:
      - Sources
    excluded:
      - Vendor  # inline comments must not become part of the pattern
      - "**/Generated"
    """

    // MARK: - Inclusion

    @Test("A file under an included: path is covered")
    func includedFileIsCovered() throws {
        let root = try makeProject(config: Self.scopedConfig)
        defer { cleanup(root) }

        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml"))
        #expect(scope.included == ["Sources"])
        #expect(scope.covers(root.appendingPathComponent("Sources/Deep/Nested/File.swift")))
    }

    @Test("A file outside every included: path is not covered")
    func fileOutsideInclusionsIsNotCovered() throws {
        let root = try makeProject(config: Self.scopedConfig)
        defer { cleanup(root) }

        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml"))
        #expect(!scope.covers(root.appendingPathComponent("Engine/Rules.swift")))
    }

    @Test("An empty included: list places no inclusion filter")
    func noInclusionsCoversEverything() throws {
        let root = try makeProject(config: "excluded:\n  - Vendor\n")
        defer { cleanup(root) }

        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml"))
        #expect(scope.included.isEmpty)
        #expect(scope.covers(root.appendingPathComponent("Engine/Rules.swift")))
    }

    // MARK: - Exclusion

    @Test("An excluded: path is not covered, even inside an included: one")
    func exclusionBeatsInclusion() throws {
        let root = try makeProject(config: "included:\n  - Sources\nexcluded:\n  - Sources/Generated\n")
        defer { cleanup(root) }

        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml"))
        #expect(!scope.covers(root.appendingPathComponent("Sources/Generated/API.swift")))
        #expect(scope.covers(root.appendingPathComponent("Sources/App.swift")))
    }

    @Test("An inline YAML comment is stripped from an exclusion pattern")
    func inlineCommentStrippedFromPattern() throws {
        let root = try makeProject(config: Self.scopedConfig)
        defer { cleanup(root) }

        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml"))
        #expect(scope.excluded.contains("Vendor"))
        #expect(!scope.covers(root.appendingPathComponent("Vendor/Thing.swift")))
    }

    @Test("A **/ wildcard exclusion matches at any depth")
    func wildcardExclusionMatches() throws {
        let root = try makeProject(config: Self.scopedConfig)
        defer { cleanup(root) }

        let scope = LintScope.read(configPath: root.appendingPathComponent(".swiftlint.yml"))
        #expect(!scope.covers(root.appendingPathComponent("Sources/Generated/API.swift")))
    }
}
