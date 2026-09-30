# Changelog

## Unreleased — 6.0 binary contract redesign

- Breaking: replace adapter endpoint/client SPI with core 6.1 EncodedRequest factories.
- Remove hand-written Empty message; use generated Empty or explicit HTTP no-content.
- Adopt application/protobuf, explicit legacy/missing-header compatibility, depth and byte budgets.
- Normalize codec failures and share core retry/cancellation/operation behavior.
- Require SwiftProtobuf 1.38.1 and core 6.1.x; enable the adapter Macros trait by default.
- Add @ProtobufAPIDefinition, ordinary query encoding, optional message bodies,
  explicit no-content response mode, mixed JSON/protobuf and macro-off consumers.
- Share route/auth/declaration validation through compiler-host support; no SPI
  execution, fake Codable, duplicate transport engine or global macro trust bypass.
- Harden release version/tag/SHA/Ready gates, negative fixtures, validation-only default and minimal permissions.

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog. Released 3.x tags remain stable while
`main` prepares the coordinated 6.0 line alongside InnoNetwork 6.1.

## Superseded unpublished SPI proposal (historical)

### Added

- Explicit `sessionAuthentication` intent on every `ProtobufAPIDefinition`.
- Regression tests against published InnoNetwork 6.0 for required/anonymous
  authentication, binary refresh replay, cancellation, structured decoding
  errors and idempotency-gated POST timeout retries.

### Changed

- Adopt `InnoNetwork-Protobuf` for repository, package and preferred product
  naming; retain the `InnoNetworkProtobuf` module and compatibility product.
- Validate both product names in the external consumer fixture.
- Require InnoNetwork `6.0.0..<7.0.0` for the next tagged release while
  retaining an explicit local-path override for pre-tag validation.
- Use the narrow `GeneratedClientSupport` SPI for binary payload execution and
  `InnoNetworkTestSupport` for consumer-owned transport tests.
- Map protobuf decode failures to the structured `NetworkError.decoding` case
  and migrate retry/configuration tests to the 6.0 contracts.
- Align the package deployment floors with InnoNetwork 6.0 and enforce Swift 6
  language mode for library, test, and documentation smoke targets.
- Execute the independent protobuf consumer smoke in CI and release validation.
- Distinguish the published core from the unpublished adapter in installation
  guidance, and separate pre-tag local-adapter checks from two-tag adoption.

## [3.0.1]

### Added

- Initial OSS package split for protobuf request and response support on top of `InnoNetwork`
- `ProtobufAPIDefinition`, `ProtobufNetworkClient`, `ProtobufEmptyResponse`, and `HTTPEmptyResponseMessage`
- Docs / contract sync automation, protobuf doc smoke target, and consumer smoke validation
- OSS governance documents, release policy, migration policy, support policy, and issue / PR templates

### Changed

- Protobuf support now lives outside the core `InnoNetwork` package so consumers that do not need protobuf no longer resolve `swift-protobuf`
- Core dependency is pinned to `InnoNetwork` `3.0.1` for the initial public release
