"""Real Git controls for tag, tested checkout and remote publication identity."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('release_ref', ROOT / 'Scripts/release-ref.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class ReleaseIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
        environment.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                           GIT_AUTHOR_NAME='Release Fixture', GIT_COMMITTER_NAME='Release Fixture',
                           GIT_AUTHOR_EMAIL='fixture@example.invalid', GIT_COMMITTER_EMAIL='fixture@example.invalid')
        patch = mock.patch.dict(os.environ, environment, clear=True)
        patch.start(); self.addCleanup(patch.stop)
        self.git('init', '-q', '-b', 'main')
        self.git('commit', '--allow-empty', '-qm', 'A')
        self.a = self.git('rev-parse', 'HEAD')
        self.git('tag', '-a', '3.0.1', '-m', 'tag A')
        self.git('init', '--bare', '-q', 'remote.git')
        self.git('remote', 'add', 'origin', str(self.root / 'remote.git'))
        self.git('push', '-q', 'origin', 'refs/tags/3.0.1')

    def git(self, *args):
        return p.git(self.root, *args)

    def test_same_tag_and_commit_pass_before_and_after_validation(self):
        binding = p.resolve(self.root, '3.0.1')
        self.assertEqual(binding['commit_sha'], self.a)
        self.assertEqual(p.resolve(self.root, '3.0.1', self.a, binding['tag_object'], True), binding)
        self.git('tag', 'v3.0.2')
        self.git('push', '-q', 'origin', 'refs/tags/v3.0.2')
        self.assertEqual(p.resolve(self.root, 'v3.0.2')['commit_sha'], self.a)

    def test_tag_move_and_same_commit_retag_are_rejected(self):
        binding = p.resolve(self.root, '3.0.1')
        self.git('tag', '-f', '-a', '3.0.1', '-m', 'changed annotation')
        self.git('push', '-q', '--force', 'origin', 'refs/tags/3.0.1')
        with self.assertRaisesRegex(ValueError, 'tag object'):
            p.resolve(self.root, '3.0.1', self.a, binding['tag_object'])
        self.git('commit', '--allow-empty', '-qm', 'B')
        self.git('tag', '-f', '-a', '3.0.1', '-m', 'tag B')
        self.git('push', '-q', '--force', 'origin', 'refs/tags/3.0.1')
        with self.assertRaisesRegex(ValueError, 'validated SHA'):
            p.resolve(self.root, '3.0.1', self.a)

    def test_wrong_checkout_and_branch_only_version_are_rejected(self):
        self.git('commit', '--allow-empty', '-qm', 'B')
        with self.assertRaisesRegex(ValueError, 'checkout HEAD'):
            p.resolve(self.root, '3.0.1', self.a, require_head=True)
        self.git('branch', '3.0.2')
        self.git('push', '-q', 'origin', 'refs/heads/3.0.2')
        with self.assertRaises(subprocess.CalledProcessError): p.resolve(self.root, '3.0.2')
        # A same-named branch cannot redirect an existing tag.
        self.git('branch', '3.0.1')
        self.git('push', '-q', 'origin', 'refs/heads/3.0.1')
        self.assertEqual(p.resolve(self.root, '3.0.1')['commit_sha'], self.a)

    def test_invalid_version_and_deleted_remote_tag_fail_closed(self):
        for tag in ['3.01.0', '3.0.1-01', '../main', 'refs/heads/main', '3.0.1\nkey=value', '$(touch owned)']:
            with self.subTest(tag=tag), self.assertRaises(ValueError): p.resolve(self.root, tag)
        self.git('push', '-q', 'origin', ':refs/tags/3.0.1')
        with self.assertRaises(subprocess.CalledProcessError): p.resolve(self.root, '3.0.1')

    def test_workflow_carries_preflight_identity_through_both_jobs(self):
        from test_ci_policy import yaml
        jobs = yaml(ROOT / '.github/workflows/release.yml')['jobs']
        self.assertEqual(jobs['validate-release']['needs'], 'resolve-release')
        self.assertEqual(set(jobs['publish-release']['needs']), {'resolve-release', 'validate-release'})
        for name in ['validate-release', 'publish-release']:
            steps = jobs[name]['steps']
            checkout = next(s for s in steps if s.get('name') == 'Checkout')
            self.assertEqual(checkout['with']['ref'], '${{ needs.resolve-release.outputs.commit_sha }}')
            policy = next(s for s in steps if s.get('name') == 'Checkout immutable identity policy')
            self.assertEqual(policy['with']['ref'], '${{ github.workflow_sha }}')
            verify = next(s for s in steps if s.get('name') == 'Verify exact release identity')
            self.assertIn('--require-head', verify['run'])
            self.assertEqual(verify['env']['RELEASE_TAG_OBJECT'], '${{ needs.resolve-release.outputs.tag_object }}')
        steps = jobs['publish-release']['steps']
        self.assertEqual(steps[-2]['name'], 'Verify exact release identity')
        self.assertEqual(steps[-1]['with']['target_commitish'], '${{ needs.resolve-release.outputs.commit_sha }}')
