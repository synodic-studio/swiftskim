import Foundation

extension SwiftLintRunnerTests {
    func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "excluded:\n  - .build\n".write(to: root.appendingPathComponent(".swiftlint.yml"), atomically: true, encoding: .utf8)
        return root
    }

    func write(_ name: String, in root: URL) throws {
        try "let value = 1\n".write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
}
