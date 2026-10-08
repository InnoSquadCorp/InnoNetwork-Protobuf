# Roadmap

## 6.0 Release Boundary

The approved breaking redesign includes public core encoded requests, shared
operations/cancellation, explicit HTTP empty semantics, configurable binary codec,
standard media negotiation, resource budgets and hardened release validation.
It supersedes the earlier SPI-only compatibility reset and absorbs the former
encoding/decoding/media/generated-client candidates. Core 6.1.1 is published and is the exact dependency pin.

## Remaining gates

- Local core and adapter regression/integration/platform evidence.
- Remote-only dependency resolution and consumer checks against exactly Core 6.1.1.
- Exact adapter candidate Xcode 26/27 CI, five platforms, Ready notes and annotated tag.
- Separate publication approval, then both-remote-tag consumer verification.

## Optional follow-ups

- Upstream-supported pre-allocation encoder cap if a concrete consumer needs one.
- Dedicated protobuf throughput/peak-memory performance baselines with realistic schemas.
- Application-specific exporters consuming core's payload-free codec measurements.

## Out of scope

gRPC, streaming RPC, schema registries, generator ownership and canonical
serialization are separate contracts, not implicit features of this HTTP adapter.
