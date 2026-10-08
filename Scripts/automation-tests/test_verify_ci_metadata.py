"""Native proof positive controls, stale/failing evidence and race regressions."""
import copy
from datetime import datetime, timedelta, timezone
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('gate', ROOT / 'Scripts/verify-ci-metadata.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
HEAD, BASE, SOURCE, TREE = 'a' * 40, 'b' * 40, 'c' * 40, 'e' * 40
REPO = gate.CONFIG['repository']


class Transcript:
    def __init__(self):
        self.pr = dict(number=45, state='open', labels=[], head=dict(sha=HEAD),
                       base=dict(sha=BASE, repo=dict(full_name=REPO)))
        self.event = dict(action='edited', pull_request=copy.deepcopy(self.pr), changes={})
        self.env = dict(GITHUB_REPOSITORY=REPO, GITHUB_EVENT_NAME='pull_request', GITHUB_REF='refs/pull/45/merge',
                        GITHUB_RUN_ID='20', GITHUB_RUN_ATTEMPT='1', GITHUB_SHA=SOURCE)
        self.run = dict(id=10, run_number=10, workflow_id=100, path=gate.CONFIG['workflow'], event='pull_request',
                        head_sha=HEAD, repository=dict(full_name=REPO), status='completed', conclusion='success',
                        run_attempt=1, check_suite_id=200,
                        display_title=f'CI validation v2 pr:45 head:{HEAD} base:{BASE} source:{SOURCE} release:false asan:false concurrency:false')
        self.own = {**self.run, 'id':20, 'run_number':20, 'status':'in_progress', 'conclusion':None,
                    'display_title':f'{gate.METADATA_PREFIX}pr:45 head:{HEAD} base:{BASE} action:edited source:{SOURCE}'}
        self.merge = dict(sha=SOURCE, parents=[dict(sha=BASE),dict(sha=HEAD)], tree=dict(sha=TREE))
        self.other_merges = {}
        self.runs = [self.run,self.own]
        self.jobs,self.checks = [],{}
        for i,name in enumerate(gate.CONFIG['checks']):
            job = dict(id=300+i, name=name, run_id=10, run_attempt=1, head_sha=HEAD, status='completed', conclusion='success',
                       completed_at=(datetime.now(timezone.utc)-timedelta(hours=1)).isoformat(),
                       steps=[dict(name='Require all planned results',conclusion='success'),dict(name=gate.VERIFY_STEP,conclusion='skipped')],
                       check_run_url=f'https://api.github.com/repos/{REPO}/check-runs/{400+i}')
            self.jobs.append(job)
            self.checks[400+i] = dict(name=name,app=dict(id=15368),check_suite=dict(id=200),head_sha=HEAD,
                                      status='completed',conclusion='success',details_url=f'https://github.com/{REPO}/actions/runs/10/job/{300+i}')
        self.reads,self.pages_read=0,0
        self.run_race,self.pr_race,self.list_race=None,None,None

    def get(self,path):
        if path.endswith('pulls/45'):
            self.reads+=1
            result=copy.deepcopy(self.pr)
            if self.reads==2 and self.pr_race:self.pr_race(result)
            return result
        if path.endswith('actions/runs/20'):return copy.deepcopy(self.own)
        if path.endswith('actions/runs/10'):
            result=copy.deepcopy(self.run)
            if self.reads==1 and getattr(self,'run_read',False) and self.run_race:self.run_race(result)
            self.run_read=True
            return result
        if '/git/commits/' in path:return copy.deepcopy(self.other_merges.get(path.rsplit('/',1)[1], self.merge))
        if '/check-runs/' in path:return copy.deepcopy(self.checks[int(path.rsplit('/',1)[1])])
        if '/actions/runs/' in path:
            return copy.deepcopy(next(r for r in self.runs if r['id']==int(path.rsplit('/',1)[1])))
        raise AssertionError(path)

    def pages(self,path,key):
        if key=='workflow_runs':
            assert 'event=' not in path, 'newer manual validation must not be hidden by an event filter'
            self.pages_read+=1
            result=copy.deepcopy(self.runs)
            if self.pages_read==2 and self.list_race:self.list_race(result)
            return result
        if key=='jobs':return copy.deepcopy(self.jobs)
        raise AssertionError(path)

    def prove(self):
        return gate.prove(self,self.event,self.env)


class MetadataGateTests(unittest.TestCase):
    def test_current_success_is_read_only_and_bound(self):
        t=Transcript();proof=t.prove()
        self.assertEqual(proof,dict(run=10,attempt=1,head=HEAD,base=BASE,source=SOURCE,
                                  validation_source=SOURCE,tree=TREE,check='CI Required'))
        for name in gate.CONFIG['checks']:
            t=Transcript();self.assertEqual(gate.prove(t,t.event,t.env,name)['check'],name)

    def test_failed_pending_cancelled_or_missing_validation_cannot_turn_green(self):
        for state,result in [('completed','failure'),('completed','cancelled'),('in_progress',None),('queued',None),('completed','skipped')]:
            t=Transcript();t.run.update(status=state,conclusion=result)
            with self.subTest(state=state,result=result),self.assertRaises(ValueError):t.prove()
        t=Transcript();t.runs=[t.own]
        with self.assertRaises(ValueError):t.prove()

    def test_newest_real_failure_is_not_hidden_by_older_success_or_metadata(self):
        t=Transcript();t.runs.append({**t.run,'id':9,'run_number':9,'conclusion':'success'});t.run['conclusion']='failure'
        t.runs.append({**t.own,'id':19,'run_number':19,'status':'completed','conclusion':'success'})
        with self.assertRaises(ValueError):t.prove()

    def test_head_base_label_workflow_and_native_check_mismatches_reject(self):
        mutations=[lambda t:t.env.update(GITHUB_EVENT_NAME='workflow_dispatch'),
                   lambda t:t.env.update(GITHUB_REPOSITORY='foreign/repo'),
                   lambda t:t.env.update(GITHUB_REF='refs/heads/main'),
                   lambda t:t.pr['head'].update(sha='d'*40),lambda t:t.pr['base'].update(sha='d'*40),
                   lambda t:t.pr.update(labels=[dict(name='release-validation')]),lambda t:t.pr.update(state='closed'),
                   lambda t:t.run.update(display_title=t.run['display_title'].replace(BASE,'d'*40)),
                   lambda t:t.run.update(display_title=t.run['display_title'].replace('release:false','release:true')),
                   lambda t:t.run.update(display_title=t.run['display_title'].replace(SOURCE,'d'*40)),
                   lambda t:t.run.update(workflow_id=999),lambda t:t.run.update(event='push'),
                   lambda t:t.run.update(event='workflow_dispatch'),
                   lambda t:t.merge['parents'].reverse(),lambda t:t.jobs.clear(),
                   lambda t:t.jobs.append(copy.deepcopy(t.jobs[0])),lambda t:t.jobs[0].update(conclusion='skipped'),
                   lambda t:t.jobs[0]['steps'][0].update(conclusion='skipped'),
                   lambda t:t.jobs[0]['steps'][1].update(conclusion='success'),
                   lambda t:t.jobs[0].update(check_run_url='https://example.invalid/400'),
                   lambda t:t.checks[400]['app'].update(id=999),lambda t:t.checks[400].update(head_sha='d'*40),
                   lambda t:t.checks[400]['check_suite'].update(id=999),lambda t:t.checks[400].update(conclusion='failure')]
        for index,mutate in enumerate(mutations):
            t=Transcript();mutate(t)
            with self.subTest(index=index),self.assertRaises(ValueError):t.prove()

    def test_rerun_new_validation_and_pr_races_reject(self):
        mutations=[lambda t:setattr(t,'run_race',lambda r:r.update(run_attempt=2)),
                   lambda t:setattr(t,'pr_race',lambda p:p['base'].update(sha='d'*40)),
                   lambda t:setattr(t,'list_race',lambda runs:runs.append({**t.run,'id':21,'run_number':21}))]
        for mutate in mutations:
            t=Transcript();mutate(t)
            with self.assertRaises(ValueError):t.prove()

    def test_only_unrelated_labels_and_description_edits_can_revalidate(self):
        for action in ['opened','synchronize','reopened','closed']:
            t=Transcript();t.event['action']=action
            with self.assertRaises(ValueError):t.prove()
        t=Transcript();t.event['changes']={'base':{'ref':{'from':'develop'}}}
        with self.assertRaises(ValueError):t.prove()
        for label in gate.CONFIG['labels']:
            for action in ['labeled','unlabeled']:
                t=Transcript();t.event.update(action=action,label=dict(name=label.upper()))
                with self.assertRaises(ValueError):t.prove()
        for action in ['labeled','unlabeled']:
            t=Transcript();t.event.update(action=action,label=dict(name='documentation'))
            self.assertEqual(t.prove()['run'],10)

    def test_stale_future_and_unzoned_completion_cannot_refresh_required_ci(self):
        for delta in [timedelta(hours=-25), timedelta(hours=1)]:
            t=Transcript();t.jobs[0]['completed_at']=(datetime.now(timezone.utc)+delta).isoformat()
            with self.subTest(delta=delta),self.assertRaises(ValueError):t.prove()
        t=Transcript();t.jobs[0]['completed_at']='2026-10-03T01:00:00'
        with self.assertRaises(ValueError):t.prove()

    def test_shared_head_is_scoped_to_verified_pr_associations(self):
        t=Transcript()
        other={**t.run, 'id':21, 'run_number':21, 'pull_requests':[dict(number=46)],
               'display_title':t.run['display_title'].replace('pr:45 ', 'pr:46 ')}
        t.runs.append(other)
        self.assertEqual(t.prove()['run'],10)
        t=Transcript();t.list_race=lambda runs:runs.append(other)
        self.assertEqual(t.prove()['run'],10)
        for associations in [None,[],[dict(number=45),dict(number=46)],[dict(number='46')]]:
            t=Transcript();t.runs.append({**other,'pull_requests':associations})
            with self.subTest(associations=associations),self.assertRaises(ValueError):t.prove()

    def test_regenerated_merge_requires_same_exact_parents_and_tree(self):
        old_source = 'd' * 40
        t=Transcript()
        t.run['display_title']=t.run['display_title'].replace(SOURCE,old_source)
        t.other_merges[old_source]={**copy.deepcopy(t.merge),'sha':old_source}
        t.checks[400]['head_sha']=old_source
        proof=t.prove()
        self.assertEqual(proof['validation_source'],old_source)
        self.assertEqual(proof['source'],SOURCE)
        self.assertEqual(proof['tree'],TREE)
        mutations=[lambda x:x.other_merges[old_source]['tree'].update(sha='f'*40),
                   lambda x:x.other_merges[old_source]['parents'].reverse(),
                   lambda x:x.other_merges[old_source]['parents'][0].update(sha='f'*40),
                   lambda x:x.other_merges[old_source].update(sha='f'*40),
                   lambda x:x.other_merges[old_source].pop('tree'),
                   lambda x:x.checks[400].update(head_sha=SOURCE)]
        for mutate in mutations:
            candidate=copy.deepcopy(t);candidate.reads=0;candidate.pages_read=0
            mutate(candidate)
            with self.subTest(mutate=mutate),self.assertRaises(ValueError):candidate.prove()

    def test_current_merge_also_requires_exact_tree_evidence(self):
        for tree in [None,{},dict(sha=''),dict(sha='e'*39),dict(sha=123)]:
            t=Transcript();t.merge['tree']=tree or {}
            with self.subTest(tree=tree),self.assertRaises(ValueError):t.prove()

    def test_unknown_or_manual_metadata_prefix_cannot_hide_newer_failure(self):
        for change in [dict(display_title=gate.METADATA_PREFIX+'unknown'),
                       dict(event='workflow_dispatch'),dict(path='.github/workflows/unknown.yml'),
                       dict(workflow_id=999),dict(repository=dict(full_name='foreign/repo')),
                       dict(display_title=f'{gate.METADATA_PREFIX}pr:46 head:{HEAD} base:{BASE} action:edited source:{SOURCE}')]:
            t=Transcript();t.runs.append({**t.own,'id':21,'run_number':21,'status':'completed',
                                         'conclusion':'failure',**change})
            with self.subTest(change=change),self.assertRaises(ValueError):t.prove()

    def test_valid_metadata_is_an_observer_not_real_validation(self):
        t=Transcript();t.runs.append({**t.own,'id':21,'run_number':21,'status':'completed','conclusion':'failure'})
        self.assertEqual(t.prove()['run'],10)
        t.runs=[t.own,t.runs[-1]]
        with self.assertRaises(ValueError):t.prove()

    def test_malformed_or_racing_inventory_never_hides_failures(self):
        mutations=[lambda runs:runs.append(copy.deepcopy(runs[0])),
                   lambda runs:runs.append({**runs[0],'id':21,'run_number':None}),
                   lambda runs:runs.append({**runs[0],'id':21}),
                   lambda runs:runs.clear(),
                   lambda runs:runs[0].update(run_attempt=2,status='in_progress',conclusion=None),
                   lambda runs:runs[0].update(status='completed',conclusion='failure')]
        for mutate in mutations:
            t=Transcript();t.list_race=mutate
            with self.subTest(mutate=mutate),self.assertRaises(ValueError):t.prove()

    def test_api_inventory_requires_stable_complete_nonnegative_total(self):
        class Pages(gate.API):
            def __init__(self, pages):self.responses=iter(pages)
            def get(self, path):return next(self.responses)
        cases=[[dict(total_count=True,workflow_runs=[])],
               [dict(total_count=-1,workflow_runs=[])],
               [dict(total_count=2,workflow_runs=[{}])],
               [dict(total_count=101,workflow_runs=[{}]*100),dict(total_count=102,workflow_runs=[{},{}])]]
        for pages in cases:
            with self.subTest(pages=pages),self.assertRaises(ValueError):Pages(pages).pages('test','workflow_runs')
