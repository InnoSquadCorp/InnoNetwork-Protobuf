# InnoNetwork-Protobuf

## AI development skill

The library-owned [InnoNetwork-Protobuf skill](skills/innonetwork-protobuf/SKILL.md)
supports stable 6.1.x, with an exact 6.1.1 adapter/Core consumer baseline. Use it
with Codex or Claude Code for macro-first integration, codec policy and testing.
See [installation and source ownership](skills/README.md) and
[validation evidence](skills/validation.md).

The standalone [validation app](Examples/ValidationApp/README.md) exercises the
macro-first adapter through real URLSession sockets and persistent
sandbox storage. Its local-pair/device results are not published-dependency or
production-service certification.

Endpoint macros reject member-level `#if` declarations so that body, query and
request policies cannot silently disappear. Put `#if` around the complete
endpoint declaration, or use the manual `EncodedAPIDefinition` contract.

Protocol Buffers over HTTP, using InnoNetwork's public encoded-request executor.
The Swift module remains `InnoNetworkProtobuf`; the preferred library product is
`InnoNetwork-Protobuf`. The `InnoNetworkProtobuf` product is a compatibility alias.

## Development and publication status

This is the **breaking 6.1.1 release line**. It requires the new
published InnoNetwork **6.1.1** contract, and SwiftProtobuf 1.38.1+.
The adapter pins Core to exactly 6.1.1, including its compiler-host support contract.
The paired validation checkout uses the immutable commit behind the same published tag.
Published core 6.0.0 cannot compile this adapter. No release/tag is changed by
local development. Published adapter 3.0.1 belongs with its documented core 3.x.
See [migration](docs/MIGRATION_6_0.md), [release gates](docs/releases/6.1.1.md), and
[historical macro-first validation](docs/MACRO_FIRST_VALIDATION_6_0.md).

The **Paired candidate** jobs are part of the required CI workflow and check
the immutable Core 6.1.1 revision on Xcode 26.0.1/27.0. Both the public and paired
lanes run real cold/warm loopback consumers. Release validation additionally runs
fresh-scratch Thread Sanitizer. See [release evidence and gates](docs/releases/6.1.1.md).

For quick local feedback, run `bash Scripts/check_static_contracts.sh`. The
independent **Static Contracts (no dependency resolution)** CI job runs this on
every PR, including documentation-only changes, without Swift resolution or a
published Core tag. It does not replace compiled consumers or release validation.

After SwiftPM resolution/build, run
`ruby Scripts/check_dependency_integrity.rb <scratch-path> <Package.resolved-path>`
to compare the active dependency graph, lockfile, Git HEADs, commit objects and
checkout cleanliness. Candidate, consumer, macro and platform validation also
run this guard. A corrupt/stale cache is rejected, never automatically deleted.
Use a fresh `--scratch-path` to retain failed evidence; pass that same path through
`PROTOBUF_VALIDATION_SCRATCH_PATH` when running the macro compiler controls.
Local package paths are checked for consistency, not certified immutable by this
guard; the paired workflow separately verifies Core with `check_core_candidate.rb`.

After the adapter 6.1.1 tag is published (Core 6.1.1 is already published):

```swift
.package(url: "https://github.com/InnoSquadCorp/InnoNetwork.git", exact: "6.1.1"),
.package(url: "https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git", from: "6.1.1"),
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
    var protobufOptions: ProtobufCodecOptions {
        .init(encoding: .init(maximumEncodedRequestBytes: 8_192), decoding: .init(maximumEncodedResponseBytes: 8_192))
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
Use `response: .empty()` with `APIResponse = EmptyResponse` for HTTP 204/205;
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
    codec: .init(encoding: .init(maximumEncodedRequestBytes: 8_192), decoding: .init(maximumEncodedResponseBytes: 8_192)))
```

Set `traits: []` on both package dependencies for a compiler-free graph; another
dependency enabling the trait can reactivate it. See the independent
[manual consumer](Examples/ManualConsumerSmoke/Package.swift). Manual named
endpoints can conform to core `EncodedAPIDefinition`. Do not implement the removed
3.x `ProtobufAPIDefinition` protocol or add fake `Codable` to generated messages.

## Media, decoding and no-content

- Request `ProtobufEncodingOptions.mediaType` and response
  `ProtobufDecodingOptions.acceptedMediaTypes` are independent. A legacy request can
  receive a standard response. Accept advertises the complete response set.
- Example: `ProtobufCodecOptions(encoding: .init(mediaType: .legacy), decoding: .init(acceptedMediaTypes: [.standard, .legacy]))`.
- `allowsMissingContentType` is a response-only opt-in. Request Content-Type remains
  checked against the encoding profile. Conflicting/duplicate headers are rejected.
- The parser deliberately implements a strict binary subset: only `encoding=binary`
  is supported. Other MIME/schema parameters, duplicate parameters, JSON and gRPC
  are rejected. This is narrower than the [full MIME contract](https://protobuf.dev/reference/protobuf/mime-types/).
  There is no automatic resend after 415 or implicit format detection.
- Depth defaults to 100; unknown fields are preserved. Deterministic ordering is
  opt-in, not a canonical cross-language signature representation.
- Schema Empty uses `Google_Protobuf_Empty`, including unknown-field equality.
  HTTP empty responses use `EncodedRequest<EmptyResponse>.protobufEmptyResponse`
  and `response: .empty(statusCodes: [200, 204])`; default `.empty()` allows 204/205
  with no observed body, never an implicit successful decode of malformed bytes.
- Proto2 required fields remain required. A valid proto3 zero-byte message is decoded normally.

## Limits and errors

`maximumEncodedRequestBytes` is checked **after encoding, before sending**; it does not
cap temporary allocations. `ProtobufDecodingOptions.maximumEncodedResponseBytes` tightens core's collection cap and
are rechecked before decoding. Default codec byte limits inherit core/app policy;
there is no invented application payload size. Synchronous codec work is not
forcibly preempted by cancellation; core checkpoints suppress late success.

Execution throws `NetworkError`. Encoding/invalid-limit/request-budget failures
use `.configuration(reason: .invalidPayload(...))`, not retryable transport errors.
Decode/media failures use `.decoding(stage: .responseBody, ...)`, with payload-free
`ProtobufDecodingFailure` domain/codes distinguishing malformed/truncated data,
invalid UTF-8, missing required fields, nesting limits, extension decoding failures and media.
Limit/configuration failures retain core `EncodedPayloadFailure` codes. Core HTTP/network/auth errors retain their
existing meaning. Failure bodies follow core `captureFailurePayload` policy.
`EncodedRequestOptions.codecObserver` reports stage, byte count, monotonic duration
and success only, without a body or token. The callback is synchronous and must
be short. Encoding is measured once per invocation, not once per retry; physical
attempt and terminal lifecycle events continue through core observers.

Cacheable malformed bytes can fail decoding again on a cache hit. See
[explicit cache recovery](docs/CACHE_RECOVERY.md) for the opt-in freshness policy,
macro-first executable example, and the 304/retry limitations.

## Local verification

```bash
export INNONETWORK_LOCAL_PATH=/absolute/path/to/InnoNetwork-encoded-request
ruby Scripts/test_core_candidate.rb
ruby Scripts/check_core_candidate.rb "$INNONETWORK_LOCAL_PATH"
swift package resolve
ruby Scripts/check_core_candidate.rb "$INNONETWORK_LOCAL_PATH" .build/workspace-state.json
swift test
swift run InnoNetworkProtobufDocSmoke
swift run --package-path Examples/ConsumerSmoke ConsumerSmoke
swift run --package-path Examples/ConsumerSmoke LegacyConsumerSmoke
ruby Scripts/check_macro_compile_failures.rb
bash Scripts/check_macro_disabled_consumer.sh
bash Scripts/check_docs_contract_sync.sh
ruby Scripts/test_release_gate.rb
```

For exact-pair evidence, use a clean checkout at `.github/core-candidate.sha`.
The checker rejects another core revision, local core source changes and a stale
active Core dependency in SwiftPM's graph. Deliberately testing other local core
work is still possible, but must be reported as a different pair, not as
validation of the pinned candidate.
For an isolated compiler check, set `PROTOBUF_VALIDATION_SCRATCH_PATH` to a fresh
build directory when invoking `Scripts/check_macro_compile_failures.rb`.

This adapter enables its own `Macros` trait by default; core's JSON macro is
independent. The mixed external consumer enables both. SwiftSyntax 604.0.x and
the shared generator are compiler-host-only; macro trust follows the consuming
toolchain's normal policy, without a global bypass. Platform CI compiles applied
macro declarations, not merely the runtime library.
The local override is development-only; remote-only resolution and both published
tags remain release gates. iOS 16 / macOS 14 / tvOS 16 / watchOS 9 / visionOS 1,
Swift 6.2+; this is HTTP protobuf, not gRPC or a schema/code-generation service.

## Sponsorship

Support InnoNetwork-Protobuf development through [GitHub Sponsors](https://github.com/sponsors/InnoSquadCorp) or [Patreon](https://www.patreon.com/15188938/join).

### Directional policy and empty response migration

The old combined `ProtobufCodingOptions` is removed. Use `ProtobufCodecOptions`
with separate `encoding` and `decoding` values. Standalone body/decoder factories
accept only their own directional options. HTTP empty responses accept encoding
options and explicit successful status codes, so unused decoding limits cannot
invalidate them. Raw `EncodedRequestOptions.maximumResponseBytes` remains a Core
collection limit; factory policies can only tighten it.

`Scripts/validate_candidate.sh standard` is shared by both public and pinned-pair CI.
It executes serial/parallel tests, compiler controls, external consumers (including
real macro-off sockets), and cold/warm loopback checks. Release validation runs the
same script with `release`, including an isolated TSAN build, on both supported
Xcodes. CI Required includes the pinned pair. Release publishing still requires
immutable tag identity, main ancestry, annotated tag and committed Ready notes.

The loopback fixture has one implementation in `Examples/ValidationSupport`, a
local sample-only package with no Core or compiler dependencies. The macro-on and
macro-off consumers keep their own independent graphs. On full CI runs, the public
Xcode matrix owns consumer execution; the `Consumer Smoke` compatibility check
requires that complete matrix to succeed instead of repeating its work. Docs-only
changes keep their independent compiled documentation smoke path.
