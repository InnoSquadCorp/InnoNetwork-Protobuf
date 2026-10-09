"""Reviewed graph is conservative and never claims Swift test compile pruning."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'Scripts'/(name+'.py'))
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
p=load('ci-product-impact')
GRAPH=json.loads((ROOT/'Scripts/ci-product-graph.json').read_text())
def dump(graph=GRAPH):
    return {'products':[{'name':n,'targets':t} for n,t in graph['products'].items()],
            'targets':[{'name':n,'type':t['kind'],'path':t['inputs'][0].rstrip('/'),
                        'dependencies':[{'byName':[d,None]} for d in t['dependencies']]} for n,t in graph['targets'].items()]}
class ProductGraphTests(unittest.TestCase):
    def test_manifest_bound_complete_graph(self):
        p.validate(GRAPH)
        self.assertEqual(GRAPH['manifest_sha256'],hashlib.sha256((ROOT/'Package.swift').read_bytes()).hexdigest())
        p.verify_dump(GRAPH,dump())
        self.assertEqual(set(GRAPH['targets']),{'InnoNetworkProtobufMacros','InnoNetworkProtobuf','InnoNetworkProtobufDocSmoke','MacroPlatformSmoke','InnoNetworkProtobufMacroTests','InnoNetworkProtobufTests'})
    def test_two_public_aliases_share_one_native_target(self):
        result=p.select(GRAPH,['Sources/InnoNetworkProtobuf/ProtobufCodec.swift'],GRAPH['manifest_sha256'])
        self.assertEqual(result['mode'],'scoped-build-plan')
        self.assertEqual(set(result['affected_products']),{'InnoNetwork-Protobuf','InnoNetworkProtobuf'})
        self.assertIn('MacroPlatformSmoke',result['affected_targets'])
        self.assertEqual(result['affected_tests'],['InnoNetworkProtobufTests'])
        self.assertEqual(len(result['native_build_commands']),1)
        self.assertEqual(result['test_compilation_scope'],'full package; no --filter compile-scope claim')
        self.assertNotIn('--filter',result['test_command'])
    def test_macro_unknown_manifest_generated_resource_falls_back_full(self):
        for path in ['Sources/InnoNetworkProtobufMacros/Plugin.swift','Package.swift','Package.resolved','Sources/InnoNetworkProtobuf/Generated/x.swift','Sources/InnoNetworkProtobuf/Fixtures/x.swift','Sources/InnoNetworkProtobuf/x.pb.swift','Sources/InnoNetworkProtobuf/Resources/x.swift','Examples/ConsumerSmoke/main.swift','future.md']:
            with self.subTest(path=path):self.assertEqual(p.select(GRAPH,[path])['mode'],'full')
        self.assertEqual(p.select(GRAPH,[])['mode'],'full')
        self.assertEqual(p.select(GRAPH,['Sources/InnoNetworkProtobuf/ProtobufCodec.swift'],'0'*64)['mode'],'full')
    def test_tests_do_not_imply_unaffected_library_changes(self):
        plan=p.select(GRAPH,['Tests/InnoNetworkProtobufTests/ProtobufCodecTests.swift'])
        self.assertEqual(plan['affected_targets'],['InnoNetworkProtobufTests'])
        self.assertEqual(plan['affected_products'],[])
        self.assertEqual(set(plan['test_dependency_products']),set(GRAPH['products']))
    def test_graph_drift_and_cycles_reject(self):
        for change in [lambda g:g['targets']['InnoNetworkProtobuf'].update(dependencies=['missing']),lambda g:g['targets']['InnoNetworkProtobufMacros'].update(dependencies=['InnoNetworkProtobuf']),lambda g:g.update(extra=True),lambda g:g['products'].update(bad=['missing'])]:
            graph=copy.deepcopy(GRAPH);change(graph)
            with self.assertRaises(ValueError):p.validate(graph)
        for change in [lambda d:d['targets'].pop(),lambda d:d['products'].pop(),lambda d:d['targets'][0].update(type='regular'),lambda d:d['targets'][1].update(dependencies=[])]:
            d=dump();change(d)
            with self.assertRaises(ValueError):p.verify_dump(GRAPH,d)
