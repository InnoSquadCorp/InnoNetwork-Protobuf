# Roadmap

## 6.0 Release Boundary

The 6.0 release is a compatibility reset, not a feature expansion. It aligns
the adapter with InnoNetwork 6.0, preserves the focused protobuf public API,
and makes authentication intent, supported platforms, and release ordering
explicit.

The release remains blocked until:

- InnoNetwork `6.0.0` resolves remotely without `INNONETWORK_LOCAL_PATH`
- the root package and clean consumer smoke both resolve the remote dependency
- Xcode 26 and Xcode 27 builds pass
- iOS, macOS, tvOS, watchOS, and visionOS build gates pass
- an annotated InnoNetworkProtobuf `6.0.0` tag points to the reviewed main
  commit

## 6.1 Candidates

Candidates are intentionally ordered by consumer value and contract risk.
None is part of the 6.0 release contract.

1. **Configurable binary decoding policy**
   - expose a small package-owned value that can set SwiftProtobuf's message
     depth limit and unknown-field behavior per endpoint
   - retain the current defaults so existing endpoints do not change behavior
   - add malformed and deeply nested payload tests before making it stable
2. **Configurable binary encoding policy**
   - allow endpoints that need repeatable map ordering to opt into
     `BinaryEncodingOptions.useDeterministicOrdering`
   - document that SwiftProtobuf deterministic output is not a cross-language
     canonicalization or signing format
3. **Protobuf content negotiation profile**
   - keep `application/x-protobuf` as the default
   - evaluate an explicit opt-in for `application/protobuf` and a matching
     `Accept` header without introducing free-form duplicated header logic
4. **Payload observability without payload logging**
   - report encoded and decoded byte counts through InnoNetwork metrics hooks
   - never log binary bodies or generated message descriptions by default
5. **Generated-client ergonomics**
   - evaluate a narrowly scoped adapter for generated protobuf endpoints so
     application targets do not import `GeneratedClientSupport` directly
   - keep the SPI dependency internal to this package

## Explicitly Out of Scope for 6.1

- gRPC framing, HTTP/2 stream management, and bidirectional RPC
- schema registry or code generation ownership
- canonical serialization for signatures or persistent fingerprints

Those concerns require separate packages or contracts and should not be folded
into the HTTP protobuf body adapter implicitly.

## Promotion Gate

A 6.1 candidate becomes implementation work only after it has a concrete
consumer, an API sketch, compatibility tests, and a clear ownership boundary
between SwiftProtobuf, InnoNetwork, and this adapter.
