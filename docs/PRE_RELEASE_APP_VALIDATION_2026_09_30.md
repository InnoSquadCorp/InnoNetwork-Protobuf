# Candidate app validation — 2026-09-30

Status: local device verification complete; final pre-release/remote results pending.
Core input was `7d46c68`, followed by cache telemetry hardening `d1b4d93`.
Adapter input was `35d30a8`; production adapter code is unchanged by the sample.
This is the unpublished core 6.1 / adapter 6.0 pair, not a new 6.0 core release.

## Sample and physical evidence

`Examples/ValidationApp` contains a real iOS app, reusable scenario kit and macOS
CLI. All named requests use `@APIDefinition` or `@ProtobufAPIDefinition`; there is
no mock transport, fake Codable conformance, generated-code copy or SPI client.
The fixture listens only on loopback. HTTP is explicitly enabled for this
diagnostic fixture, not for user credentials or application production traffic.

Fresh macOS CLI cold and second-process warm runs: **7/7 pass each**.
Fresh physical iPhone 14 Pro Max, iOS 27.0.1 (24A446), signed Debug app:
**7/7 pass on cold launch and 7/7 after terminating/relaunching the process**.

| Scenario | Assertion |
| --- | --- |
| JSON macro | Typed payload and exactly one observed socket request |
| Protobuf macro | Binary request echoed and decoded unchanged |
| Retry | First HTTP 503, second HTTP 200, exactly two attempts |
| Response cap | 4 KiB payload rejected by 128-byte limit with code 4003 |
| Cancellation | Cancel after the fixture observes entry; terminal cancelled failure |
| Persistent cache | Cold launch fetches once; second read hits cache; relaunch fetches zero times |
| Telemetry | 63 evictions become one aggregate; draining resets retained totals |

The actual signed device app was installed and launched. Exported synthetic
reports are `device-cold-report.json` and `device-warm-report.json` under the core
checkout's ignored `.build/pre-release-app-20260930/`. The screenshot showed the
sample's green rows but also another app's picture-in-picture overlay. It was
deleted for privacy, not committed or treated as complete UI coverage. No other
app, call, device orientation, signing account or provisioning setting was changed.

Build failures while writing the new sample (an incorrect failure-kind spelling
and an unavailable Cocoa error constant) were fixed in sample code; they were
not library failures. Initial logs remain alongside corrected successful runs.

## Boundaries

Physical loopback requests do not certify TLS/pinning, external routing,
background-session OS restoration, locked-device protection, a production IdP,
exporter, AWS or FairPlay. Those require the target service/entitlements and
scenario-specific acceptance. Full UI interaction/accessibility testing was not
performed. Simulator SDK compilation passed; no simulator execution is claimed.

The cache remains a **single-owner** store, not a concurrently shared App Group
database. Telemetry is now bounded by reason with saturating totals. No ownership
lock, concurrent multi-process cache implementation or public release was added.

Remote CI must be bound to the final pushed revisions. The normal public core
6.1 package dependency cannot resolve until that tag exists. A pinned paired
candidate check is additional evidence only; it must not replace the release
workflow's public-dependency gate or change its `publish: false` default.
