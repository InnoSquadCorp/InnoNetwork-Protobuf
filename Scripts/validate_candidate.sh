#!/usr/bin/env bash
# Shared executable validation used by CI, immutable pairs and release validation.
# This script does not create tags, publish, push, or mutate a dependency checkout.
set -euo pipefail
mode="${1:-standard}"
[[ "$mode" == standard || "$mode" == release ]] || { echo 'Expected standard or release validation' >&2; exit 64; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
xcrun swift package resolve
ruby Scripts/check_dependency_integrity.rb .build Package.resolved
if [[ -n "${INNONETWORK_LOCAL_PATH:-}" ]]; then
  ruby Scripts/check_core_candidate.rb "$INNONETWORK_LOCAL_PATH" .build/workspace-state.json
else
  ruby Scripts/check_public_core.rb Package.resolved
fi
xcrun swift build
xcrun swift test --no-parallel
xcrun swift test --parallel
ruby Scripts/check_macro_compile_failures.rb
bash Scripts/check_docs_contract_sync.sh
xcrun swift run InnoNetworkProtobufDocSmoke
xcrun swift run --package-path Examples/ConsumerSmoke ConsumerSmoke
xcrun swift run --package-path Examples/ConsumerSmoke LegacyConsumerSmoke
bash Scripts/check_macro_disabled_consumer.sh
report_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/protobuf-validation.XXXXXX")"
echo "Retaining synthetic cold/warm evidence at $report_dir"
xcrun swift run --package-path Examples/ValidationApp ValidationCLI "$report_dir"
cp "$report_dir/latest-report.json" "$report_dir/cold.json"
xcrun swift run --package-path Examples/ValidationApp ValidationCLI "$report_dir"
cp "$report_dir/latest-report.json" "$report_dir/warm.json"
for package in . Examples/ConsumerSmoke Examples/ValidationApp; do
  ruby Scripts/check_dependency_integrity.rb "$package/.build" "$package/Package.resolved"
  if [[ -n "${INNONETWORK_LOCAL_PATH:-}" ]]; then
    ruby Scripts/check_core_candidate.rb "$INNONETWORK_LOCAL_PATH" "$package/.build/workspace-state.json"
  else
    ruby Scripts/check_public_core.rb "$package/Package.resolved"
  fi
done
if [[ "$mode" == release ]]; then
  # A fresh scratch path prevents accidentally reusing an unsanitized test executable.
  tsan_path="$(mktemp -d "${TMPDIR:-/tmp}/protobuf-tsan.XXXXXX")"
  xcrun swift test --scratch-path "$tsan_path" --sanitize=thread --parallel
  ruby Scripts/check_dependency_integrity.rb "$tsan_path" Package.resolved
fi
