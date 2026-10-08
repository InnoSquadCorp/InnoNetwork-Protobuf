# Protobuf replacement PR: local integration evidence

Status: local preparation only; no remote push, PR creation, merge, tag or release.

## Exact inputs

- Main: `ebf1770bb76d19d07d0630787a8e12274707ac19`
- PR #2 implementation: `d4336c3995ccb1645bf564ac47e87d61720f79ba`
- PR #1 reviewed intent: `02f84dc122f1e13d8f2bef5ba363a133693c0573`
- Published Core 6.1.1: `44e4ca28c50c03f817231a077c0f3bdfdbc859c8`
- Historical paired Core pin remains `91b4b417ca134d0f837f8e000846cd0478e7d439`

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
- `python -B -m unittest discover -s Scripts/automation-tests -v`: 31 passed.
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
   integrity checks for root and consumers. The existing `6.1.0..<6.2.0` manifest
   range is unchanged and already admits 6.1.1.
2. Run Xcode 26/27 build/tests, serial/parallel and TSAN, macro compiler controls,
   documentation/preferred/compatibility consumers, and the macro-disabled consumer.
3. Run iOS/tvOS/watchOS/visionOS macro builds and actual URLSession loopback cold/warm.
4. Run historical paired validation separately, including the final graph checks
   for root, ConsumerSmoke and ValidationApp. The previous remote job failed at
   that final graph check after successful consumers/loopback. The exact failing
   workspace-state artifact was not retained; new fixtures cover the name-free
   graph hypothesis, so real Xcode reproduction remains necessary.
5. Verify published Core 6.1.1's named-security rejection semantics for encoded
   definitions if a consumer adopts `RequestSecurityProviding`. This integration
   does not introduce that API or change the adapter's minimum Core requirement.
6. Check CI on the eventual exact PR head; keep adapter release notes Draft until
   separately authorized release validation is complete.

Historical results from PR #2 are evidence for that old source/Core pair only:
https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/actions/runs/37012891595
