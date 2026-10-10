# Roadmap

## 6.1.1 Release Boundary

The approved breaking redesign includes public core encoded requests, shared
operations/cancellation, explicit HTTP empty semantics, configurable binary codec,
standard media negotiation, resource budgets and hardened release validation.
It supersedes the earlier SPI-only compatibility reset and absorbs the former
encoding/decoding/media/generated-client candidates. Core 6.1.1 is published and is the exact dependency pin.

## Release qualification

Adapter [6.1.1](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/releases/tag/6.1.1)
is published. The [release qualification record](releases/6.1.1.md) preserves
the reviewed gates and evidence; it is not a request to publish the same tag again.
Future releases must repeat the applicable exact-revision, consumer, platform
and release gates. Historical local-pair results do not certify later changes.

## Optional follow-ups

- Upstream-supported pre-allocation encoder cap if a concrete consumer needs one.
- Dedicated protobuf throughput/peak-memory performance baselines with realistic schemas.
- Application-specific exporters consuming core's payload-free codec measurements.

## Out of scope

gRPC, streaming RPC, schema registries, generator ownership and canonical
serialization are separate contracts, not implicit features of this HTTP adapter.
