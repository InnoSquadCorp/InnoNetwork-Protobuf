# InnoNetworkProtobuf

`InnoNetworkProtobuf` is the Protocol Buffers adapter package for [`InnoNetwork`](https://github.com/InnoSquadCorp/InnoNetwork).

It keeps protobuf request serialization and response decoding out of the core package so clients that only use JSON, form, download, or websocket features do not need to resolve `swift-protobuf`.

> InnoNetwork `6.0.0` is published. This adapter's 6.0 development line targets
> that release; InnoNetworkProtobuf `6.0.0` is not yet published.
> The latest published adapter remains `3.0.1`, paired with InnoNetwork `3.0.1`.

## Coordinated Installation (after adapter publication)

```swift
dependencies: [
    .package(
        url: "https://github.com/InnoSquadCorp/InnoNetwork.git",
        .upToNextMajor(from: "6.0.0")
    ),
    .package(
        url: "https://github.com/InnoSquadCorp/InnoNetworkProtobuf.git",
        .upToNextMajor(from: "6.0.0")
    ),
]
```

The declarations above require **both** published tags. Until the adapter is
published, do not combine InnoNetworkProtobuf `3.0.1` with InnoNetwork `6.0.0`.
Maintainers can validate this checkout against the published core without any
local core override:

```bash
env -u INNONETWORK_LOCAL_PATH swift test
env -u INNONETWORK_LOCAL_PATH swift run InnoNetworkProtobufDocSmoke
env -u INNONETWORK_LOCAL_PATH swift run --package-path Examples/ConsumerSmoke ConsumerSmoke
```

The consumer fixture intentionally uses the local adapter and remote core. It
executes a protobuf request/response through an in-memory transport; it is not
proof that both packages are published or that a production service works.
The optional local core override remains available for coordinated development:

```bash
INNONETWORK_LOCAL_PATH=/path/to/InnoNetwork swift test
```

Add both products to the consuming target:

```swift
.product(name: "InnoNetwork", package: "InnoNetwork"),
.product(name: "InnoNetworkProtobuf", package: "InnoNetworkProtobuf"),
```

## Quick Start

This self-contained example uses SwiftProtobuf's generated well-known messages.
Replace them with your own `protoc`-generated message types in an application.
If your target imports `SwiftProtobuf`, declare its package and product directly
(the adapter supports `swift-protobuf` from `1.35.0`).

```swift
import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

struct GetValue: ProtobufAPIDefinition {
    typealias Parameter = Google_Protobuf_Int32Value
    typealias APIResponse = Google_Protobuf_StringValue

    var method: HTTPMethod { .post }
    var path: String { "/values.protobuf" }
    var sessionAuthentication: SessionAuthentication { .anonymous }
    let parameters: Google_Protobuf_Int32Value?
}

var input = Google_Protobuf_Int32Value()
input.value = 42
let client = DefaultNetworkClient(
    configuration: .safeDefaults(baseURL: URL(string: "https://api.example.com")!)
)

let response = try await client.protobufRequest(GetValue(parameters: input))
print(response.value)
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
- Released `3.0.1` remains paired with `InnoNetwork` `3.0.1`. The 6.0 adapter
  requires InnoNetwork `6.0.0..<7.0.0`, and its tag must be published only
  after the InnoNetwork 6.0.0 tag resolves remotely.
- Every protobuf endpoint declares `sessionAuthentication` explicitly so a
  migration cannot silently change whether refresh-token policy runs.
- `.required` fails before transport without a token policy; `.anonymous`
  bypasses the policy. Authentication replay preserves the binary request body.
- Errors remain InnoNetwork's typed `NetworkError` values, including
  `.decoding(stage: .responseBody, underlying:response:)` and `.cancelled`.
- Unsafe POST timeout retries require an `Idempotency-Key` with the default
  retry safety policy. Do not opt into method-agnostic retries without owning
  duplicate-write protection.
- This compatibility update keeps the public `protobufRequest` surface. It does
  not add protobuf-specific operation handles, gRPC, or new codec policies.

## Stability

- Stable public API: [API_STABILITY.md](API_STABILITY.md)
- Release rules: [docs/RELEASE_POLICY.md](docs/RELEASE_POLICY.md)
- Migration notes: [docs/MIGRATION_POLICY.md](docs/MIGRATION_POLICY.md)
- Draft 6.0 release notes: [docs/releases/6.0.0.md](docs/releases/6.0.0.md)
- Local 6.0 compatibility evidence: [docs/COMPATIBILITY_6_0.md](docs/COMPATIBILITY_6_0.md)

## Support

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
- Support model: [SUPPORT.md](SUPPORT.md)
