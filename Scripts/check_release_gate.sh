#!/usr/bin/env bash
set -euo pipefail

# Inputs are data, never interpolated into generated shell source.
mode="${1:-validate}"
tag="${2:-6.1.1}"
version="${tag#v}"
[[ "$mode" == validate || "$mode" == publish ]] || { echo 'Invalid release mode' >&2; exit 64; }
numeric='(0|[1-9][0-9]*)'
prerelease="($numeric|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)"
version_pattern="^$numeric\.$numeric\.$numeric(-$prerelease(\.$prerelease)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"
[[ "$version" =~ $version_pattern ]] || { echo 'Invalid release version' >&2; exit 64; }
notes="docs/releases/$version.md"
[[ -f "$notes" ]] || { echo 'Release notes are required; fallback is forbidden' >&2; exit 1; }
sha="$(git rev-parse --verify HEAD)"
if [[ "$mode" == publish ]]; then
  [[ "$(git cat-file -t "refs/tags/$tag")" == tag ]] || { echo 'An existing annotated tag is required' >&2; exit 1; }
  [[ "$(git rev-parse "refs/tags/$tag^{commit}")" == "$sha" ]] || { echo 'Tag does not match validated SHA' >&2; exit 1; }
  git merge-base --is-ancestor "$sha" refs/remotes/origin/main || { echo 'Release commit must belong to reviewed main' >&2; exit 1; }
  committed_notes="$(git show "$sha:$notes")"
  [[ "$(printf '%s\n' "$committed_notes" | grep -c '^Release-Status:' || true)" == 1 ]] \
    && printf '%s\n' "$committed_notes" | grep -Fxq 'Release-Status: Ready' \
    || { echo 'Committed release notes require one Ready status' >&2; exit 1; }
fi
printf 'Release gate OK: mode=%s version=%s sha=%s\n' "$mode" "$version" "$sha"
