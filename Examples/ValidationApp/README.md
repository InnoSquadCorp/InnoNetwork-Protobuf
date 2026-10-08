# Macro-first network validation app

Standalone diagnostic sample, not a shipping application. Uses the **unpublished
core 6.1 / protobuf 6.0 pair**, real URLSession and a bounded loopback HTTP fixture
on `127.0.0.1:18764`. No mocks, external credentials, third-party endpoint or
blanket ATS exemption. The fixture is not a production server or IdP.

```sh
export INNONETWORK_LOCAL_PATH=/absolute/path/to/InnoNetwork
swift run --package-path Examples/ValidationApp ValidationCLI /tmp/network-validation-unique-run
swift run --package-path Examples/ValidationApp ValidationCLI /tmp/network-validation-unique-run
xcodebuild -project Examples/ValidationApp/NetworkValidation.xcodeproj \
  -scheme NetworkValidation -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/validation-app build CODE_SIGNING_ALLOWED=NO
```

Build from this shell so SwiftPM manifest processes inherit the local override;
GUI launches without that environment require the public core 6.1 tag. Both
dependencies are real local packages, not rewritten/simplified copies.
For a physical iPhone, select its destination and supply your own development
team/signing configuration. Do not commit team identifiers or profiles.

Launch runs seven scenarios: JSON and protobuf macros, 503 retry, response byte
limit, cancellation after actual server admission, persistent response caching,
and bounded eviction telemetry. Relaunch the process without deleting its data:
the cache row must say **Restored previous launch; zero network requests**.
Reports are synthetic and stored in Documents/NetworkValidation/latest-report.json.
CLI reports live under the supplied directory. Use a fresh directory/app container
for cold-start validation. A cache older than one hour deliberately fails the
warm expectation; clear only this sample's data to start a new cold/warm pair.

Only one suite instance may own the fixture port and cache directories. The
button disables during a run; each process shares one actor per active cache.
Different apps/extensions must use distinct cache subdirectories; App Group
URLs do not make the cache a multi-writer database.

This app does **not** validate OS background relaunch, locked-device protection,
entitlements, a live IdP/exporter/AWS service, or FairPlay. The iOS target is 18+
for the sample UI; it does not raise the library's deployment floor.
