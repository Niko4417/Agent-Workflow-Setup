#!/usr/bin/env python3
"""Check provenance, freshness and complete pagination through public read seams."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / 'scripts/required-checks-gate.py'
spec = importlib.util.spec_from_file_location('required_checks', path)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
SHA = 'a' * 40

def run(identifier=1, **extra):
    return {'id': identifier, 'name':'ci', 'app':{'id':15368}, 'head_sha':SHA, 'status':'completed', 'conclusion':'success', **extra}

class RequiredChecks(unittest.TestCase):
    def test_success_and_all_required_contexts(self):
        gate.evaluate({'ci':15368}, [run()], SHA)
        with self.assertRaises(ValueError):
            gate.evaluate({'ci':15368, 'ui':15368}, [run()], SHA)

    def test_wrong_app_wrong_sha_and_non_success_fail(self):
        for change in ({'app':{'id':99}}, {'head_sha':'b'*40}, {'status':'in_progress'}, {'conclusion':'skipped'}, {'conclusion':'failure'}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                gate.evaluate({'ci':15368}, [run(**change)], SHA)

    def test_latest_failure_cannot_be_rescued_by_older_success(self):
        with self.assertRaises(ValueError):
            gate.evaluate({'ci':15368}, [run(1), run(2, conclusion='failure')], SHA)
        gate.evaluate({'ci':15368}, [run(1, conclusion='failure'), run(2)], SHA)

    def test_unprotected_unbound_or_incomplete_policy_fails(self):
        valid = {'protected':True, 'protection':{'required_status_checks':{'contexts':['ci'], 'checks':[{'context':'ci','app_id':15368}]}}}
        self.assertEqual(gate.required_checks(valid), {'ci':15368})
        for payload in ({'protected':False}, {'protected':True,'protection':{'required_status_checks':{'contexts':['ci'], 'checks':[]}}}, {'protected':True,'protection':{'required_status_checks':{'contexts':['ci'], 'checks':[{'context':'ci','app_id':None}]}}}):
            with self.assertRaises(ValueError):
                gate.required_checks(payload)

    def test_reads_check_runs_through_last_page(self):
        with patch.object(gate, 'gh', side_effect=[{'check_runs':[run(i) for i in range(100)]},{'check_runs':[run(101)]}]) as api:
            self.assertEqual(len(gate.all_checks('owner/repo', SHA)),101)
            self.assertIn('page=2',api.call_args.args[1])

    def test_unresolved_later_review_page_blocks(self):
        def payload(nodes, more):
            return {'data':{'repository':{'pullRequest':{'headRefOid':SHA,'reviewThreads':{'nodes':nodes, 'pageInfo':{'hasNextPage':more,'endCursor':'cursor'}}}}}}
        with patch.object(gate,'gh',side_effect=[payload([{'isResolved':True}],True),payload([{'isResolved':False}],False)]) as api:
            with self.assertRaises(ValueError):
                gate.settled('owner/repo','1',SHA)
            self.assertEqual(api.call_count,2)
        with patch.object(gate,'gh',return_value=payload([],False)):
            gate.settled('owner/repo','1',SHA)

    def test_unprotected_epic_still_proves_full_dev_matrix(self):
        dev = {'protected':True,'protection':{'required_status_checks':{'contexts':['ci'],'checks':[{'context':'ci','app_id':15368}]}}}
        current = {'headRefOid':SHA,'baseRefName':'epic/demo','state':'OPEN','isDraft':False}
        for runs, allowed in (([run()], True), ([], False), ([run(conclusion='failure')], False),
                              ([run(head_sha='b'*40)], False), ([run(app={'id':99})], False)):
            with self.subTest(runs=runs), patch.object(gate,'gh',side_effect=[
                {'nameWithOwner':'owner/repo'},dev,{'protected':False},current]), \
                patch.object(gate,'all_checks',return_value=runs), patch.object(gate,'settled'):
                if allowed:
                    gate.main('1','epic/demo',SHA)
                else:
                    with self.assertRaises(ValueError): gate.main('1','epic/demo',SHA)

    def test_target_additional_requirements_are_preserved_without_parity(self):
        self.assertEqual(gate.required_checks({'protected':False},required=False),{})
        self.assertEqual(gate.required_checks({'protected':True,'protection':{'required_status_checks':None}},required=False),{})
        with self.assertRaises(ValueError): gate.required_checks({'protected':True},required=False)
        def branch(app):
            return {'protected':True,'protection':{'required_status_checks':{'contexts':['ci'],'checks':[{'context':'ci','app_id':app}]}}}
        current={'headRefOid':SHA,'baseRefName':'epic/demo','state':'OPEN','isDraft':False}
        for runs, allowed in (([run(),run(2,app={'id':99})],True),([run()],False)):
            with patch.object(gate,'gh',side_effect=[{'nameWithOwner':'owner/repo'},branch(15368),branch(99),current]), \
                 patch.object(gate,'all_checks',return_value=runs), patch.object(gate,'settled'):
                if allowed: gate.main('1','epic/demo',SHA)
                else:
                    with self.assertRaises(ValueError): gate.main('1','epic/demo',SHA)

if __name__ == '__main__': unittest.main()
