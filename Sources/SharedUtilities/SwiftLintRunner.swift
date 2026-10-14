import Foundation

/// Keeps SwiftLint out of its recursive, parallel directory walker, which can
/// exhaust a worker's stack before linting large dependency trees on macOS.
public enum SwiftLintRunner {
    private enum Constants {
        static let batchSize = 64
        static let argumentByteLimit = 32000
    }

    /// Enumerate first, then lint bounded explicit-file batches. A traversal error
    /// or failed batch fails the whole invocation; no partial run reports success.
    public static func run(
        target: URL,
        config: URL,
        execute: ([String]) throws -> Int32 = { try ProcessRunner.run("swiftlint", arguments: $0) },
    ) throws -> Int32 {
        let inputs = try files(in: target, scope: LintScope.read(configPath: config))
        guard !inputs.isEmpty else { throw CollectionError.noSwiftFiles(target.path) }
        for batch in batches(inputs) {
            let status = try execute(arguments(batch, config: config))
            guard status == 0 else { return status }
        }
        return 0
    }

    private static func batches(_ inputs: [URL]) -> [[String]] {
        var result: [[String]] = []
        var batch: [String] = []
        var bytes = 0
        for file in inputs {
            let size = file.path.utf8.count + 1
            if !batch.isEmpty, batch.count == Constants.batchSize || bytes + size > Constants.argumentByteLimit {
                result.append(batch)
                batch = []
                bytes = 0
            }
            batch.append(file.path)
            bytes += size
        }
        if !batch.isEmpty { result.append(batch) }
        return result
    }

    /// Iterative traversal preserves symlinked sources without following directory
    /// cycles. Exclusions prune traversal; inclusions filter files, not ancestors.
    public static func files(in target: URL, scope: LintScope) throws -> [URL] {
        let manager = FileManager.default
        var pending = [target]
        var visited: Set<String> = []
        var result: [URL] = []
        while let url = pending.popLast() {
            guard scope.withoutInclusions.covers(url) else { continue }
            let resolved = url.resolvingSymlinksInPath()
            let values = try resolved.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            guard values.isDirectory == true || (url.pathExtension == "swift" && scope.covers(url)) else { continue }
            guard visited.insert(resolved.standardizedFileURL.path).inserted else { continue }
            if values.isDirectory == true {
                let children = try manager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                pending.append(contentsOf: children.sorted(by: descendingPath))
                continue
            }
            guard values.isRegularFile == true else { throw CollectionError.notRegularFile(url.path) }
            result.append(url)
        }
        return result.sorted { $0.path < $1.path }
    }

    private static func arguments(_ paths: [String], config: URL) -> [String] {
        ["lint"] + paths + ["--config", config.path, "--strict"]
    }

    private static func descendingPath(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.path > rhs.path
    }

    private enum CollectionError: LocalizedError {
        case noSwiftFiles(String)
        case notRegularFile(String)

        var errorDescription: String? {
            switch self {
            case let .noSwiftFiles(path): "No Swift files in the configured lint scope at '\(path)'"
            case let .notRegularFile(path): "Cannot lint non-regular Swift input '\(path)'"
            }
        }
    }
}
