# InnoNetwork 6.0 compatibility

> Historical record — retained for the source, date and environment below.
> For the published 6.1.1 contract, use the [current quick start](../README.md)
> and [documentation map](README.md). Unexecuted checks are not implied passes.


> Historical evidence for the superseded SPI adapter, before the approved
> breaking redesign. It does **not** validate the current encoded-request API
> against published core 6.0. See [current implementation evidence](IMPLEMENTATION_6_0.md).

Status: local compatibility validation passed on 2026-09-30 (Asia/Seoul);
adapter not published.

## Scope and baseline

- Adapter starting commit: `9d622d77d93813dd301c00eb6e9c3a8b73d177a4`.
  This existing local preparation commit is preserved, not rewritten.
- Core: public annotated InnoNetwork `6.0.0`, resolved commit
  `9d8053d5f921ebf5c38cc2f816efe90c7db4a450`.
- Dependency requirement remains `6.0.0..<7.0.0`; no production API change or
  extra codec/gRPC/operation-handle feature is part of this update.
- Local toolchain: Xcode 27.0 (27A266a), Swift 6.4, macOS host.
- Resolved SwiftProtobuf: `1.38.1`. Results below apply to this resolved graph,
  not every future version allowed by the package's dependency ranges.
- All commands below explicitly unset `INNONETWORK_LOCAL_PATH`; the independent
  consumer uses the local adapter but the **published remote core**.

The resolved core revision is checked in both the root and consumer lockfiles;
historical local-path test results are not reused as published-tag evidence.

## Validation

Fresh scratch directory: `.build/compatibility-6.0.0/` (ignored).

```bash
env -u INNONETWORK_LOCAL_PATH swift test --scratch-path .build/compatibility-6.0.0/root
env -u INNONETWORK_LOCAL_PATH swift run --scratch-path .build/compatibility-6.0.0/root InnoNetworkProtobufDocSmoke
env -u INNONETWORK_LOCAL_PATH swift run --package-path Examples/ConsumerSmoke --scratch-path .build/compatibility-6.0.0/consumer ConsumerSmoke
bash Scripts/check_docs_contract_sync.sh
git diff --check
```

- Existing 17-test baseline: PASS against the public core tag.
- Added compatibility suite: PASS (23 tests total; authentication and retry
  tests each include two parameterized cases).
- Required auth without policy fails before transport; anonymous requests do
  not read/refresh tokens; optional/required refresh replays preserve bytes.
- Malformed protobuf preserves `.decoding` stage and HTTP context; offline
  errors retain `.reachability`; pre-cancelled requests never reach transport.
- Default unsafe POST timeout recovery rejects replay without an idempotency
  key and preserves the same key/body when an explicitly keyed retry succeeds.
- Documentation contract, doc smoke build/run, workflow `actionlint`, shell
  syntax, YAML syntax and `git diff --check`: PASS.
- Fresh independent consumer build/run: PASS. Captured POST path, content type,
  absent anonymous Authorization, decoded request bytes and response value all
  checked. Root and consumer both resolved the exact core revision above.

### Local platform builds

All builds below used the same published core and Xcode 27. They are SwiftPM
package-target checks, not remote Xcode 26 CI, app archives or device runs.

| Platform | Target / validation | Result |
| --- | --- | --- |
| macOS | Host SwiftPM build, 23 tests, doc smoke and consumer run; package floor 14 | PASS |
| iOS | `arm64-apple-ios16.0-simulator`, `iphonesimulator` SDK | PASS |
| tvOS | `arm64-apple-tvos16.0`, `appletvos` SDK | PASS |
| watchOS | `arm64_32-apple-watchos9.0`, `watchos` SDK | PASS |
| visionOS | `arm64-apple-xros1.0`, `xros` SDK | PASS |

iOS used `swift build --target InnoNetworkProtobuf --triple ... --sdk ...`;
the other cross-targets used `Scripts/build_apple_platform_target.sh` with
the tuples above and scratch path `.build/compatibility-6.0.0/root`.
Separate `baseline-tests.log`, `final-tests.log`, `doc-smoke.log`, `consumer.log`
and `*-build.log` files retain the individual outcomes in the evidence directory.

### Repository and product naming follow-up

On 2026-09-30, the GitHub repository was renamed to
`InnoSquadCorp/InnoNetwork-Protobuf`. Repository identity, all advertised branch
and tag refs, and the existing open pull request were preserved. The old Git
URL and the new URL returned identical refs after the rename.

The 6.0 package and preferred product now use `InnoNetwork-Protobuf`; the
`InnoNetworkProtobuf` compatibility product and Swift module remain unchanged.
No consumer-side compiler aliases or special import flags are required.

Naming-specific local checks on the same Xcode 27 / Swift 6.4 toolchain:

- All 23 tests and the documentation executable: PASS.
- Preferred product consumer (binary request/response) and compatibility
  product consumer (original module and public API): both PASS.
- Generated `InnoNetwork-Protobuf-Package` Xcode scheme: present; iOS Simulator
  aggregate build: PASS with invocation-scoped `-skipMacroValidation` for the
  reviewed core macro. This is not evidence that an unconfigured clean CI
  runner's macro approval gate passes; that previously reported gap remains.
- Documentation contract, workflow actionlint, and whitespace checks: PASS.

Logs are in `.build/naming-20260930/`. The repository metadata rename is separate
from code publication: no Git push, tag, workflow dispatch or Release creation
was part of this follow-up. Historical 3.x releases retain their original
product names. The local checkout directory was intentionally not renamed.

## Remaining publication boundaries

Local checks are not remote CI or publication evidence. Before an adapter tag:

1. Commit the reviewed local compatibility changes with the intended author.
   Local commits are separate from publication; push only after user
   authorization. The repository metadata rename above did not publish these
   local commits or the new package product.
2. Pass final-SHA Xcode 26 and 27 CI plus all supported platform jobs. Only
   Xcode 27 is installed on this local host.
3. Create the separately authorized annotated adapter `6.0.0` tag and verify
   its Release workflow and GitHub Release.
4. Resolve both published tags from a new external consumer. The checked-in
   local-adapter consumer cannot satisfy that post-publication gate.

No full application migration, dedicated backend, real-device validation,
InnoStream release or automated follow-up is included.
