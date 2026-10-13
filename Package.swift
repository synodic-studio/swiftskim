// swift-tools-version: 5.9
// Tooling version is 5.9 for SwiftPM compatibility, but the codebase uses Swift 6.1
// syntax (SE-0439 trailing commas, enforced repo-wide by swiftformat), so a Swift
// 6.1+ toolchain is required to build. swiftskim intentionally targets modern Swift.
import PackageDescription

let package = Package(
    name: "swiftskim",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "swiftformat-smart", targets: ["SwiftFormatSmart"]),
        .executable(name: "swiftlint-smart", targets: ["SwiftLintSmart"]),
        .executable(name: "swiftskim", targets: ["SwiftLintCustomSmart"]),
        // The rule engine's own CLI binary, which the `swiftskim` wrapper shells out
        // to. Built here in the root package (the engine was formerly its own nested
        // SwiftPM package; collapsing it in means SwiftSyntax compiles once).
        .executable(name: "swiftskim-engine", targets: ["swiftskim-engine"]),
        // The rule engine as an importable library: conform to `Rule` in your own
        // package and run it via `SwiftSkim.lint(externalRules:)`.
        .library(name: "SwiftSkim", targets: ["CustomRules"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        // Shared utilities library
        .target(
            name: "SharedUtilities",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),

        // SwiftFormat Smart executable
        .executableTarget(
            name: "SwiftFormatSmart",
            dependencies: [
                "SharedUtilities",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),

        // SwiftLint Smart executable
        .executableTarget(
            name: "SwiftLintSmart",
            dependencies: [
                "SharedUtilities",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),

        // SwiftLint Custom Smart executable
        .executableTarget(
            name: "SwiftLintCustomSmart",
            dependencies: [
                "SharedUtilities",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),

        // Rule engine as a library, vended from the root so it is importable via
        // .package(url:). Shares sources with the nested rule-engine package (which
        // still builds the CLI engine binary).
        .target(
            name: "CustomRules",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "CustomRules/swiftlint-swiftsyntax-integration/rule-engine/Sources/CustomRules",
        ),

        // The rule engine's CLI entrypoint (`main.swift`), sharing the CustomRules
        // target above. Path/sources mirror the former nested package's layout.
        .executableTarget(
            name: "swiftskim-engine",
            dependencies: [
                "CustomRules",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "CustomRules/swiftlint-swiftsyntax-integration/rule-engine/Sources",
            exclude: ["CustomRules"],
            sources: ["main.swift"],
        ),

        // Tests
        .testTarget(
            name: "SharedUtilitiesTests",
            dependencies: ["SharedUtilities"],
        ),
        // The rule engine's public `Rule` extensibility API tests, hoisted from the
        // former nested package so `swift test` at the root covers them too.
        .testTarget(
            name: "CustomRulesTests",
            dependencies: ["CustomRules"],
            path: "CustomRules/swiftlint-swiftsyntax-integration/rule-engine/Tests/CustomRulesTests",
        ),
    ],
)
