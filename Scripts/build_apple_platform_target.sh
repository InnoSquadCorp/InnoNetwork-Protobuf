#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: $0 <runtime> <sdk> <target-triple> [scratch-path]" >&2
  exit 64
fi

runtime="$1"
sdk="$2"
target_triple="$3"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_path="${4:-$repo_root/.build}"

case "$runtime:$sdk:$target_triple" in
  "iOS:iphonesimulator:arm64-apple-ios16.0-simulator" | \
    "tvOS:appletvos:arm64-apple-tvos16.0" | \
    "watchOS:watchos:arm64_32-apple-watchos9.0" | \
    "visionOS:xros:arm64-apple-xros1.0")
    ;;
  *)
    echo "Unsupported Apple platform build tuple: $runtime / $sdk / $target_triple" >&2
    exit 64
    ;;
esac

sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"

xcrun swift build \
  --package-path "$repo_root" \
  --scratch-path "$scratch_path" \
  --triple "$target_triple" \
  --sdk "$sdk_path" \
  --target MacroPlatformSmoke

echo "Built InnoNetworkProtobuf and expanded MacroPlatformSmoke for $runtime ($target_triple)."
