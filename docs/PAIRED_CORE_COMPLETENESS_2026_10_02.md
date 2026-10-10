# Protobuf / Core completeness — 2026-10-02

> Historical record — retained for the source, date and environment below.
> For the published 6.1.1 contract, use the [current quick start](../README.md)
> and [documentation map](README.md). Unexecuted checks are not implied passes.


Status: local development-pair verification, not release readiness.

## Fixed inputs and scope

- Adapter baseline: `4411f763ccfb0af79e6ff3f828399133fef5f0c6` plus this local
  test, documentation and candidate-validation patch.
- Paired Core: `91b4b417ca134d0f837f8e000846cd0478e7d439`, verified on remote
  `codex/core-stream-followup` and PR #141. It extends PR #132 at `7957642` with
  upload terminal/retry ordering; no Protobuf contract, public signature,
  dependency or workflow changes occur in that Core delta.
- Xcode 27.0 (27A266a), Swift 6.4; SwiftProtobuf 1.38.1, SwiftSyntax 603.0.2.
- Scope: paired-revision integrity, macro/manual cache and decoding boundaries,
  executable recovery guidance, consumers and local transport regressions.
  Adapter runtime/public APIs and Core sources are not modified by this work.

The first checks used `7957642`. Once the remote follow-up branch was
confirmed, the pin moved to `91b4b41` and the checks below were rerun against a
separate clean, detached checkout. Earlier results are retained separately and
are not substituted for this pair.

## Changes

The paired workflow now rejects malformed pins, a different or dirty checkout,
and a stale active SwiftPM dependency graph. Twenty fixture cases include
passing controls and wrong/missing/duplicate/remote-substituted dependency
failures. The root package, external consumer and loopback app are each checked
against the same checkout path and exact HEAD.

Six new parameterized regression tests exercise fourteen macro/manual cases:

| Boundary | Assertion / control |
| --- | --- |
| 304 | Binary bytes and media metadata survive validation; subsequent read hits cache |
| Representation | JSON and Protobuf at one URI remain separate; exactly two requests for four reads |
| Cached byte limit | A stricter second caller fails; the original limit still succeeds without transport |
| Transformed byte limit | Both response and decoding interceptors cannot enlarge past the cap; relaxed-cap controls pass |
| Privacy | Malformed-message failure preserves domain/category but removes bytes; a valid next response succeeds |
| Recovery | Invalid cached bytes fail twice with one request; explicit freshness obtains corrected bytes and a later cache hit |

[Cache recovery guidance](CACHE_RECOVERY.md) is backed by a compiled and executed
macro-first external example. A synchronization check rejects divergence between
its documentation block and source. The guide distinguishes validation from
forced body replacement, preserves default headers and avoids automatic retry
loops or claims of automatic decode-failure eviction.

## Fresh local evidence

- All adapter tests: **49 runtime + 2 macro**, separately passing serial,
  parallel and Thread Sanitizer runs. The runtime test binary links the TSAN
  runtime. This is adapter-suite TSAN coverage, not the full Core test suite.
- Actual compiler-plugin controls: **22 rejected declarations + 2 passing controls**.
- Documentation executable, mixed JSON/Protobuf consumer with recovery example,
  compatibility-product consumer, and isolated macro-disabled consumer: pass.
  The macro-disabled build creates no compiler-host macro artifacts.
- Actual URLSession loopback: **7/7 cold + 7/7 second-process warm**. Warm
  persistent-cache restoration makes zero requests for its cache scenario.
- Candidate fixtures (20), release-gate fixtures, document/API contracts,
  workflow actionlint, scoped Swift formatting and whitespace: pass.

An additional dependency-integrity check found stale Git alternate-object paths
from the former `InnoNetworkProtobuf` directory name in the existing build cache
(SwiftCrypto, SwiftProtobuf and SwiftSyntax). Revisions recorded in the lock and
graph agreed, but those cached Git objects could not be validated. This was a
local cache-metadata failure, not an observed runtime test failure. The original
cache was preserved; tests and consumers were rebuilt in fresh scratch paths.
The compiler-control script now accepts `PROTOBUF_VALIDATION_SCRATCH_PATH` so its
plugin and modules can be checked from the same isolated build.

Final logs, cold/warm JSON reports and TSAN linkage use the `clean-*` prefix under
the ignored `.build/paired-completeness-91b4b41/`. The isolated macro-off consumer
also uses a fresh temporary build. Earlier cached runs and `7957642` evidence
remain preserved but are not the final dependency-integrity evidence.

## Remaining boundaries

No remote workflow, push, merge, tag or publication was requested in this phase.
The public dependency remains Core **6.1.x**; the SHA pin is only for development
pair verification and does not replace the public-dependency release gate.
Core integration/release checks and exact-final-adapter-SHA remote CI remain
separate requirements, including Xcode 26 and non-macOS platform checks.

The previous physical-device/platform evidence is historical, not rerun against
this new pair. Current local loopback success does not validate an external TLS
server, IdP, exporter, background OS restoration, locked-device protection or a
production service. No benchmark or full Core preflight is claimed here.
These scoped improvements are not a claim that no further defects can exist.

## Validation-hardening follow-up and repeat-review closure

The follow-up keeps the same adapter HEAD and Core SHA. Its starting tracked
patch SHA-256 was
`0480aeb63f14042f9be262dcb473cf30fa97eaab8f446f988985f2724fc9e286`;
the twelve modified/new input files were recorded separately. This follow-up
changes validation tooling, workflow wiring and documentation only. Runtime,
macro implementation, public API and dependency version requirements are unchanged.

The two confirmed validation defects are addressed:

1. Core-candidate fixtures inherited user Git signing settings and failed before
   exercising the guard. The release fixtures had the same dependency. A shared
   **test-only** helper now isolates configuration, hooks, templates, object format
   and Git environment redirection inside private temporary repositories. It does
   not change user/global Git settings or real-repository signing policy.
2. Documentation-only edits did not reach the paired workflow, while normal CI
   attempted to resolve the unpublished public Core dependency before checking
   documentation. A separate, unfiltered-PR **Static Contracts** job now runs
   without Swift resolution/build. Existing public-dependency jobs, compiled
   documentation checks and publication gates are retained.

The accepted dependency-integrity hardening is now a maintained script, not just
an ignored diagnostic. It checks a bijection between active source-control
dependencies and lockfile pins, source location/state agreement, checkout roots,
HEADs, accessible commit objects and clean sources. It rejects missing/stale or
duplicate entries, substituted local dependencies, unsupported states, path
escapes and Git diagnostics. Package.resolved v2/v3, revision-only and branch
pins have passing controls. It does not repair caches or certify local-package
revisions; the separate Core guard supplies the latter check for the pair.

### Fixed review matrix and evidence

| Area / applicable paths | Closure evidence |
| --- | --- |
| Normal and malformed validation input; dependency source integrity | Fresh 20 Core-pin fixtures and 34 dependency-integrity fixtures, with positive controls after corruption; exact Core and clean package/consumer/app/manual graphs pass |
| Ambient configuration; fixture isolation; resource ownership | Fresh candidate/release/dependency suites under signing, hook, template and Git-path overrides; ambient files unchanged; temporary fixture lifetime is bounded by `mktmpdir` |
| Documentation / CI dispatch / false-green prevention | Fresh 12 workflow fixtures; actual docs drift fails and restored docs pass; static suite succeeds with Swift/Xcode/download commands replaced by failing sentinels |
| Macro-first / manual fallback / public contracts | Fresh actual compiler plugin: 22 rejected declarations plus 2 passing controls; docs, preferred, compatibility and macro-disabled executables pass; runtime/API source diff remains empty |
| Cache / decode errors / freshness / byte limits / privacy | Fresh six parameterized boundary tests covering 14 cases, also repeated five times under TSAN; full adapter suites pass |
| Cancellation / concurrency / retry / terminal observation | Fresh full serial, parallel and TSAN runs each pass 49 runtime + 2 macro tests; TSAN linkage verified; real-socket cancellation and bounded retry pass |
| Restoration / transport / telemetry limits | Fresh loopback 7/7 cold and 7/7 second-process warm; warm persistent cache makes zero requests; bounded telemetry drains correctly |
| CI / release / platforms | Fresh actionlint, Ruby/shell syntax, docs contract and release negative controls pass; remote execution, Xcode 26 and four non-macOS builds are not rerun in this follow-up |

Repeat review added checks for malformed optional checkout-state fields as well
as valid branch/revision pins. Static validation took about eight seconds locally
(not hosted-runner timing). The final static controls are repeated after those
changes. The stop criterion is met: the confirmed defects are fixed, the defined
matrix is closed with evidence or an explicit boundary, and no confirmed
unresolved issue remains within this patch scope. This is not an exhaustive
fresh audit of Core, a proof of no possible defects, or release approval.

Fresh follow-up logs and cold/warm reports are retained under
`.build/validation-hardening-20261002/`; the earlier failure/control logs remain
under `.build/change-review-20261002/`. The old cache with broken alternate-object
paths is preserved as a failing control. No commit, push, remote CI dispatch,
merge, tag or publication was performed during this local-verification phase.
Subsequent PR submission preserves this evidence boundary: a pushed candidate
still needs its own exact-SHA remote checks and separate release approval.
