#!/usr/bin/env python3
"""Conservative opt-in Apple consumer selection, never test compilation filtering.

Both public product names alias the same module. With no committed lockfile the
current package always takes the original full Apple macro-consumer recipe.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
_spec = importlib.util.spec_from_file_location('product_impact', Path(__file__).with_name('ci-product-impact.py'))
impact = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(impact)
SHA = re.compile(r'[0-9a-f]{40}')


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True, stderr=subprocess.PIPE).strip()


def regular_source_diff(root, base, head):
    # A suffix alone cannot admit symlinks, executable modes or unresolved/type
    # changes into a narrow source build. Parse Git's NUL-framed raw records.
    raw = subprocess.check_output(['git', '-C', str(root), 'diff', '--raw', '--no-abbrev',
                                   '--no-renames', '-z', base+'...'+head], stderr=subprocess.PIPE)
    fields = raw.decode('utf-8', errors='strict').split('\0')
    if fields.pop() != '' or len(fields) % 2:
        raise ValueError('malformed source mode evidence')
    for descriptor, path in zip(fields[::2], fields[1::2]):
        match = re.fullmatch(r':(100644|000000) (100644|000000) [0-9a-f]{40} [0-9a-f]{40} ([AMD])', descriptor)
        if not match or not path:
            raise ValueError('nonregular/executable/type-changed source requires full builds')


def identity(root):
    sha = git(root, 'rev-parse', 'HEAD')
    if not SHA.fullmatch(sha): raise ValueError('invalid checkout SHA')
    return sha


def admit(root, env, check_output=subprocess.check_output):
    root = Path(root).resolve()
    sha = identity(root)
    base = {'mode': 'full', 'reason': 'product rollout disabled or non-PR event', 'sha': sha,
            'base': None, 'head': None, 'products': [], 'targets': [], 'affected_targets': [], 'graph_sha256': None,
            'manifest_sha256': hashlib.sha256((root/'Package.swift').read_bytes()).hexdigest()}
    if env.get('PRODUCT_SCOPE_ENABLED') != 'true' or env.get('GITHUB_EVENT_NAME') != 'pull_request':
        return base
    try:
        if env.get('INNONETWORK_LOCAL_PATH'):
            raise ValueError('paired dependency validation stays full')
        event = json.loads(Path(env['GITHUB_EVENT_PATH']).read_text())
        pr = event['pull_request']
        if event.get('action') not in ('opened', 'synchronize', 'reopened', 'edited', 'labeled', 'unlabeled'):
            raise ValueError('unrecognized PR action')
        labels = pr['labels']
        if not isinstance(labels, list) or any(not isinstance(x, dict) or not isinstance(x.get('name'), str) for x in labels):
            raise ValueError('invalid PR labels')
        author = pr['user']['login']
        if not isinstance(author, str) or not author or author == 'dependabot[bot]' or any(x['name'].lower() == 'release-validation' for x in labels):
            raise ValueError('bot/release validation stays full')
        if event['action'] == 'edited' and not event.get('changes', {}).get('base'):
            raise ValueError('metadata event cannot select build scope')
        if env.get('GITHUB_SHA') != sha:
            raise ValueError('checkout is not exact event candidate')
        base_sha, head_sha = pr['base']['sha'], pr['head']['sha']
        if not all(SHA.fullmatch(x or '') for x in (base_sha, head_sha)):
            raise ValueError('missing exact PR anchors')
        # GitHub PR builds use either the exact head or its exact two-parent
        # test merge. Never project a scope onto a different checkout tree.
        parents = git(root, 'show', '-s', '--format=%P', sha).split()
        if sha != head_sha and parents != [base_sha, head_sha]:
            raise ValueError('candidate does not match PR head or exact merge parents')
        if git(root, 'status', '--porcelain', '--untracked-files=no'):
            raise ValueError('tracked checkout changed before scope admission')
        graph_path = root/'Scripts/ci-product-graph.json'
        graph = json.loads(graph_path.read_text())
        roots = sorted({entry['path'] if 'path' in entry else value.rstrip('/')
                        for entry in graph['targets'].values()
                        for value in entry.get('inputs', [entry.get('path', '')])} |
                       {entry['path'] for entry in graph.get('consumers', {}).values()})
        if subprocess.check_output(['git', '-C', str(root), 'ls-files', '--others', '--exclude-standard', '--', *roots]):
            raise ValueError('untracked source/resource/consumer input requires full validation')
        impact.validate(graph)
        if graph['manifest_sha256'] != base['manifest_sha256']:
            raise ValueError('manifest graph drift')
        paths = impact.diff_paths(root, base_sha, head_sha)
        regular_source_diff(root, base_sha, head_sha)
        plan = impact.select(graph, paths, base['manifest_sha256'])
        if plan['mode'] != 'scoped-build-plan':
            raise ValueError('shared/unknown change requires full builds')
        if not (root/'Package.resolved').is_file():
            raise ValueError('missing committed dependency lock')
        git(root, 'ls-files', '--error-unmatch', 'Package.resolved')
        # SwiftPM itself verifies the reviewed map before any narrow execution.
        # dump-package does not build/test, and no manifest is modified.
        dump = json.loads(check_output(['xcrun', 'swift', 'package', '--package-path', str(root), 'dump-package'], text=True))
        impact.verify_dump(graph, dump)
        return {**base, 'mode': 'scoped', 'reason': 'exact PR graph verified by SwiftPM',
                'base': base_sha, 'head': head_sha, 'products': plan['affected_products'],
                'affected_targets': plan['affected_targets'],
                'targets': sorted({name for product in plan['affected_products'] for name in graph['products'][product]}),
                'graph_sha256': hashlib.sha256(graph_path.read_bytes()).hexdigest()}
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as error:
        return {**base, 'reason': 'full fallback: '+str(error)}


PLATFORMS = {
    'iOS': ('iphonesimulator', 'arm64-apple-ios16.0-simulator'),
    'tvOS': ('appletvos', 'arm64-apple-tvos16.0'),
    'watchOS': ('watchos', 'arm64_32-apple-watchos9.0'),
    'visionOS': ('xros', 'arm64-apple-xros1.0'),
}


def recipe(root, admission, platform):
    root = Path(root).resolve()
    if platform not in PLATFORMS:
        raise ValueError('unreviewed Apple platform')
    if admission['mode'] == 'scoped' and 'MacroPlatformSmoke' not in admission['affected_targets']:
        return {'decision': 'skip-unaffected', 'commands': []}
    sdk, triple = PLATFORMS[platform]
    return {'decision': 'run-full' if admission['mode'] == 'full' else 'run-selected-consumer',
            'commands': [['bash', str(root/'Scripts/build_apple_platform_target.sh'), platform, sdk, triple]]}


def expected(root, env, platform, check_output=subprocess.check_output):
    admission = admit(root, env, check_output)
    return {'schema': 1, 'platform': platform, 'admission': admission, **recipe(root, admission, platform),
            'result': 'success', 'test_scope': 'unchanged full test gates; no --filter compilation claim'}


def execute(root, env, platform, receipt, run=subprocess.run, check_output=subprocess.check_output):
    receipt = Path(receipt)
    if receipt.exists():
        raise ValueError('receipt already exists; stale success cannot be reused')
    proof = expected(root, env, platform, check_output)
    for command in proof['commands']:
        run(command, cwd=root, check=True)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    with receipt.open('x') as stream:
        json.dump(proof, stream, sort_keys=True); stream.write('\n')
    print(json.dumps(proof, sort_keys=True))
    return proof


def verify(root, env, platform, receipt, check_output=subprocess.check_output):
    proof = json.loads(Path(receipt).read_text())
    if proof != expected(root, env, platform, check_output):
        raise ValueError('unexplained build skip, stale receipt, or changed exact plan')
    print('Verified exact Apple consumer build/skip receipt for ' + platform)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('build', 'verify'))
    parser.add_argument('--root', type=Path, default=Path('.'))
    parser.add_argument('--platform', choices=tuple(PLATFORMS), required=True)
    parser.add_argument('--receipt', type=Path, required=True)
    args = parser.parse_args()
    if args.action == 'build':
        execute(args.root.resolve(), os.environ, args.platform, args.receipt)
    else:
        verify(args.root.resolve(), os.environ, args.platform, args.receipt)

if __name__ == '__main__':
    main()
