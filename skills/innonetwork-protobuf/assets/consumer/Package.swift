// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ProtobufSkillConsumer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git", exact: "6.1.1"),
        .package(url: "https://github.com/InnoSquadCorp/InnoNetwork.git", exact: "6.1.1"),
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.38.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0")
    ],
    targets: [
        .target(name: "ProtobufSkillExample", dependencies: [
            .product(name: "InnoNetwork-Protobuf", package: "InnoNetwork-Protobuf"),
            .product(name: "InnoNetwork", package: "InnoNetwork"),
            .product(name: "SwiftProtobuf", package: "swift-protobuf")
        ]),
        .testTarget(name: "ProtobufSkillExampleTests", dependencies: [
            "ProtobufSkillExample",
            .product(name: "InnoNetworkTestSupport", package: "InnoNetwork"),
            .product(name: "SwiftProtobuf", package: "swift-protobuf")
        ])
    ],
    swiftLanguageModes: [.v6]
)
