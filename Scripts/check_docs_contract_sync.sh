#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
for path in README.md API_STABILITY.md SECURITY.md CHANGELOG.md docs/MIGRATION_6_0.md docs/IMPLEMENTATION_6_0.md docs/releases/6.0.0.md docs/COMPATIBILITY_6_0.md; do
  [[ -f "$path" ]] || { echo "Missing $path" >&2; exit 1; }
done
for section in Stable 'Provisionally Stable' Internal/Operational; do
  grep -Fxq "## $section" API_STABILITY.md
done
expected_stable=(
  'ProtobufMediaType'
  'ProtobufEncodingOptions'
  'ProtobufDecodingOptions'
  'ProtobufCodecOptions'
  'ProtobufDecodingFailure'
  'EncodedRequest.protobuf(method:path:auth:body:codec:options:)'
  'EncodedRequest.protobuf(method:path:auth:codec:options:)'
  'EncodedRequest.protobufEmptyResponse(method:path:auth:body:encoding:statusCodes:options:)'
  'EncodedRequest.protobufEmptyResponse(method:path:auth:encoding:statusCodes:options:)'
  'EncodedRequestBody.protobuf(_:options:)'
  'AnyResponseDecoder.protobuf(options:)'
)
documented_stable="$(awk '/^## Stable$/ { active=1; next } /^## / { active=0 } active && /^- `/ { sub(/^- `/, ""); sub(/`$/, ""); print }' API_STABILITY.md | sort)"
[[ "$documented_stable" == "$(printf '%s\n' "${expected_stable[@]}" | sort)" ]] \
  || { echo 'Stable ledger differs from reviewed codec surface' >&2; exit 1; }
[[ "$(grep -c 'static func protobuf' Sources/InnoNetworkProtobuf/ProtobufCodec.swift)" == 7 ]] \
  || { echo 'Expected five request factories, body encoder and response decoder' >&2; exit 1; }
for manifest in Package.swift Examples/ConsumerSmoke/Package.swift Examples/ManualConsumerSmoke/Package.swift Examples/ValidationApp/Package.swift; do
  grep -Fq 'exact: "6.1.1"' "$manifest"
done
grep -Fxq '44e4ca28c50c03f817231a077c0f3bdfdbc859c8' .github/core-candidate.sha
grep -Fq 'exact: "6.1.1"' README.md
grep -Fq 'from: "1.38.1"' Package.swift
grep -Fq 'traits: []' Package.swift
grep -Fq 'traits: []' Examples/ManualConsumerSmoke/Package.swift
grep -Fq '.default(enabledTraits: ["Macros"])' Package.swift
grep -Fq 'public macro ProtobufAPIDefinition' Sources/InnoNetworkProtobuf/ProtobufAPIDefinition+Macro.swift
grep -Fq '@ProtobufAPIDefinition' Examples/ConsumerSmoke/Sources/ConsumerSmoke/main.swift
grep -Fq '@APIDefinition' Examples/ConsumerSmoke/Sources/ConsumerSmoke/main.swift
grep -Fq 'import InnoNetworkProtobuf' README.md
grep -Fq 'https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git' README.md
grep -Fq 'Release-Status:' docs/releases/6.0.0.md
grep -Fq '**unpublished, breaking 6.0 development line**' README.md
grep -Fq 'Historical evidence for the superseded SPI adapter' docs/COMPATIBILITY_6_0.md
if grep -ERn '@_spi|protocol ProtobufAPIDefinition|ProtobufNetworkClient|ProtobufEmptyResponse|HTTPEmptyResponseMessage|protobufEmptyCapable' Sources SmokeTests Examples/ConsumerSmoke/Sources; then
  echo 'Removed runtime surface or SPI reintroduced' >&2; exit 1
fi
for symbol in ProtobufEncodingOptions ProtobufDecodingOptions ProtobufCodecOptions ProtobufDecodingFailure ProtobufMediaType; do
  grep -Fq "public $(if [[ "$symbol" == ProtobufMediaType || "$symbol" == ProtobufDecodingFailure ]]; then echo enum; else echo struct; fi) $symbol" Sources/InnoNetworkProtobuf/ProtobufCodec.swift
  grep -Fq "\`$symbol\`" API_STABILITY.md
done
ruby -e '
  source = File.read("Examples/ConsumerSmoke/Sources/ConsumerSmoke/CacheRecovery.swift")
  examples = source.scan(/^\/\/ BEGIN CACHE_RECOVERY_EXAMPLE\n(.*?)^\/\/ END CACHE_RECOVERY_EXAMPLE$/m)
  documented = File.read("docs/CACHE_RECOVERY.md").scan(/```swift\n(.*?)```/m)
  abort "Cache recovery documentation differs from the executable consumer" unless examples.length == 1 && documented == examples
'
echo 'docs-contract-sync: OK'

# One shared fixture implementation is used only by validation packages.
[[ "$(find Examples -name LoopbackFixture.swift | wc -l | tr -d ' ')" == 1 ]]
[[ -f Examples/ValidationSupport/Sources/ProtobufValidationSupport/LoopbackFixture.swift ]]
for manifest in Examples/ManualConsumerSmoke/Package.swift Examples/ValidationApp/Package.swift; do
  grep -Fq '.package(name: "ProtobufValidationSupport", path: "../ValidationSupport")' "$manifest"
done
