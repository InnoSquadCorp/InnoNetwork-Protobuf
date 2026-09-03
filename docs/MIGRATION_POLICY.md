# Migration Policy

## Stable API

- Stable API changes require a migration note when call sites or behavior must change.
- Behavior changes without source breakage should still be documented if they affect protobuf request execution, decoding, or installation requirements.

## Provisionally Stable API

- These APIs may evolve faster, but changes still require release notes and updated examples.

## Internal / Operational

- Internal details are not migration-contract items.
- Changes to SPI imports, local workspace wiring, or adapter internals do not require public migration docs unless they affect documented behavior.

## 3.0.1 to 6.0.0

- Upgrade `InnoNetwork` and `InnoNetworkProtobuf` as a coordinated pair.
- Every `ProtobufAPIDefinition` must explicitly provide
  `sessionAuthentication`; use `.anonymous` only for endpoints that truly do
  not participate in authenticated-session recovery.
- Protobuf request execution intentionally uses InnoNetwork's
  `GeneratedClientSupport` SPI. Applications should consume the public
  `protobufRequest` API rather than importing that SPI themselves.
- The 6.0 line supports iOS 16, macOS 14, tvOS 16, watchOS 9, and visionOS 1,
  matching the core package floors.
