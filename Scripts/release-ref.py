"""Bind an existing remote release tag to one immutable tested commit."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

NUMERIC = r'(?:0|[1-9][0-9]*)'
PRERELEASE = rf'(?:{NUMERIC}|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)'
VERSION = re.compile(rf'v?{NUMERIC}\.{NUMERIC}\.{NUMERIC}(?:-{PRERELEASE}(?:\.{PRERELEASE})*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?')
SHA = re.compile(r'[0-9a-f]{40}')


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True, stderr=subprocess.PIPE).strip()


def resolve(root, tag, expected_sha='', expected_tag_object='', require_head=False):
    if not VERSION.fullmatch(tag):
        raise ValueError('release tag must be an exact SemVer tag, optionally v-prefixed')
    for value in (expected_sha, expected_tag_object):
        if value and not SHA.fullmatch(value):
            raise ValueError('expected release identities must be full commit/object SHAs')
    ref = 'refs/tags/' + tag
    def remote():
        lines = git(root, 'ls-remote', '--exit-code', '--tags', 'origin', ref, ref + '^{}').splitlines()
        pairs = [line.split() for line in lines]
        if any(len(pair) != 2 or not SHA.fullmatch(pair[0]) or pair[1] not in {ref, ref + '^{}'} for pair in pairs):
            raise ValueError('malformed remote release refs')
        refs = {name: sha for sha, name in pairs}
        if len(refs) != len(pairs) or ref not in refs:
            raise ValueError('missing or duplicate remote release tag')
        return refs
    before = remote()
    # A same-named branch never participates in release resolution.
    candidate = 'refs/ci-release/candidate'
    git(root, 'fetch', '--no-tags', 'origin', '+' + ref + ':' + candidate)
    tag_object = git(root, 'rev-parse', '--verify', candidate)
    commit = git(root, 'rev-parse', '--verify', candidate + '^{commit}')
    if (tag_object != before[ref] or commit != before.get(ref + '^{}', before[ref]) or remote() != before):
        raise ValueError('remote tag changed while binding release')
    if expected_sha and commit != expected_sha:
        raise ValueError('release commit differs from validated SHA')
    if expected_tag_object and tag_object != expected_tag_object:
        raise ValueError('release tag object differs from validated identity')
    if require_head and git(root, 'rev-parse', 'HEAD') != commit:
        raise ValueError('checkout HEAD differs from validated release commit')
    return dict(tag=tag, commit_sha=commit, tag_object=tag_object)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--expected-sha', default='')
    parser.add_argument('--expected-tag-object', default='')
    parser.add_argument('--require-head', action='store_true')
    args = parser.parse_args()
    try:
        result = resolve(Path.cwd(), args.tag, args.expected_sha, args.expected_tag_object, args.require_head)
        if os.environ.get('GITHUB_OUTPUT'):
            with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
                for key, value in result.items():
                    output.write(f'{key}={value}\n')
        print(json.dumps(result, sort_keys=True))
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print('Release identity rejected: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
