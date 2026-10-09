"""Exact-Git admission and fake command receipts, not real Apple build evidence."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from test_ci_product_impact import ROOT, GRAPH, dump, load
p=load('ci_product_execution')
class ProductExecutionTests(unittest.TestCase):
    def setUp(self):
        tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);self.root=Path(tmp.name)
        self.env={**os.environ,'GIT_AUTHOR_NAME':'Fixture','GIT_COMMITTER_NAME':'Fixture','GIT_AUTHOR_EMAIL':'ci@example.invalid','GIT_COMMITTER_EMAIL':'ci@example.invalid'}
        self.git('init','-q','-b','main')
        (self.root/'Scripts').mkdir();shutil.copyfile(ROOT/'Package.swift',self.root/'Package.swift');shutil.copyfile(ROOT/'Scripts/ci-product-graph.json',self.root/'Scripts/ci-product-graph.json')
        (self.root/'Package.resolved').write_text('{}\n');self.base=self.commit()
        self.write('Sources/InnoNetworkProtobuf/ProtobufCodec.swift','struct Codec {}\n');self.head=self.commit();self.event={'action':'synchronize','pull_request':{'base':{'sha':self.base},'head':{'sha':self.head},'user':{'login':'contributor'},'labels':[]}}
        self.event_path=self.root/'.git/event.json';self.sync_event();self.env.update(GITHUB_EVENT_NAME='pull_request',GITHUB_SHA=self.head,PRODUCT_SCOPE_ENABLED='true',GITHUB_EVENT_PATH=str(self.event_path))
    def git(self,*args):return subprocess.check_output(['git','-C',str(self.root),'-c','commit.gpgsign=false',*args],text=True,env=self.env).strip()
    def commit(self):self.git('add','-A');self.git('commit','-qm','fixture');return self.git('rev-parse','HEAD')
    def write(self,path,text):
        path=self.root/path;path.parent.mkdir(exist_ok=True,parents=True);path.write_text(text)
    def sync_event(self):self.event_path.write_text(json.dumps(self.event))
    def fake_dump(self,*args,**kwargs):return json.dumps(dump())
    def admit(self,**env):return p.admit(self.root,{**self.env,**env},self.fake_dump)
    def test_scoped_library_includes_platform_consumer_and_both_product_names(self):
        a=self.admit();self.assertEqual(a['mode'],'scoped');self.assertEqual(set(a['products']),set(GRAPH['products']))
        for platform,tuple_ in p.PLATFORMS.items():
            r=p.recipe(self.root,a,platform);self.assertEqual(r['decision'],'run-selected-consumer');self.assertEqual(r['commands'][0][2:],[platform,*tuple_])
    def test_default_nonpr_release_bot_and_paired_keep_original_recipe(self):
        for env in [{'PRODUCT_SCOPE_ENABLED':''},{'GITHUB_EVENT_NAME':'push'},{'GITHUB_EVENT_NAME':'workflow_dispatch'},{'GITHUB_SHA':'f'*40},{'INNONETWORK_LOCAL_PATH':'/paired'}]:
            with self.subTest(env=env):self.assertEqual(self.admit(**env)['mode'],'full')
        for key,value in [('labels',[{'name':'RELEASE-VALIDATION'}]),('user',{'login':'dependabot[bot]'})]:
            old=self.event['pull_request'][key];self.event['pull_request'][key]=value;self.sync_event();self.assertEqual(self.admit()['mode'],'full');self.event['pull_request'][key]=old
    def test_missing_lock_dump_drift_dirty_and_untracked_inputs_fall_back(self):
        self.git('rm','Package.resolved');self.head=self.commit();self.env['GITHUB_SHA']=self.head;self.event['pull_request']['head']['sha']=self.head;self.sync_event();self.assertEqual(self.admit()['mode'],'full')
        self.git('reset','--hard',self.event['pull_request']['base']['sha'])
        self.assertEqual(self.admit()['mode'],'full')
    def test_dirty_tracked_and_untracked_build_inputs_require_full(self):
        path=self.root/'Sources/InnoNetworkProtobuf/ProtobufCodec.swift';path.write_text('dirty\n');self.assertEqual(self.admit()['mode'],'full')
        self.git('checkout','--',str(path));self.write('Sources/InnoNetworkProtobuf/other.swift','struct Extra {}\n');self.assertEqual(self.admit()['mode'],'full')
    def test_dump_error_or_graph_drift_never_skips(self):
        def bad(*args,**kwargs):return '{}'
        self.assertEqual(p.admit(self.root,self.env,bad)['mode'],'full')
        graph=copy.deepcopy(GRAPH);graph['manifest_sha256']='0'*64;(self.root/'Scripts/ci-product-graph.json').write_text(json.dumps(graph));self.assertEqual(self.admit()['mode'],'full')
    def test_test_only_may_skip_only_after_exact_locked_graph_proof(self):
        self.git('reset','--hard',self.base);self.write('Tests/InnoNetworkProtobufTests/Test.swift','import Testing\n');head=self.commit();self.env['GITHUB_SHA']=head;self.event['pull_request']['head']['sha']=head;self.sync_event()
        a=self.admit();self.assertEqual(a['mode'],'scoped');self.assertEqual(p.recipe(self.root,a,'iOS'),{'decision':'skip-unaffected','commands':[]})
        receipt=self.root/'receipt.json';p.execute(self.root,self.env,'iOS',receipt,check_output=self.fake_dump);p.verify(self.root,self.env,'iOS',receipt,check_output=self.fake_dump)
    def test_success_failure_stale_and_tampered_receipts(self):
        calls=[]
        def run(command,**kwargs):calls.append(command);self.assertTrue(kwargs['check'])
        receipt=self.root/'receipt.json';proof=p.execute(self.root,self.env,'iOS',receipt,run=run,check_output=self.fake_dump);self.assertEqual(len(calls),1);p.verify(self.root,self.env,'iOS',receipt,check_output=self.fake_dump)
        with self.assertRaises(ValueError):p.execute(self.root,self.env,'iOS',receipt,run=run,check_output=self.fake_dump)
        proof['commands']=[];receipt.write_text(json.dumps(proof))
        with self.assertRaises(ValueError):p.verify(self.root,self.env,'iOS',receipt,check_output=self.fake_dump)
        receipt.unlink()
        def fail(command,**kwargs):raise subprocess.CalledProcessError(1,command)
        with self.assertRaises(subprocess.CalledProcessError):p.execute(self.root,self.env,'iOS',receipt,run=fail,check_output=self.fake_dump)
        self.assertFalse(receipt.exists())
    def test_current_repository_cannot_enable_scoped_execution_without_lock(self):
        self.assertFalse((ROOT/'Package.resolved').exists())
        self.assertNotIn('Package.resolved',subprocess.check_output(['git','-C',str(ROOT),'ls-files'],text=True).splitlines())
    def test_exact_ordered_merge_parents_admit_and_other_parents_fall_back(self):
        tree=self.git('rev-parse',self.head+'^{tree}')
        exact=self.git('commit-tree',tree,'-p',self.base,'-p',self.head,'-m','exact candidate')
        self.git('checkout','-q','--detach',exact)
        self.assertEqual(self.admit(GITHUB_SHA=exact)['mode'],'scoped')
        reversed_=self.git('commit-tree',tree,'-p',self.head,'-p',self.base,'-m','reversed candidate')
        self.git('checkout','-q','--detach',reversed_)
        self.assertEqual(self.admit(GITHUB_SHA=reversed_)['mode'],'full')
        unrelated=self.git('commit-tree',tree,'-p',self.base,'-m','unrelated candidate')
        wrong=self.git('commit-tree',tree,'-p',self.base,'-p',unrelated,'-m','wrong parents')
        self.git('checkout','-q','--detach',wrong)
        self.assertEqual(self.admit(GITHUB_SHA=wrong)['mode'],'full')

    def test_unknown_platform_rejects(self):
        with self.assertRaises(ValueError):p.recipe(self.root,self.admit(),'Linux')
