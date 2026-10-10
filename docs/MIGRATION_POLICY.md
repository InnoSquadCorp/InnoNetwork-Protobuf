# Migration Policy

## Stable API

- Stable API changes require a migration note when call sites or behavior must change.
- Behavior changes without source breakage should still be documented if they affect protobuf request execution, decoding, or installation requirements.

## Provisionally Stable API

- These APIs may evolve faster, but changes still require release notes and updated examples.

## Internal / Operational

- Internal details are not migration-contract items.
- Changes to SPI imports, local workspace wiring, or adapter internals do not require public migration docs unless they affect documented behavior.

## 3.0.1 to 6.1.1

- Upgrade `InnoNetwork` and `InnoNetwork-Protobuf` as a coordinated pair.
- Use the core 6.1 encoded-request contract, with explicit authentication on
  every factory. No SPI import or Protobuf-specific client is required.
- The prior development API is replaced, not retained as a second execution
  contract. Follow [the complete migration table](MIGRATION_6_0.md).
- The 6.x line supports iOS 16, macOS 14, tvOS 16, watchOS 9, and visionOS 1,
  matching the core package floors.

### Repository and package naming

- Canonical repository: `https://github.com/InnoSquadCorp/InnoNetwork-Protobuf`.
- New 6.1.1 integrations should select product `InnoNetwork-Protobuf` and keep
  `import InnoNetworkProtobuf` in Swift source.
- The legacy product `InnoNetworkProtobuf` is still available in 6.1.1. Both
  products expose the same module; do not depend on both simultaneously.
- When changing the dependency URL, also change the `.product(..., package:)`
  reference to `InnoNetwork-Protobuf` (unless an explicit package alias is in
  use). SwiftPM derives package identity from the dependency location; do not
  declare the old and new URLs together. Regenerate and review Package.resolved
  in your application after switching URLs.
- GitHub redirects the old repository URL, but consumers should adopt the
  canonical URL. Do not reuse the old repository name, which would break that
  redirect. Existing tags and release history are not rewritten by the rename.
- Historical 3.x tags still expose only the original product and require the
  matching old core. A repository rename does not upgrade those manifests.
