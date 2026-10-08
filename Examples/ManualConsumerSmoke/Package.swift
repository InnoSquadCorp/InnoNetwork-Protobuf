// swift-tools-version: 6.2
import Foundation
import PackageDescription

let core: Package.Dependency
if let path = ProcessInfo.processInfo.environment["INNONETWORK_LOCAL_PATH"] {
    core = .package(name: "InnoNetwork", path: path, traits: [])
} else {
    core = .package(url: "https://github.com/InnoSquadCorp/InnoNetwork.git", exact: "6.1.1", traits: [])
}
let package = Package(
    name: "ManualConsumerSmoke", platforms: [.macOS(.v14)],
    dependencies: [
        core, .package(name: "InnoNetwork-Protobuf", path: "../..", traits: []),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.38.1"),
    ],
    targets: [
        .executableTarget(
            name: "ManualConsumerSmoke",
            dependencies: [
                .product(name: "InnoNetwork", package: "InnoNetwork"),
                .product(name: "InnoNetwork-Protobuf", package: "InnoNetwork-Protobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ])
    ])
