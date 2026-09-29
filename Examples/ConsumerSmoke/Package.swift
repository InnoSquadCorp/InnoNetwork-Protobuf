// swift-tools-version: 6.2

import Foundation
import PackageDescription

let innoNetworkDependency: Package.Dependency
if let localInnoNetworkPath = ProcessInfo.processInfo.environment[
    "INNONETWORK_LOCAL_PATH"
] {
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
    name: "ConsumerSmoke",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    dependencies: [
        innoNetworkDependency,
        .package(name: "InnoNetworkProtobuf", path: "../.."),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.35.0"),
    ],
    targets: [
        .executableTarget(
            name: "ConsumerSmoke",
            dependencies: [
                .product(name: "InnoNetwork", package: "InnoNetwork"),
                .product(name: "InnoNetworkProtobuf", package: "InnoNetworkProtobuf"),
                .product(name: "InnoNetworkTestSupport", package: "InnoNetwork"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        )
    ]
)
