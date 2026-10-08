# API Stability

This ledger describes the unpublished 6.0 redesign, not the released 3.x API.
No GeneratedClientSupport SPI is imported by this package.

## Stable

- `ProtobufMediaType`
- `ProtobufEncodingOptions`
- `ProtobufDecodingOptions`
- `ProtobufCodecOptions`
- `ProtobufDecodingFailure`
- `EncodedRequest.protobuf(method:path:auth:body:codec:options:)`
- `EncodedRequest.protobuf(method:path:auth:codec:options:)`
- `EncodedRequest.protobufEmptyResponse(method:path:auth:body:encoding:statusCodes:options:)`
- `EncodedRequest.protobufEmptyResponse(method:path:auth:encoding:statusCodes:options:)`
- `EncodedRequestBody.protobuf(_:options:)`
- `AnyResponseDecoder.protobuf(options:)`

## Provisionally Stable

- `ProtobufResponseMode` and `@ProtobufAPIDefinition(method:path:auth:response:)`:
  candidate surface pending both Xcode 26 and 27 external-compiler validation.
- The body factory includes a typed optional-message overload. Nil is absent;
  a present zero-byte message remains an HTTP body.
- Dependency minimums and local coordinated-development override.
- Runnable consumer examples and release tooling.

## Internal/Operational

- Media-header parser and option merging implementation.
- Build artifact layout and test helpers.

## Contract

Stable compatibility begins with publication of this major. Request execution,
typed NetworkError, operation lifecycle and HTTP no-content belong to core 6.1+.
Every factory requires explicit `auth`. Default media validation is strict;
legacy/missing response headers require explicit codec policy. Byte quotas are
not promises about peak encoder memory. Generated message unknown fields retain
SwiftProtobuf equality/serialization semantics.

Removed in this major: the old `ProtobufAPIDefinition` **protocol**, `ProtobufNetworkClient`,
`protobufRequest`, `ProtobufEmptyResponse`, `HTTPEmptyResponseMessage`, and
`protobufEmptyCapable`. See [migration](docs/MIGRATION_6_0.md).
Both product names still export the `InnoNetworkProtobuf` module.
The new macro shares the old protocol's spelling, but generates core
`EncodedAPIDefinition` conformance and cannot be used as a protocol constraint.
`Macros` is enabled by default; disabling it removes macro declarations but
retains manual factories and runtime behavior. SwiftSyntax 604.0.x and
`InnoNetworkMacroSupport` are compiler-host dependencies, not app runtime APIs.
