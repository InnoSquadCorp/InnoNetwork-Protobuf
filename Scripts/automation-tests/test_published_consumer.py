"""Remote-consumer shell/identity fixtures; no Swift compilation is performed."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from test_ci_policy import ROOT, yaml

class PublishedConsumerTests(unittest.TestCase):
    def fixture(self, failure='', wrong_pin='' , dirty=False):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'Scripts').mkdir()
            for name in ['validate_published_consumer.sh','check_public_core.rb']:
                shutil.copy(ROOT/'Scripts'/name,root/'Scripts')
            shutil.copytree(ROOT/'.github',root/'.github')
            source=root/'Examples/ConsumerSmoke';source.mkdir(parents=True)
            shutil.copy(ROOT/'Examples/ConsumerSmoke/Package.swift',source)
            if dirty: (source/'Package.resolved').write_text('{}')
            tools=root/'tools';tools.mkdir()
            (tools/'xcrun').write_text('''#!/usr/bin/env python3
import json,os,pathlib,sys
assert 'INNONETWORK_LOCAL_PATH' not in os.environ
args=sys.argv[1:]
with open(os.environ['COMMAND_LOG'],'a') as f: f.write(' '.join(args)+'\\n')
if os.environ['FAIL_PATTERN'] and os.environ['FAIL_PATTERN'] in ' '.join(args): sys.exit(42)
p=pathlib.Path(args[args.index('--package-path')+1])
s=(p/'Package.swift').read_text()
assert 'path:' not in s and 'INNONETWORK_LOCAL_PATH' not in s
if 'resolve' in args:
 pins=[]
 for name,repo,sha in [('innonetwork','InnoNetwork','44e4ca28c50c03f817231a077c0f3bdfdbc859c8'),('innonetwork-protobuf','InnoNetwork-Protobuf',('b' if os.environ['WRONG_PIN']=='adapter' else 'a')*40)]:
  pins.append({'identity':name,'kind':'remoteSourceControl','location':'https://github.com/InnoSquadCorp/'+repo+'.git','state':{'version':'6.1.1','revision':sha}})
 if os.environ['WRONG_PIN']=='core': pins[0]['state']['revision']='b'*40
 if os.environ['WRONG_PIN']=='missing': pins.pop()
 if os.environ['WRONG_PIN']=='duplicate': pins.append(pins[-1])
 (p/'Package.resolved').write_text(json.dumps({'version':3,'pins':pins}))
''')
            ruby=shutil.which('ruby');self.assertIsNotNone(ruby,'Ruby required for identity fixtures')
            (tools/'ruby').write_text('''#!/bin/bash
if [[ "$1" == *check_dependency_integrity.rb ]]; then
 echo integrity >> "$COMMAND_LOG"
 exit 0
fi
exec "$REAL_RUBY" "$@"
''')
            for p in tools.iterdir():p.chmod(0o755)
            log=root/'commands'
            env={**os.environ,'PATH':str(tools)+os.pathsep+os.environ['PATH'],'REAL_RUBY':ruby,
                 'COMMAND_LOG':str(log),'FAIL_PATTERN':failure,'WRONG_PIN':wrong_pin,
                 'RUNNER_TEMP':str(root),'INNONETWORK_LOCAL_PATH':'must-be-unset'}
            result=subprocess.run(['/bin/bash',str(root/'Scripts/validate_published_consumer.sh'),'6.1.1','a'*40],env=env,capture_output=True,text=True)
            return result,log.read_text() if log.exists() else ''

    def test_exact_remote_identity_and_both_products(self):
        result,log=self.fixture()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('Published adapter: PASS',result.stdout)
        self.assertIn('Published Core: PASS',result.stdout)
        self.assertIn('ConsumerSmoke',log);self.assertIn('LegacyConsumerSmoke',log)
        self.assertTrue(log.endswith('integrity\n'))

    def test_fail_closed(self):
        for kwargs in [{'failure':'resolve'},{'failure':'ConsumerSmoke'},{'failure':'LegacyConsumerSmoke'},{'wrong_pin':'adapter'},{'wrong_pin':'core'},{'wrong_pin':'missing'},{'wrong_pin':'duplicate'},{'dirty':True}]:
            with self.subTest(kwargs=kwargs):
                result,log=self.fixture(**kwargs)
                self.assertNotEqual(result.returncode,0)
                self.assertNotIn('integrity',log)
        result,_=self.fixture();self.assertEqual(result.returncode,0)

    def test_runs_only_after_publication_on_exact_commit(self):
        job=yaml(ROOT/'.github/workflows/release.yml')['jobs']['published-consumer']
        self.assertEqual(job['needs'],['resolve-release','publish-release'])
        self.assertIn('inputs.publish',job['if'])
        self.assertEqual(job['permissions'],{'contents':'read'})
        self.assertEqual(job['steps'][0]['with']['ref'],'${{ needs.resolve-release.outputs.commit_sha }}')
