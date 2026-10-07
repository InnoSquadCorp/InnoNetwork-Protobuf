# InnoNetworkProtobuf

`InnoNetworkProtobuf` is the Protocol Buffers adapter package for [`InnoNetwork`](https://github.com/InnoSquadCorp/InnoNetwork).

It keeps protobuf request serialization and response decoding out of the core package so clients that only use JSON, form, download, or websocket features do not need to resolve `swift-protobuf`.

> `main` is currently aligned with the unreleased InnoNetwork 5.0 development
> branch. No 5.0 tag has been published; use the 3.0.1 tag pair below for the
> latest released line.

## Installation

```swift
dependencies: [
    .package(
        url: "https://github.com/InnoSquadCorp/InnoNetwork.git",
        exact: "3.0.1"
    ),
    .package(url: "https://github.com/InnoSquadCorp/InnoNetworkProtobuf.git", exact: "3.0.1"),
]
```

Add both products to the consuming target:

```swift
.product(name: "InnoNetwork", package: "InnoNetwork"),
.product(name: "InnoNetworkProtobuf", package: "InnoNetworkProtobuf"),
```

## Quick Start

```swift
import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

struct GetUserRequest: SwiftProtobuf.Message, Sendable {
    var userID: Int32 = 0
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    static let protoMessageName = "GetUserRequest"

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt32Field(value: &userID)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if userID != 0 {
            try visitor.visitSingularInt32Field(value: userID, fieldNumber: 1)
        }
        try unknownFields.traverse(visitor: &visitor)
    }
}

struct GetUserResponse: SwiftProtobuf.Message, Sendable {
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    static let protoMessageName = "GetUserResponse"

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while try decoder.nextFieldNumber() != nil {}
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }
}

struct GetUser: ProtobufAPIDefinition {
    typealias Parameter = GetUserRequest
    typealias APIResponse = GetUserResponse

    var method: HTTPMethod { .post }
    var path: String { "/users.protobuf" }
    var sessionAuthentication: SessionAuthentication { .anonymous }
    let parameters: GetUserRequest?
}

let client = DefaultNetworkClient(
    configuration: .safeDefaults(baseURL: URL(string: "https://api.example.com")!)
)

let response = try await client.protobufRequest(
    GetUser(parameters: GetUserRequest(userID: 1))
)
print(response)
```

## Public Surface

- `ProtobufAPIDefinition`
- `ProtobufNetworkClient`
- `ProtobufEmptyResponse`
- `HTTPEmptyResponseMessage`
- `AnyResponseDecoder.protobuf()`
- `AnyResponseDecoder.protobufEmptyCapable()`

`DefaultNetworkClient` still comes from the core `InnoNetwork` package. This package only adds protobuf request execution and decoding on top of it.

## Notes

- GET requests with protobuf parameters are rejected. Binary protobuf payloads are body-only.
- For `204 No Content` or empty responses, use `ProtobufEmptyResponse` or a custom type conforming to `HTTPEmptyResponseMessage`.
- Released `3.0.1` remains paired with `InnoNetwork` `3.0.1`. The development
  branch follows InnoNetwork `main` until matching 5.0 release tags are cut.
- Every protobuf endpoint declares `sessionAuthentication` explicitly so a
  migration cannot silently change whether refresh-token policy runs.

## Stability

- Stable public API: [API_STABILITY.md](API_STABILITY.md)
- Release rules: [docs/RELEASE_POLICY.md](docs/RELEASE_POLICY.md)
- Migration notes: [docs/MIGRATION_POLICY.md](docs/MIGRATION_POLICY.md)

## Support

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
- Support model: [SUPPORT.md](SUPPORT.md)

## Sponsorship

Support InnoNetwork-Protobuf development through [GitHub Sponsors](https://github.com/sponsors/InnoSquadCorp) or [Patreon](https://www.patreon.com/15188938/join).
