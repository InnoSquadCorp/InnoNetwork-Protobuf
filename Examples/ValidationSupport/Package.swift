// swift-tools-version: 6.2
import PackageDescription

// Sample/test infrastructure only. It has no product-library or compiler dependencies.
let package = Package(
    name: "ProtobufValidationSupport",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [.library(name: "ProtobufValidationSupport", targets: ["ProtobufValidationSupport"])],
    targets: [.target(name: "ProtobufValidationSupport")],
    swiftLanguageModes: [.v6]
)
