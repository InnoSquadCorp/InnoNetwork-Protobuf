"""Shell orchestration fixtures only: fake tools do not compile or execute Swift."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from test_ci_policy import ROOT, yaml

class CandidateValidationTests(unittest.TestCase):
    def run_fixture(self, mode, fail='', paired=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            scripts.mkdir()
            shutil.copy(ROOT / 'Scripts/validate_candidate.sh', scripts)
            tools = root / 'tools'
            tools.mkdir()
            shim = tools / 'shim'
            shim.write_text('''#!/usr/bin/env python3
import json,os,pathlib,sys
name=pathlib.Path(sys.argv[0]).name
command=name+' '+' '.join(sys.argv[1:])
with open(os.environ['COMMAND_LOG'],'a') as log: log.write(json.dumps(command)+'\\n')
if os.environ.get('FAIL_PATTERN') and os.environ['FAIL_PATTERN'] in command: sys.exit(42)
if name=='xcrun' and 'ValidationCLI' in sys.argv:
    report=pathlib.Path(sys.argv[-1]);report.mkdir(parents=True,exist_ok=True)
    (report/'latest-report.json').write_text('{"passed":true}')
''')
            shim.chmod(0o755)
            for name in ['xcrun', 'ruby', 'bash']:
                (tools / name).symlink_to(shim)
            log = root / 'commands.jsonl'
            env = {**os.environ, 'PATH':str(tools)+os.pathsep+os.environ['PATH'],
                   'COMMAND_LOG':str(log),'FAIL_PATTERN':fail,'RUNNER_TEMP':str(root),'TMPDIR':str(root)}
            if paired: env['INNONETWORK_LOCAL_PATH'] = str(root / 'core')
            else: env.pop('INNONETWORK_LOCAL_PATH',None)
            result = subprocess.run(['/bin/bash',str(scripts / 'validate_candidate.sh'),mode],
                                    env=env,capture_output=True,text=True)
            commands = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, commands

    def test_standard_has_real_consumer_compiler_and_two_loopback_stages(self):
        result, commands = self.run_fixture('standard')
        self.assertEqual(result.returncode,0,result.stderr)
        joined='\n'.join(commands)
        for required in ['swift test --no-parallel','swift test --parallel','check_macro_compile_failures.rb',
                         'ConsumerSmoke','LegacyConsumerSmoke','check_macro_disabled_consumer.sh','check_public_core.rb']:
            self.assertIn(required,joined)
        self.assertEqual(sum('ValidationCLI' in c for c in commands),2)
        self.assertNotIn('--sanitize=thread',joined)

    def test_release_adds_isolated_tsan_and_pair_checks_every_graph(self):
        result, commands = self.run_fixture('release',paired=True)
        self.assertEqual(result.returncode,0,result.stderr)
        sanitizer=[c for c in commands if '--sanitize=thread' in c]
        self.assertEqual(len(sanitizer),1)
        self.assertIn('--scratch-path',sanitizer[0])
        self.assertEqual(sum('check_core_candidate.rb' in c for c in commands),4)
        self.assertFalse(any('check_public_core.rb' in c for c in commands))

    def test_failures_never_become_success_or_continue(self):
        for stage in ['swift test --no-parallel','check_macro_disabled_consumer.sh',
                      'ValidationCLI','check_public_core.rb','--sanitize=thread']:
            with self.subTest(stage=stage):
                result, commands = self.run_fixture('release',fail=stage)
                self.assertEqual(result.returncode,42,result.stderr)
                self.assertIn(stage,commands[-1])
        result,_=self.run_fixture('unsupported')
        self.assertEqual(result.returncode,64)

    def test_workflows_share_contract_and_gate_the_pair(self):
        ci=yaml(ROOT/'.github/workflows/ci.yml')['jobs']
        release=yaml(ROOT/'.github/workflows/release.yml')['jobs']
        self.assertIn('paired-candidate',ci['ci-required']['needs'])
        self.assertEqual(ci['paired-candidate']['needs'],'ci-plan')
        self.assertFalse((ROOT/'.github/workflows/paired-candidate.yml').exists())
        for job in [ci['build-and-test'],ci['paired-candidate'],release['validate-release']]:
            runs='\n'.join(s.get('run','') for s in job['steps'])
            self.assertIn('Scripts/validate_candidate.sh',runs)
        self.assertIn('validate-release',release['publish-release']['needs'])
        self.assertEqual({x['label'] for x in release['validate-release']['strategy']['matrix']['xcode']}, {'26.0.1','27.0'})
        runs='\n'.join(s.get('run','') for s in release['validate-release']['steps'])
        self.assertIn('env -u INNONETWORK_LOCAL_PATH bash Scripts/validate_candidate.sh release',runs)
