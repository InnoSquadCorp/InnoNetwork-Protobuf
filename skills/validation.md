# Protobuf skill validation — 2026-10-08

The skill is based on remote main and annotated **6.1.1** tag commit
`5e5f8316c94358235c3997e70e5e97aadc11df3a`. The annotated tag object is
`e37446078ad3e3e87e565ca2f1ce539ed75bb39e`. No adapter GitHub Release page was
found at the recorded check. Core 6.1.1 is published at
`44e4ca28c50c03f817231a077c0f3bdfdbc859c8`; the adapter requires that version
exactly. Source skill additions do not change or become part of an existing tag.

Stable support is `>=6.1.0 <6.2.0`, excluding prereleases. The first observed
adapter tag in this range is 6.1.1. Other patches keep their actual resolved
version and need their own manifest/API and consumer checks. This range is not
a claim that every patch exists, passed, or accepts an arbitrary Core 6.1.x.

## Exact remote consumer

```bash
python3 skills/innonetwork-protobuf/scripts/validate_consumer.py --scratch-path /tmp/protobuf-skill-validation
```

The helper copied the fixture outside the skill and passed **14 Swift tests**
on macOS arm64 with Xcode 27 / Swift 6.4, complete strict concurrency and warnings
as errors. It compared all eight remote pins with support metadata, the active
graph/workspace, clean Git checkout identities and SwiftSyntax prebuilt selection.
Manifest/lock and source hashes remained unchanged through validation. The
fixture pins SwiftProtobuf 1.38.1 and SwiftSyntax 604.0.0.

The tests cover macro POST/GET/path/query, wire headers/body and returned values,
HTTP no-content status/body rejection, optional nil versus zero-byte messages,
directional legacy/standard media, strict response media and missing-header opt-in,
request/response quota failures with passing boundaries, retry byte reuse and
encoding per invocation, auth before codec/transport, payload-free decode errors,
unknown-field round-trip and expired operation/closed-client rejection.
Parameterized invocations are not counted as additional test declarations.

A diagnostic copy with an incorrect library SHA was rejected before any Swift
resolve/build command. Skill frontmatter, relative links, Python syntax and
whitespace validation passed. The Python helper uses only the standard library;
the authoring validator's YAML dependency was installed in an external temporary
virtual environment, not bundled into the skill.

## Validator command limits

Each external command has a recorded timeout: 60 seconds for toolchain and Git
checks, 600 seconds for resolution, 120 seconds for the dependency graph and
1,800 seconds for the Swift test/build command. A timeout stops validation with
exit status 1, preserves the command's partial log and records failed
`evidence.json` with `timeout_seconds`, `timed_out: true` and no fabricated
process exit code.

Run the host-independent regression tests with:

```bash
python3 -B -m unittest discover -s Scripts/automation-tests -p test_skill_consumer.py -v
```

These tests simulate successful commands, nonzero exits and timeouts during
toolchain checks, resolution, graph inspection, Git inspection and Swift tests.
They verify that evidence is written and no later command runs after a timeout;
they do not compile Swift or replace the macOS consumer evidence above.

## Source repository checks

- `Scripts/check_static_contracts.sh`: passed, including documentation contracts
  and dependency/candidate/release/workflow guard fixtures.
- Root `swift test --no-parallel`: **68 runtime tests + 2 macro tests** passed.
- `InnoNetworkProtobufDocSmoke`: passed.
- `Examples/ConsumerSmoke` preferred and compatibility-product executables:
  passed, including mixed JSON/protobuf macros, operation and cache recovery.
- Dependency integrity passed for the root and sample graph. The sample uses
  the changed local adapter plus seven remote checkouts; that evidence is distinct
  from the skill fixture's eight remote-only checkouts.

Runtime source, package manifest and production tests are unchanged by this skill.
The machine-readable [consumer evidence](validation/consumer-evidence.json)
records immutable pins, source and log hashes, toolchains and test counts.

These checks do not rerun the complete library release matrix, TSAN, real-socket
loopback, alternate toolchains, mobile/device behavior or later patches. Actual
Codex/Claude selection and code generation are recorded separately in the central
plugin repository. Local checks, remote CI, source merge, library release and
public plugin publication remain separate states.
