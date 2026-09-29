// swift-tools-version: 6.2

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
        path: localInnoNetworkPath
    )
} else {
    innoNetworkDependency = .package(
        url: "https://github.com/InnoSquadCorp/InnoNetwork.git",
        .upToNextMajor(from: "6.0.0")
    )
}

let package = Package(
    name: "InnoNetwork-Protobuf",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
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
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.35.0"),
        innoNetworkDependency,
    ],
    targets: [
        .target(
            name: "InnoNetworkProtobuf",
            dependencies: [
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
