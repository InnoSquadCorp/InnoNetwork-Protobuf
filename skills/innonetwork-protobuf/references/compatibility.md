# Versions, products and migration

The validated pair is adapter **6.1.1**, tag commit
`5e5f8316c94358235c3997e70e5e97aadc11df3a`, and Core **6.1.1**, tag commit
`44e4ca28c50c03f817231a077c0f3bdfdbc859c8`. The adapter manifest pins Core exactly,
including the compiler-host support contract. A broad Core 6.1.x declaration in
an application does not override that pin. If another dependency requires a
different Core version, inspect the graph and select a compatible released pair
under the user's dependency policy; do not replace dependencies with local paths.

Supported stable adapter line: `>=6.1.0 <6.2.0`, excluding prereleases. The first
observed tag in this line is 6.1.1; no 6.1.0 tag was found at check. A range does
not invent earlier versions or validate future patches. For each new patch,
verify the actual tag/commit and inspect manifest/API/release-note changes, then
test the consumer with that patch. Preserve its version instead of copying the
fixture pin. Recheck 6.2+, prereleases and moving branches separately.

## Package and compiler surface

| Surface | 6.1.1 contract |
| --- | --- |
| Preferred product / Swift module | `InnoNetwork-Protobuf` / `InnoNetworkProtobuf` |
| Compatibility product | `InnoNetworkProtobuf`, same module and runtime |
| Core | Exactly 6.1.1; public `EncodedRequest` execution |
| SwiftProtobuf | 1.38.1+; fixture pins 1.38.1 |
| SwiftSyntax | 604.0.x; fixture pins 604.0.0 |
| Manifest / language | Swift tools 6.2, Swift 6 language mode |
| Declared platforms | iOS 16, macOS 14, tvOS 16, watchOS 9, visionOS 1 |

Adapter `Macros` is enabled by default. Core's JSON macro trait is independent;
enabling both supports a mixed consumer. `SwiftSyntax` and
`InnoNetworkMacroSupport` belong to compiler-host targets, not application runtime
imports/products. Apply the toolchain's normal macro trust process.

For intentional macro-free use, set `traits: []` on **both** Core and adapter
dependencies and use manual factories or `EncodedAPIDefinition`. Another
dependency enabling a trait can reactivate it. Disabling macros removes compiler
targets from the selected graph; it does not remove manifest resolution constraints.
Do not promise a smaller resolved dependency set without checking the graph.

## Migrate historical 3.x code

| Removed contract | 6.1.1 replacement |
| --- | --- |
| `ProtobufAPIDefinition` protocol | `@ProtobufAPIDefinition` macro, or Core `EncodedAPIDefinition` |
| `ProtobufNetworkClient`, `protobufRequest` | Core client `request` with encoded request/endpoint |
| `ProtobufEmptyResponse`, `HTTPEmptyResponseMessage`, `protobufEmptyCapable` | Generated `Google_Protobuf_Empty` or explicit Core `EmptyResponse`, according to wire semantics |
| `ProtobufCodingOptions` from an unpublished proposal | Directional `ProtobufCodecOptions(encoding:decoding:)` |
| `protobufNoContent` / `.noContent` from an unpublished proposal | `protobufEmptyResponse` / `.empty(statusCodes:)` |

Do not port historical SPI examples or use the macro name as a protocol
constraint. Preserve explicit auth, headers, limits, unknown-field behavior and
retry/cancellation ownership. For rollback, restore a known compatible lockfile
pair; never move release tags. Schema generation/gRPC are separate tools/tasks.

Immutable sources: [manifest](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/Package.swift),
[API ledger](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/API_STABILITY.md),
[migration](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/docs/MIGRATION_6_0.md),
[manual consumer](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/Examples/ManualConsumerSmoke/Package.swift).
