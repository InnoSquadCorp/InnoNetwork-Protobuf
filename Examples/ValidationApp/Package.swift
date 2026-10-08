// swift-tools-version: 6.2
import Foundation
import PackageDescription

let core: Package.Dependency
if let path = ProcessInfo.processInfo.environment["INNONETWORK_LOCAL_PATH"] {
    core = .package(name: "InnoNetwork", path: path)
} else {
    core = .package(url: "https://github.com/InnoSquadCorp/InnoNetwork.git", exact: "6.1.1")
}
let package = Package(
    name: "NetworkValidation",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "ValidationKit", targets: ["ValidationKit"])],
    dependencies: [
        core, .package(name: "InnoNetwork-Protobuf", path: "../.."),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.38.1"),
    ],
    targets: [
        .target(
            name: "ValidationKit",
            dependencies: [
                .product(name: "InnoNetwork", package: "InnoNetwork"),
                .product(name: "InnoNetworkPersistentCache", package: "InnoNetwork"),
                .product(name: "InnoNetwork-Protobuf", package: "InnoNetwork-Protobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]),
        .executableTarget(name: "ValidationCLI", dependencies: ["ValidationKit"]),
    ], swiftLanguageModes: [.v6]
)
