"""Guard cleanup ownership without claiming to execute Swift code."""
from pathlib import Path
import os
import subprocess
import unittest
from test_ci_policy import ROOT, yaml

class LocalCleanupTests(unittest.TestCase):
    def test_one_sample_fixture_and_no_production_dependency(self):
        fixtures=list((ROOT/'Examples').rglob('LoopbackFixture.swift'))
        self.assertEqual(fixtures,[ROOT/'Examples/ValidationSupport/Sources/ProtobufValidationSupport/LoopbackFixture.swift'])
        support=(ROOT/'Examples/ValidationSupport/Package.swift').read_text()
        self.assertNotIn('.package(',support)
        self.assertNotIn('SwiftSyntax',support)
        self.assertNotIn('ProtobufValidationSupport',(ROOT/'Package.swift').read_text())
        for name in ['ManualConsumerSmoke','ValidationApp']:
            manifest=(ROOT/'Examples'/name/'Package.swift').read_text()
            self.assertIn('.package(name: "ProtobufValidationSupport", path: "../ValidationSupport")',manifest)

    def test_exact_error_fixtures_remain_distinct(self):
        source=(ROOT/'Tests/InnoNetworkProtobufTests/ProtobufCoreBoundaryTests.swift').read_text()
        body=source.split('fileprivate func decodingPrivacy',1)[1].split('\n    @Test(',1)[0]
        self.assertIn('truncated ? Data([0x0a, 2, 1]) : Data([0xff])',body)
        self.assertIn('truncated ? .truncatedMessage : .malformedMessage',body)
        self.assertIn('error.code == expected.rawValue',body)
        self.assertIn('response.data.isEmpty',body)

    def test_consumer_context_uses_successful_matrix_and_docs_keep_separate_lane(self):
        jobs=yaml(ROOT/'.github/workflows/ci.yml')['jobs']
        consumer=jobs['consumer-smoke']
        self.assertEqual(consumer['needs'],['ci-plan','build-and-test'])
        self.assertIn('[[ "$PUBLIC_MATRIX_RESULT" == success ]]',consumer['steps'][0]['run'])
        self.assertEqual(consumer['steps'][0]['env']['PUBLIC_MATRIX_RESULT'],'${{ needs.build-and-test.result }}')
        build='\n'.join(s.get('run','') for s in jobs['build-and-test']['steps'])
        self.assertEqual(build.count('validate_candidate.sh'),1)
        self.assertNotIn('swift package resolve',build)
        for step in jobs['docs-contract-sync']['steps']:
            if step.get('name') in ['Resolve dependencies','Build documentation smoke target','Run documentation smoke target']:
                self.assertEqual(step['if'],'${{ !fromJSON(needs.ci-plan.outputs.plan).jobs.build-and-test }}')
        self.assertIn('consumer-smoke',jobs['ci-required']['needs'])

    def test_consumer_context_rejects_every_non_success_parent_result(self):
        step=yaml(ROOT/'.github/workflows/ci.yml')['jobs']['consumer-smoke']['steps'][0]
        for result in ['success','failure','cancelled','skipped','', 'success\n']:
            with self.subTest(result=result):
                run=subprocess.run(['/bin/bash','-e','-c',step['run']],
                                   env={**os.environ,'PUBLIC_MATRIX_RESULT':result},capture_output=True,text=True)
                self.assertEqual(run.returncode == 0,result == 'success')

    def test_factory_assembly_and_media_set_have_single_owners(self):
        source=(ROOT/'Sources/InnoNetworkProtobuf/ProtobufCodec.swift').read_text()
        self.assertEqual(source.count('private static func makeProtobufRequest('),1)
        self.assertEqual(source.count('try makeProtobufRequest('),3)
        self.assertEqual(source.count('Set(media)'),1)
        self.assertIn('try options.validate()',source) # standalone deferred body and response safety remain
