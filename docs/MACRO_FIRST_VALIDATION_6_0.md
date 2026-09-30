# Macro-first local implementation evidence

Date: 2026-09-30. Status: local implementation and scoped validation complete;
publication gates pending, not published or release-ready.

## Revision and authority

The maintainer approved sequential local execution of `MACRO_FIRST_PLAN_6_0.md`.
Core worktree: `InnoNetwork-encoded-request`, HEAD
`9d8053d5f921ebf5c38cc2f816efe90c7db4a450`, branch
`codex/encoded-request-contract`. Adapter HEAD:
`e6dc0ff414b15e044e667d192c3e30cc88d346b0`. The adapter's three existing local
commits remain intact. Evidence below applies to the recorded **uncommitted
source**, not those HEADs alone. No push, merge, automation, tag or release was
performed. The original core checkout remains at
`f8b13f47f757cfc3908aa4f801bba4f42d5e95b9` with its untracked Derived/Xcode files.

The implemented dependency pair is core 6.1.x + adapter 6.0, with SwiftProtobuf
1.38.1 and SwiftSyntax 603.0.2 resolved inside the supported 603.0.x range.
Xcode 27 / Swift 6.4 is installed locally; Xcode 26 evidence is still required.

## Implemented sequence

1. A separate three-package host-generator/adapter/client probe passed, including
   nested/public/private declarations and coexistence with the JSON macro.
2. `EncodedAPIDefinition` bridges direct requests and operations to the existing
   executor. Metadata is checked, factory invocation is once, and body encoding
   stays deferred. JSON protocol requirements were not changed.
3. JSON generation moved behind a thin plugin delegate into host-only support;
   shared validators serve both macros. This is the documented plan adjustment,
   not a change to JSON payload behavior.
4. Adapter `Macros` is default-enabled. The macro generates only public endpoint
   metadata and a typed factory; it does not start tasks, perform I/O or serialize.
5. Typed optional-body overloads, body/query combination, ordered query appending,
   explicit no-content response mode and manual factories are implemented.
6. Expansion tests and actual external compiler contracts reject malformed
   declarations. Generic bodies, aliases and visibility are checked by compilation.
7. Macro/manual policy comparisons cover auth, retry, cancellation, limits,
   signed response context, codec observations and credential-separated caching.
8. README and the preferred/doc consumers are macro-first; the independent
   macro-off package and compatibility product consumer remain runnable.
9. CI gains explicit compile-failure and macro-off checks. Coverage, safety
   scanners and ownership include the shared generator; runtime coverage excludes
   it. Platform builds now compile applied macros in a consumer target.
10. Runtime inventory is 1,764 (367 Stable candidates, 1,364 Provisional, 33 SPI).
    Twelve compiler-host declarations have a separate exact ledger. The new
    protobuf macro stays Provisional pending both supported toolchains. Published
    core 6.0's 1,702-row inventory and its release tag are unchanged.

## Validation matrix

Logs are retained under each checkout's `.build/encoded-contract-validation/`.
All rows here are current-turn checks unless marked reused or pending.

| Boundary | Evidence / limitation |
| --- | --- |
| Core regression | `macro-core-full.log`: 1,973 registered, 1,969 ordinary passes, four opt-in live skips; all eight test targets passed |
| Named endpoint bridge | Six new tests: factory once, metadata/factory failure, pre-cancel, zero deadline, tag forwarding, query order/empty/error sanitization |
| Core TSAN | `macro-core-tsan.log`: 38 endpoint/encoded-request/operation tests passed |
| JSON compatibility | 56 existing macro tests passed; five existing external negative package fixtures passed; mixed JSON/protobuf external consumer passed |
| Protobuf TSAN | `macro-adapter-tsan-final-fixed.log`: 42 runtime tests plus two macro expansion tests passed; parameterized rows execute both declaration styles |
| Compiler diagnostics | `macro-compile-final.log`: 19 invalid declarations with two passing controls; missing/invalid auth/method/path, optional path aliases, no-content mismatch, Message/query constraints, duplicate/owned/unused declarations; matching error lines, not source echoes, are required |
| Body/query/response | Encoded slash and duplicate ordered query; optional alias nil versus present-zero; 204/205 explicit contract; malformed media/depth/required proto2/unknown fields covered by freshly rerun codec suite |
| Retry/signing/observability | Required/optional 401 replay, anonymous bypass, fail-closed required auth, keyed/unsafe POST; identical bytes, one encoding observation, signed request visible to response interceptor |
| Cancellation/deadline | Entry barrier cancellation with one terminal event; pre-cancel/expired factory tests; queue/coalescing deadline and synchronous codec checkpoints covered by fresh core regression/TSAN, not a claim of every possible protobuf interleaving |
| Concurrency/limits | 64 distinct macro endpoint bodies remain bound to paths; request rejection before transport; response quota cannot raise the client's cap; current codec tests cover depth/unknown fields |
| Cache/coalescing | Macro/manual cache reuse and token-separated cache identity passed. Coalescing's adversarial combinations use the existing core suite; no new protobuf-specific all-interleavings claim |
| Consumer graphs | Doc, mixed JSON/protobuf, compatibility alias and independent manual consumer pass. Final fresh core/adapter trait-off checks pass (`macro-core-trait-final.log`, `macro-disabled-consumer-final.log`): **build products** have no compiled macro/SwiftSyntax/support artifacts; mixed executable has no linked support/SwiftSyntax symbols. SwiftPM still resolves/downloads swift-syntax prebuilt caches; these are not app-linked or scheduled compiler targets |
| Apple SDKs | macOS execution plus iOS, tvOS, watchOS and visionOS `MacroPlatformSmoke` builds pass on Xcode 27, using normal host-plugin/target separation |
| Contract/tooling | Core and adapter docs checks, API budget/tier fixtures, release-state fixtures, nine CI-contract tests/38 assertions, trait graph, safety scanners, formatting and whitespace passed. Actionlint uses only the existing custom xcode-27 runner label in a diagnostic config |
| Runtime/build cost | Controlled comparison passes all 14 runtime and five JSON guards at the unchanged 20% limit; original lifecycle measurement failure preserved below. Five-repeat protobuf consumer matrix and independent no-op/edit controls complete; detailed measurements below |
| Publication | Deliberately unexecuted: final committed SHA CI, Xcode 26, public core 6.1 dependency resolution, protected merges and validate-only Release. Draft stays Draft |

## Build-cost baseline and no-op controls

The new **protobuf-only** SwiftPM profile was measured five times per graph on
MacBookPro18,1 (M1 Pro, 32 GiB), macOS 27.0.1 (26A434), Xcode 27.0 (27A266a),
Swift 6.4 (swiftlang-6.4.0.34.1). Each repetition used a fresh temporary consumer
and scratch directory; shared dependency/prebuilt caches were retained. All
65 build commands succeeded: 25 clean, 25 no-op, 15 one-endpoint edits.
These are command wall-time medians including resolution/startup, not just
compiler time, and they are not a new SLO or portable regression threshold.

| Graph | Clean | No-op | One endpoint edit |
| --- | ---: | ---: | ---: |
| Both macros disabled | 17.93 s | 3.28 s | — |
| Protobuf macro enabled, 0 endpoints | 18.14 s | 3.15 s | — |
| 10 endpoints | 19.29 s | 3.45 s | 4.09 s |
| 50 endpoints | 19.07 s | 3.26 s | 4.35 s |
| 200 endpoints | 19.70 s | 3.08 s | 5.32 s |

Raw samples: core `.build/encoded-contract-validation/protobuf-build-times.json`;
65 logs: `protobuf-build-raw/`; summary/resource audit:
`macro-build-log-audit.log`. Clean command-level maximum-resident medians were
535 MiB with macros disabled and 637–643 MiB with macros enabled. These
`time -l` figures are not a peak-memory guarantee for the codec or an app.
The fresh JSON/mixed-profile and separate `xcodebuild` repeated timing matrices
were not measured; their existing historic baselines are not this candidate's
fresh evidence. Mixed-graph functional builds did pass.

Nine compact no-op logs displayed numbered target progress. An initial audit
mistook these labels for scheduled compilation; that failure is retained in
`macro-build-log-audit-initial.log`. Verbose mixed-consumer controls showed
up-to-date targets with no compilation/linking. An independent **200-endpoint
protobuf-only** clean → no-op → endpoint edit → no-op probe then verified both
no-op builds preserved hashes and modification times of all 237 object files
and ran no compile/link commands. The actual edit invalidated objects and
compiled, so the control detects real rebuilds. Evidence:
`protobuf-noop-200-{clean,noop-1,edit,noop-2}.log` and
`protobuf-noop-200-probe.log`; the independent consumer path is retained in
that probe log. No runtime or build behavior was changed to silence the audit.

The extended measurement-harness fixtures cover JSON/protobuf/mixed traits,
0/10/50/200 declaration counts, one-endpoint edit identity, repeated phase
classification and medians. Final docs/API contracts, 535-file formatting,
release-state fixtures and source hash checks passed. Production hashes in
each checkout's `macro-source-sha256.txt` still match the code tested by the
full suites; subsequent changes were documentation, diagnostics and tooling.

## Failures investigated during validation

The first three-pair runtime guard failed lifecycle throughput at -41.83%.
Pair timings (base/head seconds) were 1.889/3.368, 1.921/3.302, 1.891/1.914.
The WebSocket source and disassembly of the complete WebSocketState object are
identical between baseline and candidate. A diagnostic-only benchmark subset
(unchanged work and iteration count) completed six candidate runs at
1.894–1.905 seconds. This does not establish the exact cause of the two slow
full-suite samples. A transient swift-test process was observed during the first
comparison but had exited before its owning checkout could be identified; no
foreign process was stopped. Preserve this as an unresolved measurement event,
not proof of a product regression or proof of environmental noise.
One full controlled comparison was requested after the scoped builds finished;
there is no green-until-pass loop and no threshold/baseline reduction. Its logs
and `.build/macro-first-benchmarks-control/` are separate from the original
`.build/macro-first-benchmarks/` failure. Focused subset data does not replace
the full guard. The controlled comparison completed successfully: all 14 runtime
and five JSON guards passed at the unchanged 20% limit. Lifecycle delta was
-0.063% (1.211 percentage-point pair spread); cache revalidation +0.080%, event
delivery -0.905%, and the largest JSON regression was anyOf matching at -6.81%.
This is a successful local guard run, not a retrospective explanation of the
initial failure. The unresolved initial sample variation stays visible for the
final-candidate remote performance gate.
The runtime baseline is published core revision `9d8053d5f921ebf5c38cc2f816efe90c7db4a450`;
the head measurement uses the recorded uncommitted candidate, not the unchanged
Git HEAD alone. The JSON lane retains the script's existing archived JSON
baseline; neither baseline was advanced to make this run pass.

The initial cache parity test omitted explicit permission to cache an authenticated
response. It failed because the existing core correctly refused storage, not
because the macro had a different cache identity. The fixture now supplies
`Cache-Control: public, max-age=60` and matching response URL; alpha/beta/alpha
identity controls pass. Original failure log is retained as
`macro-adapter-tsan-final.log`; no cache production semantics were loosened.

An early negative fixture assumed all absolute route literals were compile-time
errors. The existing JSON validator permits them subject to runtime URL policy;
the fixture was corrected to the actual forbidden query-in-path contract, without
changing JSON behavior. Early compiler/format/doc-inventory failures remain in
local logs where separately captured; final passed logs are explicitly named.

## Remaining boundaries

No live device/server/IdP/exporter/FairPlay service was supplied. No Capto or other
application source migration was performed. The earlier workspace reference scan
(reused, not a new whole-workspace audit) found no active importing app graph and
left fourteen unrelated legacy lockfile pairs untouched. Modified references in
this task are the actual adapter consumers, core recipe and candidate contracts.

Next publication order is core PR/CI/merge/release, then adapter public dependency
resolution and PR/CI/merge, followed by validate-only Release. This requires separate
publication authority. Local success does not certify unknown service behavior,
all potential defects, Xcode 26 compatibility or a published dependency pair.
Reconcile each candidate with freshly fetched remote main before that publication
sequence; the original local core checkout and remote CI were not updated here.
