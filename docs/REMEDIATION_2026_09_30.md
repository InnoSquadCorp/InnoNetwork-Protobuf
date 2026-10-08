# Review remediation — 2026-09-30

This follow-up records authorized local fixes and commits after the macro-first
implementation and the expanded read-only review. It does not publish the
adapter or core, approve a tag, or change the Draft release state.

## Source pair and commits

- Adapter baseline `093dc45` checkpoints the approved redesign previously
  reviewed as dirty files on `e6dc0ff414b15e044e667d192c3e30cc88d346b0`.
  The three pre-existing local commits are preserved.
- Core baseline `ab757e1` checkpoints the approved encoded-request and shared
  macro implementation previously reviewed on `9d8053d5f921ebf5c38cc2f816efe90c7db4a450`.
- Adapter `6919cdc` adds actual external compiler failures for conditional
  endpoint members and a passing whole-endpoint platform conditional.
- Adapter `cee712d` adds compiled/runtime controls for escaped path/body/options
  and response-alias names, plus a property colliding with the generated helper.
- Final source pair: adapter `cee712dd345afee3f4642279df57ad426bfc909b` with
  core `5b6ee48e31a0b7a2931646b79699b32d073d2ad5`.
  Later evidence-only documentation commits do not alter the tested code.

All nine confirmed findings are addressed in the shared core or integration
surface: conditional macro omission (`9c5ec29`), escaped-name/helper hygiene
(`08ea3f4`), incompatible coalescing response budgets (`dc75398`), non-S3 signing
path identity (`2eace8e`), persisted cache numeric accounting (`9dfae77`),
download journal numeric recovery (`73b105b`), new error/example/enum integration
(`1828205`) and prose-only changelog validation (`5b6ee48`). F3/F4 share one
root-adjacent hygiene commit; no finding is counted twice as a separate fix.
The core's `docs/REMEDIATION_2026_09_30.md` contains the detailed closure matrix.

Final core validation additionally found an omitted compiler-host entry in the
DocC product ledger (F10). Core `cf8b43b` adds the entry and real-manifest-bound
positive/negative fixture controls. The actual ten-product archive check passes.
This changes only a product-list document and a shell test, not the Swift source
pair above; the core report preserves the initial failed preflight and the
targeted continuation evidence.

## Compatibility decision

Direct `#if` members are rejected by both endpoint macros before inference,
instead of silently omitting payloads or options. Put the conditional around
complete endpoint declarations or use the manual factory. This is an intentional
syntax restriction, not full conditional-member support. The preferred API
remains `@ProtobufAPIDefinition`; the macro-disabled manual consumer and product
alias remain covered. Runtime module spelling is still `InnoNetworkProtobuf`.

## Fresh validation

The sequential final run uses Xcode 27 / Swift 6.4 and
`INNONETWORK_LOCAL_PATH=/Users/changwooson/Developer/InnoSquad/InnoNetwork-encoded-request`.
This validates the exact local pair, not dependency resolution of an unpublished
core 6.1 tag. Logs and exit results are kept in the core checkout under
`.build/review-fixes-20260930/final-*`; the adapter's focused compiler and
identifier runs remain under its `.build/` directory.

Fresh adapter gates all exited 0:

| Gate | Result |
| --- | --- |
| Complete ordinary and TSAN suites | 43 runtime tests plus two macro expansion tests passed in each run; repeated runs are not counted as unique tests |
| Actual compiler diagnostics | 22 rejected declarations and two passing controls; includes all three new conditional-member failures |
| Executable consumers | Doc smoke, mixed JSON/protobuf consumer and compatibility-product consumer passed |
| Independent macro-off graph | Manual consumer passed; no compiled macro/SwiftSyntax/shared-generator artifacts in its isolated build products |
| Platforms | macOS execution plus applied-macro consumer builds for iOS Simulator, tvOS, watchOS and visionOS passed |
| Documentation and release tools | Docs contract, release negative fixtures and validate-only release gate passed; publish was not invoked |
| Workflow syntax | Actionlint exited 0 with the existing `xcode-27` self-hosted runner label config |

Core final preflight results are recorded in the core's companion remediation
report; the adapter's success is not a substitute for those gates.

The expanded pre-fix review and crash/compile/runtime probes remain under
`.build/deep-review-20260930/` and `.build/macro-review-20260930/`. They establish
the original defects and controls, not final-candidate success. Historical
timing anomalies remain unresolved and their raw evidence is not replaced by a
later passing measurement.

## Deliberate boundaries

No push, PR, remote CI, merge, tag, release, scheduled task or application-source
migration was performed. The original core checkout and generated artifacts,
and the archived JSON performance baseline ref, are preserved. There was no
successful push, so post-push cleanup does not apply.

Xcode 26 is not installed. Published dependency resolution, final-SHA remote CI,
real devices/background restoration, live AWS and dedicated server/IdP/exporter/
FairPlay remain unverified. The optional persistent-cache telemetry bound and
multiple-owner directory contract are not implemented as new features here.
Local regression closure does not prove the absence of all other defects or
make the pair release-ready.
