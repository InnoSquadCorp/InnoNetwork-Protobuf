#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# An isolated build, not a scan of dependency checkouts or manifests: resolution
# may legitimately download swift-syntax even when its targets are not compiled.
scratch_path="$(mktemp -d "${TMPDIR:-/tmp}/protobuf-no-macros.XXXXXX")"
echo "Retaining trait-off evidence at $scratch_path"
swift run --package-path "$repo_root/Examples/ManualConsumerSmoke" \
  --scratch-path "$scratch_path" ManualConsumerSmoke
ruby "$repo_root/Scripts/check_dependency_integrity.rb" "$scratch_path" \
  "$repo_root/Examples/ManualConsumerSmoke/Package.resolved"
if find "$scratch_path" \( -path "$scratch_path/checkouts" -o -path "$scratch_path/repositories" \
  -o -path "$scratch_path/prebuilts" \) -prune -o \( -name 'SwiftSyntax.swiftmodule' -o -name 'InnoNetworkMacroSupport.swiftmodule' \
  -o -name 'InnoNetworkMacros' -o -name 'InnoNetworkMacros-tool' \
  -o -name 'InnoNetworkProtobufMacros' -o -name 'InnoNetworkProtobufMacros-tool' \) -print | grep -q .; then
  echo 'Compiler-host artifact was built for macro-disabled consumer' >&2
  exit 1
fi
echo 'Macro-disabled consumer graph: PASS'
