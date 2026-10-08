# Macro-first HTTP integration — 6.1.1

Link the `InnoNetwork-Protobuf`, `InnoNetwork`, and `SwiftProtobuf` products to
the application target. Import `InnoNetworkProtobuf` (without the hyphen),
`InnoNetwork`, and `SwiftProtobuf`. The compatibility product `InnoNetworkProtobuf`
exports the same module; it does not restore removed 3.x APIs.

For a named request, use the adapter macro:

```swift
@ProtobufAPIDefinition(method: .post, path: "/echo/{id}", auth: .anonymous)
struct Echo {
    typealias APIResponse = Google_Protobuf_StringValue
    let id: Int
    let body: Google_Protobuf_StringValue
    var protobufOptions: ProtobufCodecOptions {
        .init(encoding: .init(maximumEncodedRequestBytes: 8_192),
              decoding: .init(maximumEncodedResponseBytes: 8_192))
    }
}
```

The budgets above are illustrative. Choose application-specific values. With an
application-owned configured client, `try await client.request(Echo(...))`
returns the message and throws `NetworkError`. `OperationNetworkClient(client:
client).start(endpoint)` provides the Core operation lifecycle instead.

Store body, query and path inputs on a struct. `body` is a generated message or
optional message; `query` is ordinary `Encodable & Sendable` HTTP query input.
For GET, omit body. Query encoding appends after `requestOptions.queryItems`,
preserving duplicates/order; `queryEncoder` optionally controls array encoding.
`protobufOptions`, `requestOptions`, and `queryEncoder` can be instance stored or
computed policy properties. The compiler checks message/query conformances.

The macro generates `EncodedAPIDefinition` witnesses, including
`makeEncodedRequest()`. Do not manually declare colliding generated witnesses.
Computed body/query, optional path inputs, unused stored inputs and member-level
`#if` are rejected. Put conditional compilation around the whole endpoint, or use
a complete manual `EncodedAPIDefinition` when that contract is needed. Declaring
`@APIDefinition` for a protobuf body would select Core's JSON model instead.

For a concrete manual request or deliberate macro opt-out:

```swift
let request = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
    method: .post, path: "/echo", auth: .anonymous, body: generatedMessage,
    codec: ProtobufCodecOptions())
```

Do not eagerly serialize into Data unless the task actually needs a custom codec.
The factory snapshots value input and defers serialization until execution.
Binary-only mocks may conform to Core `EncodedRequestClient`; do not implement
the removed `ProtobufAPIDefinition` protocol.

Use `InnoNetworkTestSupport` in test targets. Its public overload accepts
`MockURLSession`; ordinary consumers cannot inject a generic package-only
`URLSessionProtocol`. Seed protobuf responses using `serializedData()` and an
explicit `Content-Type: application/protobuf`. Inspect captured bytes/headers and
decoded values. Do not use `@testable import InnoNetwork` or compiler-host modules.

Immutable sources: [macro declaration](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/Sources/InnoNetworkProtobuf/ProtobufAPIDefinition%2BMacro.swift),
[macro expansion](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/Sources/InnoNetworkProtobufMacros/ProtobufAPIDefinitionMacro.swift),
[mixed external consumer](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/Examples/ConsumerSmoke/Sources/ConsumerSmoke/main.swift).
