# Contributing to InnoNetwork-Protobuf

Thanks for contributing to InnoNetwork-Protobuf.

## Before You Start

- Read [API Stability](API_STABILITY.md) before proposing public API changes.
- Read [Support](SUPPORT.md) to understand the maintainer response model.
- For security issues, do not open a public issue. Follow [SECURITY.md](SECURITY.md).

## Development Setup

```bash
swift test
bash Scripts/check_docs_contract_sync.sh
swift build --target InnoNetworkProtobufDocSmoke
swift run --package-path Examples/ConsumerSmoke ConsumerSmoke
swift run --package-path Examples/ConsumerSmoke LegacyConsumerSmoke
```

## Pull Request Expectations

- Keep public API changes narrow and justified.
- Update documentation when behavior or contracts change.
- Add or update tests for any user-visible behavior.
- Keep examples aligned with `DefaultNetworkClient` plus `ProtobufAPIDefinition`.
- Document any required matching `InnoNetwork` version or branch.

## Public API Policy

- `Stable` API changes require migration notes and changelog updates.
- `Provisionally Stable` APIs can evolve more quickly, but still require documentation updates.
- `Internal/Operational` items should not be relied on by downstream consumers.

## Commit / PR Checklist

- Tests pass locally.
- Docs contract sync passes.
- Both preferred and compatibility product consumers build and run.
- Changelog and release notes are updated when behavior changes.
