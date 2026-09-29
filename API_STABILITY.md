# API Stability

This document defines the compatibility contract for the public OSS release of `InnoNetwork-Protobuf` (Swift module `InnoNetworkProtobuf`).

## Stable

- `ProtobufAPIDefinition`
- `ProtobufNetworkClient`
- `ProtobufEmptyResponse`
- `HTTPEmptyResponseMessage`
- `AnyResponseDecoder.protobuf()`
- `AnyResponseDecoder.protobufEmptyCapable()`

## Provisionally Stable

- package dependency requirements on `InnoNetwork`
- installation guidance in the README
- smoke examples and troubleshooting guidance

## Internal/Operational

- protobuf adapter execution internals
- SPI imports used to bridge into `InnoNetwork`
- local workspace dependency wiring before the matching `InnoNetwork` release ships
- test support utilities and CI workflow structure

## Notes

- The preferred package product is `InnoNetwork-Protobuf`; the compatibility
  product `InnoNetworkProtobuf` remains available. Both expose the same module
  and preserve `import InnoNetworkProtobuf`.
- Stable items follow semantic versioning once the package is published.
- `ProtobufAPIDefinition.sessionAuthentication` is a required security witness;
  endpoint declarations cannot inherit an implicit authentication mode.
- `InnoNetwork` remains the source of truth for `DefaultNetworkClient`, transport behavior, retry behavior, and trust policy.
