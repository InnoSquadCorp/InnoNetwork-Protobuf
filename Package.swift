// swift-tools-version: 6.2

import CompilerPluginSupport
import Foundation
import PackageDescription

let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6)
]

let innoNetworkDependency: Package.Dependency
if let localInnoNetworkPath = ProcessInfo.processInfo.environment[
    "INNONETWORK_LOCAL_PATH"
] {
    precondition(
        FileManager.default.fileExists(
            atPath: localInnoNetworkPath + "/Package.swift"
        ),
        "INNONETWORK_LOCAL_PATH must point to an InnoNetwork package checkout."
    )
    innoNetworkDependency = .package(
        name: "InnoNetwork",
        path: localInnoNetworkPath,
        traits: []
    )
} else {
    innoNetworkDependency = .package(
        url: "https://github.com/InnoSquadCorp/InnoNetwork.git",
        exact: "6.1.1",
        traits: []
    )
}

let package = Package(
    name: "InnoNetwork-Protobuf",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "InnoNetwork-Protobuf",
            targets: ["InnoNetworkProtobuf"]
        ),
        // Compatibility product; both names expose the same Swift module.
        .library(
            name: "InnoNetworkProtobuf",
            targets: ["InnoNetworkProtobuf"]
        ),
    ],
    traits: [
        .trait(name: "Macros", description: "Enables @ProtobufAPIDefinition declarations."),
        .default(enabledTraits: ["Macros"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", .upToNextMinor(from: "603.0.1")),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.38.1"),
        innoNetworkDependency,
    ],
    targets: [
        .macro(
            name: "InnoNetworkProtobufMacros",
            dependencies: [
                .product(name: "InnoNetworkMacroSupport", package: "InnoNetwork"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ], swiftSettings: strictSettings),
        .target(
            name: "InnoNetworkProtobuf",
            dependencies: [
                .target(name: "InnoNetworkProtobufMacros", condition: .when(traits: ["Macros"])),
                .product(name: "InnoNetwork", package: "InnoNetwork"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Sources/InnoNetworkProtobuf",
            swiftSettings: strictSettings
        ),
        .executableTarget(
            name: "InnoNetworkProtobufDocSmoke",
            dependencies: [
                .product(name: "InnoNetwork", package: "InnoNetwork"),
                "InnoNetworkProtobuf",
            ],
            path: "SmokeTests/InnoNetworkProtobufDocSmoke",
            swiftSettings: strictSettings
        ),
        .target(
            name: "MacroPlatformSmoke",
            dependencies: [
                "InnoNetworkProtobuf", .product(name: "InnoNetwork", package: "InnoNetwork"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "SmokeTests/MacroPlatformSmoke", swiftSettings: strictSettings
        ),
        .testTarget(
            name: "InnoNetworkProtobufMacroTests",
            dependencies: [
                .target(name: "InnoNetworkProtobufMacros", condition: .when(platforms: [.macOS], traits: ["Macros"])),
                .product(
                    name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax",
                    condition: .when(platforms: [.macOS], traits: ["Macros"])),
            ], swiftSettings: strictSettings
        ),
        .testTarget(
            name: "InnoNetworkProtobufTests",
            dependencies: [
                .product(name: "InnoNetwork", package: "InnoNetwork"),
                .product(name: "InnoNetworkTestSupport", package: "InnoNetwork"),
                "InnoNetworkProtobuf",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Tests/InnoNetworkProtobufTests",
            swiftSettings: strictSettings
        ),
    ]
)
