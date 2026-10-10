# Protobuf replacement PR: local integration evidence

> Historical record — retained for the source, date and environment below.
> For the published 6.1.1 contract, use the [current quick start](../README.md)
> and [documentation map](README.md). Unexecuted checks are not implied passes.


Status: local preparation only; no remote push, PR creation, merge, tag or release.

## Exact inputs

- Main: `ebf1770bb76d19d07d0630787a8e12274707ac19`
- PR #2 implementation: `d4336c3995ccb1645bf564ac47e87d61720f79ba`
- PR #1 reviewed intent: `02f84dc122f1e13d8f2bef5ba363a133693c0573`
- Published Core 6.1.1: `44e4ca28c50c03f817231a077c0f3bdfdbc859c8`
- Current paired Core pin: `44e4ca28c50c03f817231a077c0f3bdfdbc859c8` (published 6.1.1)
- Earlier paired evidence used `91b4b417ca134d0f837f8e000846cd0478e7d439` and is historical

PR #1's implementation is not merged: its low-level API is SPI in published Core,
and PR #2 intentionally deletes the legacy adapter. Its existential consumer
regression intent is implemented against `any EncodedRequestClient`, using both
manual and macro-generated encoded requests in tests and the external consumer.

## Integration decisions

- Retain main's impact-based plan, metadata queue and fixed CI Required gate.
  Include the candidate's Xcode 26/27 matrix and four Apple platform builds in
  the fail-closed aggregate. Static contracts stay independent of builds and
  run for docs changes, but skip metadata-only events through the same exact
  admission expression as CI Plan; metadata reuse retains main's exact checks.
- Retain main's immutable remote tag object/commit verification at both validation
  and publication, and the candidate's explicit opt-in publication, annotated
  tag, reviewed-main ancestry and committed Ready notes. No fallback notes.
  Existing main SemVer/v-prefix support is retained. Version selection is unchanged.
- Normalize equivalent outbound protobuf media types using the response parser,
  without treating response-only legacy tolerance as permission to change the
  outbound profile. Reject duplicates, malformed/unknown parameters and other media.
- Select a pinned local Core in SwiftPM graphs by canonical identity, declared
  name or exact canonical checkout location, then still require exactly one,
  the matching fileSystem state/path, exact clean Git SHA and package root.
  Fixtures include unnamed nested graphs, duplicate local/remote Core and wrong paths.

## Executed in the cloud VM

- `bash Scripts/check_static_contracts.sh`: passed, including 23 Core fixtures,
  34 dependency-integrity fixtures, 12 static workflow fixtures, release gate
  negative controls, isolated Git fixture checks and documentation synchronization.
- `python -B -m unittest discover -s Scripts/automation-tests -v`: 32 passed.
- actionlint 1.7.12: passed after applying only the existing source-position-exact
  `concurrency.queue` compatibility exception in `check-ci-workflows.py`.
- All shell scripts: `bash -n`; all Ruby scripts: `ruby -c`; Git whitespace checks passed.

The workflow inventory fixture is intentionally updated to the integrated
matrix/platform/consumer contract; independent tests assert metadata admission,
fail-closed aggregation, exact release identity and the new integration gates.

## Not executed / required before publication

This Linux VM has no Swift/Xcode installation. Added Swift source is reviewed
but not compiled. No claim of a passing new runtime or remote CI result is made.

1. Resolve the public dependency path with `INNONETWORK_LOCAL_PATH` unset; record
   the resolved Core version and SHA, and confirm 6.1.1 is exercised. Run dependency
   integrity checks for root and consumers. All four manifests now specify `exact: "6.1.1"` by explicit user request.
   The paired checkout pin is the same published commit. No Package.resolved
   file was generated in this VM; the repository ignores those generated files.
2. Run Xcode 26/27 build/tests, serial/parallel and TSAN, macro compiler controls,
   documentation/preferred/compatibility consumers, and the macro-disabled consumer.
3. Run iOS/tvOS/watchOS/visionOS macro builds and actual URLSession loopback cold/warm.
4. Run immutable 6.1.1 paired validation separately, including the final graph checks
   for root, ConsumerSmoke and ValidationApp. The previous remote job failed at
   that final graph check after successful consumers/loopback. The exact failing
   workspace-state artifact was not retained; new fixtures cover the name-free
   graph hypothesis, so real Xcode reproduction remains necessary.
5. Verify published Core 6.1.1's named-security rejection semantics for encoded
   definitions if a consumer adopts `RequestSecurityProviding`. This integration
   does not introduce that API. Core is now pinned exactly to 6.1.1.
6. Check CI on the eventual exact PR head; keep adapter release notes Draft until
   separately authorized release validation is complete.

Historical results from PR #2 are evidence for that old source/Core pair only:
https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/actions/runs/37012891595

## Breaking refinement, local implementation (2026-10-08)

The later user-approved refinement replaces the combined `ProtobufCodingOptions`
with `ProtobufCodecOptions(encoding:decoding:)`, directional options and independent
request/response media policy. Request bytes, response serialized bytes and nesting
limits are named separately; none promises a peak-memory or CPU cap. Protobuf decode
failures now have payload-free categories. Core remains the transport/auth/retry/
cache/cancellation owner, pinned exactly to 6.1.1; no Core source was modified.

HTTP empty responses use `protobufEmptyResponse` and macro `.empty(statusCodes:)`.
The default remains 204/205; other successful status codes require explicit opt-in.
Invalid/duplicate/nonliteral macro status policies and protobuf Empty versus HTTP
EmptyResponse confusion have targeted diagnostics. Decoder options are not applied
to HTTP empty responses.

The macro-off executable now runs a real URLSession loopback echo, schema-empty,
explicit HTTP-empty and invalid-media path via `any EncodedRequestClient`.
Its sample-only socket fixture matches ValidationApp byte-for-byte. The manual
existential unit test is no longer conditional on the Macros trait.

`Scripts/validate_candidate.sh` is the shared execution contract. Public and paired
CI use it, and paired validation is part of CI Required. Both Xcodes validate the
exact release tag through the same script in release mode, which adds isolated
TSAN. Public lockfiles must match both version 6.1.1 and the reviewed tag commit.
Loopback cold/warm JSON reports are uploaded from each matrix job. Existing metadata
queue logic, impact selection, tag-object identity, annotated tag, main ancestry,
Ready notes and explicit publication approval gates remain.

Executed VM evidence for this refinement:
- Python automation: 36 tests passed, including fake-tool shell orchestration and
  failure-stop fixtures. Fake tools are NOT evidence of Swift compilation/runtime.
- Static contracts: 23 Core fixtures, 34 dependency-integrity fixtures, 8 public
  Core pin fixtures, 12 workflow fixtures, release/Git/docs checks passed.
- actionlint 1.7.12 passed with only the existing exact queue compatibility exception.
- Shell/Ruby syntax and Git whitespace checks passed.

Still NOT executed: Swift build/tests, macro expansion/compiler controls, actual
consumer/socket execution, TSAN or Apple platform builds against this new source.
The new Swift regression suite covers directional MIME, response caps, empty status
policy and detailed malformed/depth/required-field errors but remains uncompiled
in this VM. The paired graph fix still needs real SwiftPM/Xcode evidence. New
Package.resolved files were not fabricated. This is a locally prepared candidate,
not a verified releasable build.


## Local cleanup after the deployment plan

The next local pass implements A1–A5 without changing Core or its exact pin.
The malformed 0xff privacy fixture now expects malformedMessage, with a separate
length-delimited truncated case and payload-redaction assertions. A sample-only
ValidationSupport package owns the single loopback implementation. Public consumer
execution is owned by the complete Xcode matrix; the retained Consumer Smoke check
fails unless that matrix succeeds. Docs-only compilation remains independent.
Redundant public/release resolution steps, repeated request assembly and duplicate
Set construction are removed. The standalone deferred encoder validation remains.

Python automation now has 41 tests, including a real shell negative control for
the retained consumer context; all passed in the VM. Static contracts, public
Core pin fixtures, actionlint, shell/Ruby syntax and whitespace checks passed.
These are implementation/static milestones only. The new support package,
factory overloads and corrected Swift fixtures still require actual Xcode builds
and runtime tests. B1 is the next blocked step: this VM has no Swift or xcrun;
starting a new Mac task requires the user's environment/model/effort approval.
