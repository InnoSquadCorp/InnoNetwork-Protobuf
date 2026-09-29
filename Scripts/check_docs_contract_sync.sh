#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

api_stability="$repo_root/API_STABILITY.md"
readme="$repo_root/README.md"
required_meta_docs=(
  "$repo_root/CONTRIBUTING.md"
  "$repo_root/CODE_OF_CONDUCT.md"
  "$repo_root/SECURITY.md"
  "$repo_root/SUPPORT.md"
  "$repo_root/CHANGELOG.md"
  "$repo_root/docs/RELEASE_POLICY.md"
  "$repo_root/docs/MIGRATION_POLICY.md"
  "$repo_root/docs/ROADMAP.md"
  "$repo_root/docs/releases/6.0.0.md"
  "$repo_root/docs/COMPATIBILITY_6_0.md"
)

fail() {
  echo "docs-contract-sync: $1" >&2
  exit 1
}

has_rg() {
  command -v rg > /dev/null 2>&1
}

require_contains() {
  local needle="$1"
  local file="$2"
  if has_rg; then
    rg -Fq "$needle" "$file" || fail "missing '$needle' in $file"
  else
    grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
  fi
}

require_pattern() {
  local pattern="$1"
  local file="$2"
  if has_rg; then
    rg -Fq "$pattern" "$file" || fail "missing '$pattern' in $file"
  else
    grep -Fq "$pattern" "$file" || fail "missing '$pattern' in $file"
  fi
}

require_contains "## Stable" "$api_stability"
require_contains "## Provisionally Stable" "$api_stability"
require_contains "## Internal/Operational" "$api_stability"

expected_stable=(
'`ProtobufAPIDefinition`'
'`ProtobufNetworkClient`'
'`ProtobufEmptyResponse`'
'`HTTPEmptyResponseMessage`'
'`AnyResponseDecoder.protobuf()`'
'`AnyResponseDecoder.protobufEmptyCapable()`'
)

documented_stable=()
while IFS= read -r line; do
  documented_stable+=("$line")
done < <(
  awk '
    /^## Stable$/ { in_section = 1; next }
    /^## / { if (in_section) exit }
    in_section && /^- / {
      sub(/^- /, "")
      print
    }
  ' "$api_stability"
)

expected_sorted="$(printf '%s\n' "${expected_stable[@]}" | LC_ALL=C sort)"
documented_sorted="$(printf '%s\n' "${documented_stable[@]:-}" | LC_ALL=C sort)"
[[ "$expected_sorted" == "$documented_sorted" ]] || fail "Stable symbol list in API_STABILITY.md does not match expected allowlist"

require_pattern "public protocol ProtobufAPIDefinition" "$repo_root/Sources/InnoNetworkProtobuf/ProtobufAPIDefinition.swift"
require_pattern "var sessionAuthentication: SessionAuthentication { get }" "$repo_root/Sources/InnoNetworkProtobuf/ProtobufAPIDefinition.swift"
require_pattern "public protocol ProtobufNetworkClient" "$repo_root/Sources/InnoNetworkProtobuf/ProtobufNetworkClient.swift"
require_pattern "public struct ProtobufEmptyResponse" "$repo_root/Sources/InnoNetworkProtobuf/ProtobufEmptyResponse.swift"
require_pattern "public protocol HTTPEmptyResponseMessage" "$repo_root/Sources/InnoNetworkProtobuf/EmptyResponseMessage.swift"
require_pattern "static func protobuf()" "$repo_root/Sources/InnoNetworkProtobuf/AnyResponseDecoder+Protobuf.swift"
require_pattern "static func protobufEmptyCapable()" "$repo_root/Sources/InnoNetworkProtobuf/AnyResponseDecoder+Protobuf.swift"

require_contains '# InnoNetwork-Protobuf' "$readme"
require_contains 'https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git' "$readme"
require_contains 'import InnoNetworkProtobuf' "$readme"
require_contains 'name: "InnoNetwork-Protobuf"' "$repo_root/Package.swift"
require_contains 'name: "InnoNetworkProtobuf"' "$repo_root/Package.swift"
require_contains '.product(name: "InnoNetwork-Protobuf", package: "InnoNetwork-Protobuf")' "$readme"
require_contains "InnoNetwork" "$readme"
require_contains "Protocol Buffers" "$readme"
require_contains "protobufRequest" "$readme"
require_contains 'InnoNetwork `6.0.0` is published.' "$readme"
require_contains '.upToNextMajor(from: "6.0.0")' "$repo_root/Package.swift"
require_contains 'INNONETWORK_LOCAL_PATH' "$repo_root/Package.swift"
require_contains 'docs/releases/6.0.0.md' "$readme"
require_contains '## 6.1 Candidates' "$repo_root/docs/ROADMAP.md"

for doc in "${required_meta_docs[@]}"; do
  [[ -f "$doc" ]] || fail "required OSS document is missing: $doc"
done

echo "docs-contract-sync: OK"
