#!/usr/bin/env bash
# Execute the real consumers with both libraries resolved only from remote tags.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:?Expected adapter version}"
expected_sha="${2:?Expected adapter commit}"
[[ "$version" == 6.1.1 && "$expected_sha" =~ ^[0-9a-f]{40}$ ]] || {
  echo 'Expected release 6.1.1 and an exact commit SHA' >&2; exit 64;
}
unset INNONETWORK_LOCAL_PATH
workspace="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/protobuf-published.XXXXXX")"
printf 'Published consumer evidence: %s\n' "$workspace"
cp -R "$root/Examples/ConsumerSmoke" "$workspace/consumer"
# Copy only tracked sample input; inherited build/lock files are not allowed.
[[ ! -e "$workspace/consumer/.build" && ! -e "$workspace/consumer/Package.resolved" ]] || {
  echo 'Consumer source must be clean of build caches and lockfiles' >&2; exit 1;
}
python3 - "$workspace/consumer/Package.swift" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text()
old = '.package(name: "InnoNetwork-Protobuf", path: "../..")'
assert s.count(old) == 1
s = s.replace(old, '.package(url: "https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git", exact: "6.1.1")')
a = s.index('let innoNetworkDependency: Package.Dependency')
b = s.index('let package = Package(', a)
s = s[:a] + 'let innoNetworkDependency: Package.Dependency = .package(url: "https://github.com/InnoSquadCorp/InnoNetwork.git", exact: "6.1.1")\n\n' + s[b:]
assert 'path:' not in s and 'INNONETWORK_LOCAL_PATH' not in s
p.write_text(s)
PY
xcrun swift package --package-path "$workspace/consumer" resolve
ruby -rjson - "$workspace/consumer/Package.resolved" "$version" "$expected_sha" <<'RUBY'
lock = JSON.parse(File.read(ARGV[0]))
pins = lock.fetch('pins')
abort 'Remote-only pins required' unless pins.all? { |p| p['kind'] == 'remoteSourceControl' }
adapters = pins.select { |p| p['identity'] == 'innonetwork-protobuf' }
abort 'Exactly one adapter pin required' unless adapters.length == 1
pin = adapters.first
abort 'Wrong public adapter identity' unless pin['location'] == 'https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git' && pin['state']['version'] == ARGV[1] && pin['state']['revision'] == ARGV[2] && pin['state']['branch'].nil?
puts "Published adapter: PASS #{ARGV[1]} #{ARGV[2]}"
RUBY
ruby "$root/Scripts/check_public_core.rb" "$workspace/consumer/Package.resolved"
xcrun swift run --package-path "$workspace/consumer" ConsumerSmoke
xcrun swift run --package-path "$workspace/consumer" LegacyConsumerSmoke
ruby "$root/Scripts/check_dependency_integrity.rb" "$workspace/consumer/.build" "$workspace/consumer/Package.resolved"
echo 'Remote-only published preferred and compatibility consumers: PASS'
