# InnoNetwork-Protobuf

[English](README.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

[**breaking 6.1.1 release line**](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/releases/tag/6.1.1)

<!-- section:1 -->
## Scope

Protocol Buffers over HTTP using Core’s encoded-request pipeline. This is not gRPC, streaming RPC or a schema generator. The preferred product is InnoNetwork-Protobuf; the compatibility product and Swift module are InnoNetworkProtobuf.

These seven quick starts cover the same stable release, setup, example, lifecycle and migration scope. The detailed English guide remains the shared advanced reference; translations do not imply native-speaker review.

<!-- section:2 -->
## Requirements

Swift 6.2+, Swift 6 language mode; Apple platforms only: iOS 16+, macOS 14+, tvOS 16+, watchOS 9+, visionOS 1+. Core is pinned to InnoNetwork 6.1.1 exactly.

SwiftProtobuf 1.38.1+; SwiftSyntax 604.0.x (compiler host).

<!-- section:3 -->
## Installation

Add these package dependencies, then the products to your consuming target.

```swift
.package(url: "https://github.com/InnoSquadCorp/InnoNetwork.git", exact: "6.1.1"),
.package(url: "https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git", from: "6.1.1"),
.package(url: "https://github.com/apple/swift-protobuf.git", from: "1.38.1"),
```

```swift
.product(name: "InnoNetwork", package: "InnoNetwork"),
.product(name: "InnoNetwork-Protobuf", package: "InnoNetwork-Protobuf"),
.product(name: "SwiftProtobuf", package: "swift-protobuf"),
```

<!-- section:4 -->
## Quick start

The snippets below are source-checked examples, not a new compilation or device-test result. A consuming application owns its URLs, credentials and transport policies.

Use protoc-generated Message & Sendable types; do not add fake Codable conformance. The well-known message below needs no schema-generation step. Macros are enabled by default. The detailed guide covers traits: [] and the manual EncodedRequest.protobuf factory.

```swift
import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

@ProtobufAPIDefinition(method: .post, path: "/echo", auth: .anonymous)
struct Echo {
    typealias APIResponse = Google_Protobuf_StringValue
    let body: Google_Protobuf_StringValue
    var protobufOptions: ProtobufCodecOptions {
        .init(
            encoding: .init(maximumEncodedRequestBytes: 8_192),
            decoding: .init(maximumEncodedResponseBytes: 8_192)
        )
    }
}

func echo(using client: DefaultNetworkClient) async throws -> Google_Protobuf_StringValue {
    var body = Google_Protobuf_StringValue()
    body.value = "hello"
    return try await client.request(Echo(body: body))
}
```

<!-- section:5 -->
## Ownership and failures

Execution throws NetworkError. Configuration/encoding/invalid-budget failures use .configuration(reason: .invalidPayload(...)); media and decoding failures use .decoding(stage: .responseBody, ...). Core owns retries, authentication, deadlines and cancellation. Encoding happens once per invocation, after preflight; retries reuse the bytes. Synchronous codec work is not forcibly interrupted, so cancellation is checked at Core boundaries. Request byte limits apply after encoding, not before allocation; response limits tighten Core’s collection cap.

<!-- section:6 -->
## Migration

A missing body differs from a present message with zero-byte encoding. For HTTP 204/205 use response: .empty() and EmptyResponse; Google_Protobuf_Empty is a protobuf message. Standard application/protobuf is the default, legacy media is opt-in; no implicit resend after 415. Migration from 3.0.1 removes the old protocol/client and combined ProtobufCodingOptions. Use the macro or EncodedAPIDefinition and directional ProtobufCodecOptions.

<!-- section:7 -->
## Documentation and verification

Run the listed checks from this repository. Static checks do not replace Swift builds, macro expansion, DocC or device/service acceptance. Unset INNONETWORK_LOCAL_PATH when checking the published dependency graph.

- [Technical guide (English)](docs/GUIDE.md)
- [Documentation map / historical evidence](docs/README.md)
- [Migration (English)](docs/MIGRATION_6_0.md)
- [API stability](API_STABILITY.md)
- [AI development skill](skills/README.md)
- [Release qualification record](docs/releases/6.1.1.md)
- [Roadmap](docs/ROADMAP.md)
- [MIT License](LICENSE)

```bash
bash Scripts/check_static_contracts.sh
bash Scripts/check_docs_contract_sync.sh
env -u INNONETWORK_LOCAL_PATH swift test
```
