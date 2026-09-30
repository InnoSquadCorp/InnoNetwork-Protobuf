# InnoNetwork-Protobuf

The standalone [validation app](Examples/ValidationApp/README.md) exercises the
unpublished macro-first candidate through real URLSession sockets and persistent
sandbox storage. Its local-pair/device results are not published-dependency or
production-service certification.

Endpoint macros reject member-level `#if` declarations so that body, query and
request policies cannot silently disappear. Put `#if` around the complete
endpoint declaration, or use the manual `EncodedAPIDefinition` contract.

Protocol Buffers over HTTP, using InnoNetwork's public encoded-request executor.
The Swift module remains `InnoNetworkProtobuf`; the preferred library product is
`InnoNetwork-Protobuf`. The `InnoNetworkProtobuf` product is a compatibility alias.

## Development and publication status

This is the **unpublished, breaking 6.0 development line**. It requires the new
InnoNetwork **6.1** contract, also currently unpublished, and SwiftProtobuf 1.38.1+.
The adapter pins core to 6.1.x while its compiler-host support contract is minor-bound.
Published core 6.0.0 cannot compile this adapter. No release/tag is changed by
local development. Published adapter 3.0.1 belongs with its documented core 3.x.
See [migration](docs/MIGRATION_6_0.md), [release gates](docs/releases/6.0.0.md), and
[current macro-first validation](docs/MACRO_FIRST_VALIDATION_6_0.md).

After both new tags are published:

```swift
.package(url: "https://github.com/InnoSquadCorp/InnoNetwork.git", from: "6.1.0"),
.package(url: "https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git", from: "6.0.0"),
.package(url: "https://github.com/apple/swift-protobuf.git", from: "1.38.1"),
```

Link the products needed by the consuming target:

```swift
.product(name: "InnoNetwork", package: "InnoNetwork"),
.product(name: "InnoNetwork-Protobuf", package: "InnoNetwork-Protobuf"),
.product(name: "SwiftProtobuf", package: "swift-protobuf"),
```

## Request: macro first

Use protoc-generated `Message & Sendable` types. Well-known generated messages
keep this example self-contained:

```swift
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

@ProtobufAPIDefinition(method: .post, path: "/echo", auth: .anonymous)
struct Echo {
    typealias APIResponse = Google_Protobuf_StringValue
    let body: Google_Protobuf_StringValue
    var protobufOptions: ProtobufCodingOptions {
        .init(maximumRequestBytes: 8_192, maximumResponseBytes: 8_192)
    }
}

var body = Google_Protobuf_StringValue()
body.value = "hello"
let request = Echo(body: body)
// With an application-owned configured client:
// let result = try await client.request(request)
// let operation = OperationNetworkClient(client: client).start(request)
// let result = try await operation.value()
```

The 8 KiB limits are example endpoint budgets, not universal defaults. Encoding
is deferred until executor preflight succeeds and happens once per invocation;
retries/401 refresh reuse bytes. A new invocation encodes anew. Authentication,
idempotency, late signing, deadlines, cancellation, caching and admission remain
owned by core policy. Binary-only test doubles conform to `EncodedRequestClient`.

For GET, omit `body`. Declare ordinary `query: Encodable & Sendable` values for
HTTP query parameters; they append after `requestOptions.queryItems`, preserving
duplicates and order. An optional `queryEncoder` selects array handling.
`protobufOptions` and `requestOptions` are optional instance stored/computed
policy properties. A missing body differs from a default message whose
valid encoding happens to contain zero bytes. GET/HEAD/TRACE bodies are rejected.
Optional-message bodies preserve nil versus present-empty, including aliases.
Use `response: .noContent` with `APIResponse = EmptyResponse` for HTTP 204/205;
use `Google_Protobuf_Empty` for a protobuf message, including unknown fields.

Macros accept structs, public/private/nested and generic Message bodies.
Paths/auth/methods must be explicit supported declarations; unused stored inputs,
computed body/query, optional path values and owned witness collisions fail
compilation. The compiler, not syntax guessing, checks message/query conformances.

### Advanced: manual factory / compiler-plugin opt-out

The same endpoint can be built without a macro:

```swift
let manual = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
    method: .post, path: "/echo", auth: .anonymous, body: body,
    codec: .init(maximumRequestBytes: 8_192, maximumResponseBytes: 8_192))
```

Set `traits: []` on both package dependencies for a compiler-free graph; another
dependency enabling the trait can reactivate it. See the independent
[manual consumer](Examples/ManualConsumerSmoke/Package.swift). Manual named
endpoints can conform to core `EncodedAPIDefinition`. Do not implement the removed
3.x `ProtobufAPIDefinition` protocol or add fake `Codable` to generated messages.

## Media, decoding and no-content

- Default Content-Type/Accept is `application/protobuf` (RFC 9996).
- `ProtobufCodingOptions(mediaType: .legacy)` explicitly sends `application/x-protobuf`.
  `acceptsLegacyMediaType` and `allowsMissingContentType` are separate response opt-ins.
- Strict decoding accepts only the selected binary profile and supported
  `encoding=binary` parameter. The reserved `version` parameter, duplicate and
  unsupported parameters are rejected; no wire version is currently defined.
  See the [official media-type contract](https://protobuf.dev/reference/protobuf/mime-types/).
  No JSON/gRPC detection, no automatic POST re-send after 415.
- Depth defaults to 100; unknown fields are preserved. Deterministic ordering is
  opt-in, not a canonical cross-language signature representation.
- Schema Empty uses `Google_Protobuf_Empty`, including unknown-field equality.
  HTTP no-content uses `EncodedRequest<EmptyResponse>` and `.noContent()` (204/205
  with no observed body), never an implicit successful decode of malformed bytes.
- Proto2 required fields remain required. A valid proto3 zero-byte message is decoded normally.

## Limits and errors

`maximumRequestBytes` is checked **after encoding, before sending**; it does not
cap temporary allocations. Response limits tighten core's collection cap and
are rechecked before decoding. Default codec byte limits inherit core/app policy;
there is no invented application payload size. Synchronous codec work is not
forcibly preempted by cancellation; core checkpoints suppress late success.

Execution throws `NetworkError`. Encoding/invalid-limit/request-budget failures
use `.configuration(reason: .invalidPayload(...))`, not retryable transport errors.
Decode/media failures use `.decoding(stage: .responseBody, ...)`, with payload-free
`EncodedPayloadFailure` domain/codes. Core HTTP/network/auth errors retain their
existing meaning. Failure bodies follow core `captureFailurePayload` policy.
`EncodedRequestOptions.codecObserver` reports stage, byte count, monotonic duration
and success only, without a body or token. The callback is synchronous and must
be short. Encoding is measured once per invocation, not once per retry; physical
attempt and terminal lifecycle events continue through core observers.

## Local verification

```bash
export INNONETWORK_LOCAL_PATH=/absolute/path/to/InnoNetwork-encoded-request
swift test
swift run InnoNetworkProtobufDocSmoke
swift run --package-path Examples/ConsumerSmoke ConsumerSmoke
swift run --package-path Examples/ConsumerSmoke LegacyConsumerSmoke
ruby Scripts/check_macro_compile_failures.rb
bash Scripts/check_macro_disabled_consumer.sh
bash Scripts/check_docs_contract_sync.sh
ruby Scripts/test_release_gate.rb
```

This adapter enables its own `Macros` trait by default; core's JSON macro is
independent. The mixed external consumer enables both. SwiftSyntax 603.0.x and
the shared generator are compiler-host-only; macro trust follows the consuming
toolchain's normal policy, without a global bypass. Platform CI compiles applied
macro declarations, not merely the runtime library.
The local override is development-only; remote-only resolution and both published
tags remain release gates. iOS 16 / macOS 14 / tvOS 16 / watchOS 9 / visionOS 1,
Swift 6.2+; this is HTTP protobuf, not gRPC or a schema/code-generation service.
