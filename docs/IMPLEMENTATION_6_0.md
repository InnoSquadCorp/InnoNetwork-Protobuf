# Encoded-request redesign implementation

Status: local implementation, unpublished. Date: 2026-09-30.

The subsequent macro-first implementation is tracked in
[current validation](MACRO_FIRST_VALIDATION_6_0.md). Counts and timing below are
the earlier runtime-only milestone, not evidence for the later macro source.

## Baseline and scope

- Adapter baseline: `e6dc0ff414b15e044e667d192c3e30cc88d346b0`; the three existing
  local commits are preserved. This work replaces its unpublished SPI draft.
- Core base: published 6.0.0 `9d8053d5f921ebf5c38cc2f816efe90c7db4a450`.
  Additive work lives in `InnoNetwork-encoded-request`, branch
  `codex/encoded-request-contract`. The original divergent core checkout and
  its generated Xcode artifacts are untouched.
- The current adapter requires the new core 6.1 contract. No tag or release is
  moved, created or published. Local override evidence is not public-tag evidence.
- Toolchain: Xcode 27 / Swift 6.4. SwiftProtobuf 1.38.1.
- No independent transport engine, gRPC, streaming codec, schema registry or
  serializer-internal API was introduced.

## Encoded-runtime milestone (before macro-first work)

| Boundary | Implementation / fresh local evidence |
| --- | --- |
| Public API | EncodedRequest/Body/Options/Client, no adapter SPI; binary-only fake compiles without Codable client conformance |
| Execution / retries | Same core executor and shared operation lifecycle; encoding once per call; keyed retries and 401 refresh preserve bytes |
| Options / limits | Core metadata forwarding; request quota before transport; response quota can only tighten the client cap |
| Signed response context | Integration reproduced the old core passing a pre-signing request to response interceptors; now use response provenance, with prepared-request fallback for synthetic responses and existing credential-redaction boundaries |
| Cancellation | Pre-cancel, operation-entry barrier, one terminal event, expired deadline before encoding/dispatch |
| Message semantics | Generated Empty unknown-field equality/preservation, explicit discard, proto2 required failures with passing controls |
| HTTP empty | No-content requires an allowed status and observed empty bytes; no dummy request message |
| Codec policy | Standard/legacy media profiles, malformed/wrong/reserved-version rejection, bounded decoding depth, missing-header opt-in |
| Observability | Payload-free encode/decode duration, byte count and success; encoding replay emits no duplicate codec sample; callback outside lock |
| Concurrency | 64 independent operation requests with captured body/path association |
| Consumers | Preferred and compatibility products run against the local core; doc executable compiles and runs |
| Apple platforms | macOS tests plus iOS/tvOS/watchOS/visionOS SwiftPM target builds; no macro-validation bypass |
| Release safety | Draft validation separate from explicit publish; strict version, existing annotated tag, validated SHA, main ancestry, committed Ready notes; negative fixtures |
| Dependency graph | Adapter opts out of unused core Macros trait with `traits: []`; SwiftProtobuf minimum and consumers updated to 1.38.1 |

## Reference inventory

Workspace search covered source imports and manifests plus lockfiles, excluding
generated build/checkouts. No active app manifest or source importing this adapter
or SwiftProtobuf was found. Fourteen legacy root lockfile pairs still mention
SwiftProtobuf 1.36.1; active `apple/Tuist/Package.swift` / Tuist lockfiles do not.
Those unrelated legacy files and dirty app work are preserved, not rewritten as
if they were active resolved graphs. Actual adapter consumer examples and the core
Protobuf recipe were migrated. Historical release/compatibility evidence remains
clearly labeled as historical.

## Reproduction

Set `INNONETWORK_LOCAL_PATH` to the new core checkout, then run:

```bash
swift test
swift run InnoNetworkProtobufDocSmoke
swift run --package-path Examples/ConsumerSmoke ConsumerSmoke
swift run --package-path Examples/ConsumerSmoke LegacyConsumerSmoke
bash Scripts/check_docs_contract_sync.sh
ruby Scripts/test_release_gate.rb
bash Scripts/build_apple_platform_target.sh iOS iphonesimulator arm64-apple-ios16.0-simulator
bash Scripts/build_apple_platform_target.sh tvOS appletvos arm64-apple-tvos16.0
bash Scripts/build_apple_platform_target.sh watchOS watchos arm64_32-apple-watchos9.0
bash Scripts/build_apple_platform_target.sh visionOS xros arm64-apple-xros1.0
swift run -c release --package-path Examples/ConsumerSmoke CodecBenchmarks
```

The new informational codec harness checks round-trip values and saves raw timing
samples for 8 KiB, 1 MiB, 8 MiB, 1,000-entry deterministic maps and nested messages.
It is not an invented historical performance guard or a peak-RSS measurement.
Core regression benchmarks retain their existing 20% guard and source baselines.

## Remaining release gates / explicit limitations

- Publish core 6.1 first, then validate minimum/latest public dependency resolution
  and clean consumers without the local override. Current remote 6.0 lacks this API.
- Final committed SHA needs remote CI, including Xcode 26/27 and the actual manual
  validation run showing Publish Release skipped. No remote run was requested here.
- The release environment must have appropriate required reviewers configured;
  merely naming an environment in YAML does not prove protection exists.
- Generated dependencies are not auto-trusted. Macro-first consumers must approve
  their compiler-plugin graph; the explicit macro-off consumer excludes host artifacts.
- Request size is checked after upstream serialization, not before allocations.
  Synchronous codecs are cooperatively checked, not forcibly preempted mid-call.
  Interceptors/signers are trusted application code; replacing a prepared body can
  exceed the codec quota and remains that custom component's responsibility.
- Only data delivered by URLSession is inspectable; hidden wire bytes on no-content
  responses are not claimed to be validated. No live service/device test was run.
- Old 23-test/public-core-6.0 evidence in COMPATIBILITY_6_0.md cannot be reused for
  this redesigned source. See the final validation record below for current counts.

## Prior runtime-only local validation

Historical evidence for the pre-macro implementation, not the current final source:

- Core: 1,967 tests registered; 1,963 ordinary tests passed and four opt-in live
  tests skipped. The 40 encoded-request/operation/signing tests also passed TSAN.
- Adapter: all 33 tests passed TSAN; documentation executable and both external
  consumer products passed against the local core.
- macOS host and iOS/tvOS/watchOS/visionOS target builds passed on Xcode 27.
  Xcode 26 is not installed locally and remains a remote gate.
- Core public inventory: 1,757 declarations, partitioned into 360 Stable,
  1,364 Provisional and 33 SPI. The added 55 declarations are explicitly reviewed
  additions, not removal of an existing API gate. Historical 6.0.0 tag validation
  still passes using its original 1,702-declaration inventory.
- Both documentation contracts, core API-tier fixtures, release positive/negative
  fixtures, workflow actionlint, scoped formatting and whitespace checks passed.
- Final logs, source checksums and the signed-response-context failure before its
  fix are retained in each checkout's `.build/encoded-contract-validation/`.

Codec costs below are medians of six measured samples after two warmups, Release
build on an Apple M1 Pro / 32 GiB, macOS 27.0.1, Xcode 27, Swift 6.4. They exclude
transport time and are an initial informational baseline, not an existing
performance SLO or a memory-allocation bound.

| Input | Encoded bytes | Encode (ms) | Decode (ms) |
| --- | ---: | ---: | ---: |
| 8 KiB bytes | 8,195 | 0.001605 | 0.005021 |
| 1 MiB bytes | 1,048,580 | 0.052938 | 0.036251 |
| 8 MiB bytes | 8,388,613 | 0.428125 | 0.215917 |
| Deterministic map, 1,000 entries | 21,890 | 2.414666 | 0.573146 |
| Nested value, depth 20 | 86 | 0.135063 | 0.009354 |

Raw samples: `.build/encoded-contract-validation/codec-samples.json`.

The independent core comparison completed successfully: all 14 runtime guards
and all five JSON guards passed the unchanged 20% threshold, using three paired
base/head measurements. Runtime comparison used the published 6.0.0 base
`9d8053d5f921ebf5c38cc2f816efe90c7db4a450`; JSON retained its reviewed baseline
`b358692e1e583b5cef1c97bb65208729b313f574`. The measured candidate was the recorded
uncommitted working tree, not a new published or committed SHA. This was not a
rerun of the historical runtime release-baseline gate.

Paired medians included coalescing -3.59%, cache revalidation -0.77% and JSON
anyOf -9.36%. Coalescing's 36.0 percentage-point pair spread demonstrates timing
variability; these results do not establish a universal speedup or replace final
remote validation. Raw samples, results and summaries are preserved in the core
checkout's `.build/encoded-contract-benchmarks/` and its `json/` subdirectory.

No commits, pushes, tags, remote workflow dispatches or releases were made during
this implementation. Existing local adapter commits and unrelated work remain
preserved.
