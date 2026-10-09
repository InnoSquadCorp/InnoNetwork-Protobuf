# CI impact and cancellation rollout

Baseline: `ba6ab8d6112d51efa69d92ac6739464bfc775aed` (published 6.1.1).
This change is independent of PR #9's skill-validator stdout correction. It
changes no package manifest, public Swift code, version, tag, or release gate.

## Immediate behavior

- Policy unit tests and pinned workflow lint run as two independent GitHub
  native `parallel` children. Their implicit join propagates failures. No SwiftPM
  scratch path or Xcode DerivedData is concurrently shared.
- The static-contract job uses Ubuntu. Its existing build-free Ruby/shell checks
  and independent admission remain intact.
- An ordinary PR can skip compiled documentation only after exact Git content
  proves the *entire* diff is eligible prose (or valid FUNDING data). The policy
  job and final required aggregate independently revalidate base/head proof.
  Fences, inline code, DocC, directives, versions, release/contracts, modes,
  symlinks, renames, binary data, unknown input, and failed Git reads retain the
  existing compiled/full fallback. A `.md` suffix alone is not a prose proof.
- Metadata reuse still accepts only the latest original successful validation
  for the exact PR, head, base, validation labels, native job/check and attempt.
  Regenerated synthetic merge SHAs are equivalent only when both ordered parents
  and the exact resulting tree match. Metadata runs cannot recursively replace
  original validation, conceal newer failed/unknown runs, or renew 24-hour-old
  evidence.

## Product/reverse-dependency scope

`Scripts/ci-product-graph.json` contains the complete local target graph, bound
by the exact Package.swift SHA-256. Conditional macro edges are included
conservatively. Runtime SwiftPM `dump-package` must agree before any narrow
Apple consumer selection. Macro, manifest, dependency, resource, generated,
consumer, automation and unknown changes retain full validation.

`InnoNetwork-Protobuf` and `InnoNetworkProtobuf` both expose the same
`InnoNetworkProtobuf` target. They are aliases, not independent build islands.
A library change therefore affects both public names and MacroPlatformSmoke.
The reviewable plan includes affected tests and their dependency closure, but
`swift test` compilation remains the full package. No `--filter` compile-scope
claim is made.

The optional Apple adapter requires `INNOPROTOBUF_PRODUCT_CI=true`, an ordinary
PR, exact clean head/test-merge identity, ordinary source modes, a reviewed
manifest/graph, a committed Package.resolved, and matching SwiftPM graph. The
repository currently does **not** commit Package.resolved, so it intentionally
runs the original MacroPlatformSmoke command on all four Apple platforms even
if the variable is enabled. Adding a lockfile or activating the variable is
outside this change. With all guards satisfied, unaffected platform consumers
can be skipped with an exact verified receipt; affected consumers retain the
existing SDK/triple and dependency-integrity command. Failed commands never
write success receipts; missing/stale/changed receipts fail verification.

Full public Xcode 26.0.1/27.0 builds and sequential/parallel tests, preferred and
compatibility consumers, immutable paired-candidate validation, main builds,
fresh release validation and release TSAN remain required as before. Main and
release do not reuse a PR-only success. No cache is treated as a test result.

## Job cancellation and metadata observers

`INNO_JOB_CANCELLATION=enabled` opts into per-job cancellation. Unset or malformed
values preserve the original workflow-level behavior. Keys include repository,
workflow, job, PR, base branch, release lane and relevant Xcode/runtime matrix.
Opt-in product workloads additionally include a stable reviewed target/product
partition; missing evidence under-cancels using a run-unique key.

Metadata-only events never cancel validation; aggregate/planner jobs are not
per-job cancellation targets. In opt-in mode the existing verifier retries for
at most 21,000 seconds inside a 360-minute observer job. Each subprocess gets
only the remaining deadline; expiration is failure. With the flag off the
verifier is invoked once behind the existing workflow queue. Neither a timeout
nor a canceled/failed predecessor becomes a synthetic success.

Native concurrency cannot guarantee newer-head-first scheduling if an older
job reaches its group late. This is a documented scheduling limitation, not a
claim of atomic stale-job cancellation.

## Merged PR cleanup activation

The new `pull_request_target: closed` workflow runs only after a merge on the
trusted default branch. It checks out immutable `github.workflow_sha`, never PR
code. Only its dedicated job grants `actions: write`; contents and
pull-requests remain read-only. It opts in with `--apply` and
`CLEANUP_ENABLE_WRITES=enabled`, and activates for merged PR closed events only
after this workflow change reaches the default branch. It inventories only
`ci.yml` pull-request runs in `queued` or `in_progress`, requiring the exact
merged head, branch, native PR association and authoritative API workflow ID.
It rechecks the workflow, PR and run immediately before each cancellation.
Earlier heads, main/default/release branches, manual runs, other PRs/workflows,
completed runs, ambiguous associations and intentional post-merge reruns are
preserved. Reopened/unmerged PRs, mismatched identity/SHA, API errors and
incomplete inventory cannot authorize cancellation.

Standalone CLI execution remains dry-run by default. No settings, repository
variables, credentials or protection rules are changed here. GitHub GET/POST
cancellation cannot be atomic; fresh rechecks reduce but cannot eliminate the
race. Fake API regressions validate the write path without cancelling live runs.

## Verification and acceptance

Local policy, negative and fake-command tests prove admission, selection,
provenance, failure propagation, deadlines and receipt checks. They do not prove
Apple compilation, real GitHub cancellation race freedom, or hosted elapsed-time
savings. The actionlint 1.7.12 archive is checksum verified. Native parallel is
strictly parsed and projected only for the old linter; original YAML is sent to
GitHub unchanged, and unrelated diagnostics remain fatal.

After publication, inspect the exact PR head's native policy/static/required
checks and full Apple matrix. Native-parallel child results and a later metadata
observer should be checked on GitHub before merge. Runtime validation is not
claimed from this Linux editing environment.

References:
- [GitHub native parallel steps](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsparallel)
- [GitHub concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)
- [Router reviewed helper reference](https://github.com/InnoSquadCorp/InnoRouter/commit/cf4c11db653e522fa66066ae64d4ff0dc56b9ffc)
