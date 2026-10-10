#!/usr/bin/env python3
"""Behavioral regressions for delivery preflight; isolated repos, no network writes."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class DeliveryPreflight(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cwd = Path(self.tmp.name)
        self.run_cmd('git', 'init', '-q')
        (self.cwd/'.git/info/exclude').write_text('/bin/\n/npm.log\n/.keiko-scripts\n')
        self.run_cmd('git', '-c', 'user.name=Test', '-c', 'user.email=test@example.test', 'commit', '-q', '--allow-empty', '-m', 'init')
        self.run_cmd('git', 'checkout', '-q', '-b', 'codex/issue-3915-foundation')
        self.sha = self.run_cmd('git', 'rev-parse', 'HEAD').stdout.strip()

    def run_cmd(self, *args, env=None):
        return subprocess.run(args, cwd=self.cwd, text=True, capture_output=True, env=env)

    def gate(self, name, *args):
        return self.run_cmd('bash', str(ROOT / 'scripts' / name), *args)


    def test_untracked_implementation_cannot_mint_or_consume_proof(self):
        source=self.cwd/'untracked-source.ts'; source.write_text('export const value = 1;')
        result=self.gate('audit-receipt.sh','3915','--findings','0','--user-facing','false')
        self.assertNotEqual(result.returncode,0,result.stdout+result.stderr)
        verify=self.cwd/'.git/keiko-verify';verify.mkdir(exist_ok=True)
        (verify/'codex_issue-3915-foundation.json').write_text(json.dumps({'verified_sha':self.sha,'mode':'full'},separators=(',',':')))
        self.assertNotEqual(self.gate('verify-gate.sh').returncode,0)
        source.unlink()
        self.assertEqual(self.gate('verify-gate.sh').returncode,0)

    def test_ignored_notes_do_not_invalidate_proof(self):
        with (self.cwd/'.git/info/exclude').open('a') as out: out.write('/notes/\n')
        (self.cwd/'notes').mkdir();(self.cwd/'notes/status.md').write_text('scratch')
        self.assertEqual(self.gate('audit-receipt.sh','3915','--findings','0','--user-facing','false').returncode,0)

    def test_system_bash_default_receipt_invocation(self):
        (self.cwd/'package.json').write_text(json.dumps({'scripts':{'agent:pre-pr':'true'}}))
        self.run_cmd('git','add','package.json')
        self.run_cmd('git','-c','user.name=Test','-c','user.email=test@example.test','commit','-qm','policy')
        bindir=self.cwd/'bin';bindir.mkdir()
        npm=bindir/'npm';npm.write_text('#!/bin/sh\nexit 0\n');npm.chmod(0o755)
        env=dict(os.environ,PATH=f'{bindir}:{os.environ["PATH"]}')
        result=self.run_cmd('/bin/bash',str(ROOT/'scripts/verify-receipt.sh'),'3915',env=env)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue((self.cwd/'.git/keiko-verify/codex_issue-3915-foundation.json').exists())

    def test_first_web_push_checks_implementation_but_allows_baseline(self):
        adr=self.cwd/'docs/adr';adr.mkdir(parents=True)
        (adr/'ADR-0145-retire-the-agent-pre-pr-aggregate-gate.md').write_text('Accepted')
        self.run_cmd('git','add','docs')
        self.run_cmd('git','-c','user.name=Test','-c','user.email=test@example.test','commit','-qm','policy')
        self.sha=self.run_cmd('git','rev-parse','HEAD').stdout.strip()
        self.run_cmd('git','update-ref','refs/remotes/origin/dev',self.sha)
        bindir=self.cwd/'bin';bindir.mkdir()
        gh=bindir/'gh';gh.write_text('#!/bin/sh\necho "[]"\n');gh.chmod(0o755)
        env=dict(os.environ,PATH=f'{bindir}:{os.environ["PATH"]}')
        def push(): return self.run_cmd('bash',str(ROOT/'scripts/push-gate.sh'),env=env)
        self.assertEqual(push().returncode,0)
        source=self.cwd/'source.ts';source.write_text('export const value = 1;')
        self.assertNotEqual(push().returncode,0)
        self.run_cmd('git','add','source.ts')
        self.run_cmd('git','-c','user.name=Test','-c','user.email=test@example.test','commit','-qm','implementation')
        self.sha=self.run_cmd('git','rev-parse','HEAD').stdout.strip()
        self.assertNotEqual(push().returncode,0)
        folder=self.cwd/'.git/keiko-verify';folder.mkdir()
        receipt=folder/'codex_issue-3915-foundation.json'
        receipt.write_text(json.dumps({'verified_sha':self.sha,'mode':'full'},separators=(',',':')))
        self.assertEqual(push().returncode,0)  # pre-PR verification does not require early audit
        receipt.write_text(json.dumps({'verified_sha':'a'*40,'mode':'full'},separators=(',',':')))
        self.assertNotEqual(push().returncode,0)

    def test_verification_that_creates_untracked_source_cannot_mint_proof(self):
        (self.cwd/'package.json').write_text(json.dumps({'scripts':{'agent:pre-pr':'true'}}))
        self.run_cmd('git','add','package.json')
        self.run_cmd('git','-c','user.name=Test','-c','user.email=test@example.test','commit','-qm','policy')
        bindir=self.cwd/'bin';bindir.mkdir()
        npm=bindir/'npm';npm.write_text('#!/bin/sh\necho implementation > generated-source.ts\n');npm.chmod(0o755)
        env=dict(os.environ,PATH=f'{bindir}:{os.environ["PATH"]}')
        result=self.run_cmd('bash',str(ROOT/'scripts/verify-receipt.sh'),'3915',env=env)
        self.assertNotEqual(result.returncode,0)
        self.assertFalse((self.cwd/'.git/keiko-verify/codex_issue-3915-foundation.json').exists())

    def test_codex_verify_requires_receipt(self):
        self.assertNotEqual(self.gate('verify-gate.sh').returncode, 0)

    def test_codex_audit_requires_receipt(self):
        self.assertNotEqual(self.gate('audit-gate.sh').returncode, 0)

    def test_raw_delivery_without_effective_directory_is_denied(self):
        (self.cwd/'.keiko-scripts').symlink_to(ROOT/'scripts')
        self.run_cmd('git', 'checkout', '-q', '--detach')
        payload = {'cwd':str(self.cwd), 'tool_name':'Bash',
                   'tool_input':{'command':'gh pr create --title fixture'}}
        result = subprocess.run(['python3',str(ROOT/'scripts/delivery-hook.py'),'verify-gate'],
                                input=json.dumps(payload),cwd=self.cwd,text=True,capture_output=True)
        self.assertEqual(result.returncode,2,result.stderr)

    def test_fast_run_cannot_mint_delivery_receipt(self):
        (self.cwd / 'package.json').write_text('{"scripts":{"typecheck":"true"}}')
        bindir = self.cwd / 'bin'; bindir.mkdir()
        npm = bindir / 'npm'; npm.write_text('#!/bin/sh\nexit 0\n'); npm.chmod(0o755)
        env = dict(os.environ, PATH=f'{bindir}:{os.environ["PATH"]}')
        self.run_cmd('bash', str(ROOT / 'scripts/verify-receipt.sh'), '3915', '--fast', env=env)
        self.assertFalse((self.cwd / '.git/keiko-verify/codex_issue-3915-foundation.json').exists())

    def test_current_target_policy_runs_format_sonar_and_touched_gates(self):
        scripts = {name:'true' for name in ['typecheck','lint','format:check','arch:check','arch:check:negative','gates:sonar','check:eslint-lane','agent:pre-pr']}
        (self.cwd / 'package.json').write_text(json.dumps({'scripts':scripts}))
        adr = self.cwd / 'docs/adr'; adr.mkdir(parents=True)
        (adr / 'ADR-0145-retire-the-agent-pre-pr-aggregate-gate.md').write_text('Accepted')
        (self.cwd / 'AGENTS.md').write_text('### Minimum loop for any change\n```bash\nnpm run typecheck\nnpm run lint\nnpm run format:check\nnpm test\nnpm run arch:check\nnpm run arch:check:negative\n```\n### When you touched these areas, also run\n| You changed | Also run |\n| --- | --- |\n| ESLint toolchain | `npm run check:eslint-lane` |\n| Any code at all | `npm run gates:sonar` |\n')
        self.run_cmd('git','add','.')
        self.run_cmd('git','-c','user.name=Test','-c','user.email=test@example.test','commit','-qm','policy')
        self.run_cmd('git','update-ref','refs/remotes/origin/dev', self.sha)
        bindir = self.cwd / 'bin'; bindir.mkdir()
        npm = bindir / 'npm'; npm.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$NPM_LOG"\n'); npm.chmod(0o755)
        logfile = self.cwd / 'npm.log'
        env = dict(os.environ,PATH=f'{bindir}:{os.environ["PATH"]}',NPM_LOG=str(logfile))
        result = self.run_cmd('bash',str(ROOT/'scripts/verify-receipt.sh'),'3915','--also','check:eslint-lane',env=env)
        self.assertEqual(result.returncode,0,result.stderr)
        calls = logfile.read_text().splitlines()
        self.assertIn('run format:check',calls)
        self.assertIn('run gates:sonar',calls)
        self.assertIn('run check:eslint-lane',calls)
        self.assertNotIn('run agent:pre-pr',calls)
        receipt=json.loads((self.cwd/'.git/keiko-verify/codex_issue-3915-foundation.json').read_text())
        self.assertEqual(receipt['mode'],'full')
        self.assertIn(['npm','run','check:eslint-lane'],receipt['commands'])
        self.assertEqual([' '.join(command) for command in receipt['commands']],['npm '+call for call in calls])

    def test_child_pr_push_requires_current_receipts(self):
        bindir = self.cwd / 'bin'; bindir.mkdir()
        gh = bindir / 'gh'; gh.write_text('''#!/bin/sh
echo '[{"state":"OPEN","baseRefName":"codex/epic-quality"}]'
'''); gh.chmod(0o755)
        env = dict(os.environ,PATH=f'{bindir}:{os.environ["PATH"]}')
        result = self.run_cmd('bash',str(ROOT/'scripts/push-gate.sh'),env=env)
        self.assertNotEqual(result.returncode,0)

    def test_old_receipt_without_full_mode_is_rejected(self):
        folder = self.cwd / '.git/keiko-verify'; folder.mkdir()
        (folder / 'codex_issue-3915-foundation.json').write_text(json.dumps({'verified_sha':self.sha}))
        self.assertNotEqual(self.gate('verify-gate.sh').returncode,0)

    def dirty_tracked(self):
        path = self.cwd / 'tracked.txt'; path.write_text('before')
        self.run_cmd('git','add','tracked.txt')
        self.run_cmd('git','-c','user.name=Test','-c','user.email=test@example.test','commit','-qm','tracked')
        self.sha = self.run_cmd('git','rev-parse','HEAD').stdout.strip()
        path.write_text('after')

    def test_dirty_tree_cannot_mint_audit_or_ui_evidence(self):
        self.dirty_tracked()
        self.assertNotEqual(self.gate('audit-receipt.sh','3915','--findings','0','--user-facing','false').returncode,0)
        env = dict(os.environ,KEIKO_PROFILE='keiko-native')
        result = self.run_cmd('bash',str(ROOT/'scripts/ui-verify-receipt.sh'),'3915','--','true',env=env)
        self.assertNotEqual(result.returncode,0)
        self.assertFalse((self.cwd/'.git/keiko-audit/codex_issue-3915-foundation.json').exists())
        self.assertFalse((self.cwd/'.git/keiko-ui-verify/codex_issue-3915-foundation.json').exists())

    def test_dirty_tree_cannot_consume_previous_current_head_proof(self):
        self.dirty_tracked()
        verify = self.cwd/'.git/keiko-verify'; verify.mkdir()
        audit = self.cwd/'.git/keiko-audit'; audit.mkdir()
        (verify/'codex_issue-3915-foundation.json').write_text(json.dumps({'verified_sha':self.sha,'mode':'full'},separators=(',',':')))
        (audit/'codex_issue-3915-foundation.json').write_text(json.dumps({'audited_sha':self.sha,'findings':'0','user_facing':'false'}))
        self.assertNotEqual(self.gate('verify-gate.sh').returncode,0)
        self.assertNotEqual(self.gate('audit-gate.sh').returncode,0)

    def test_ui_command_that_dirties_tree_cannot_mint_evidence(self):
        path = self.cwd/'tracked.txt'; path.write_text('before')
        self.run_cmd('git','add','tracked.txt')
        self.run_cmd('git','-c','user.name=Test','-c','user.email=test@example.test','commit','-qm','tracked')
        env = dict(os.environ,KEIKO_PROFILE='keiko-native')
        result = self.run_cmd('bash',str(ROOT/'scripts/ui-verify-receipt.sh'),'3915','--','bash','-c','echo after > tracked.txt',env=env)
        self.assertNotEqual(result.returncode,0)
        self.assertFalse((self.cwd/'.git/keiko-ui-verify/codex_issue-3915-foundation.json').exists())

    def test_hooks_fail_closed_across_whitespace_and_leading_git_options(self):
        helpers=self.cwd/'.keiko-scripts';helpers.mkdir()
        (helpers/'delivery-hook.py').symlink_to(ROOT/'scripts/delivery-hook.py')
        operations={'epic-merge-gate':['gh pr merge','gh  pr merge','gh\tpr merge'],
                    'verify-gate':['gh  pr create','gh\tpr ready'],
                    'audit-gate':['gh  pr create','gh\tpr ready'],
                    'ready-gate':['gh  pr ready'],
                    'push-gate':['git  push','git\tpush','git -c advice.pushUpdateRejected=false push','git -C /tmp push']}
        import re
        checked=0
        for rel in ('codex/hooks.json','claude/settings.json'):
            data=json.loads((ROOT/rel).read_text())
            for group in data['hooks']['PreToolUse']:
                for hook in group['hooks']:
                    command=hook.get('command','')
                    matches=[key for key in operations if key in command]
                    if not matches: continue
                    for invocation in operations[matches[0]]:
                        payload=json.dumps({'tool_name':'Bash','cwd':str(self.cwd),'tool_input':{'command':invocation+' 99'}})
                        result=subprocess.run(['bash','-c',command],input=payload,cwd=self.cwd,text=True,capture_output=True)
                        self.assertEqual(result.returncode,2,rel+' '+invocation+' '+result.stderr)
                        checked+=1
        self.assertGreaterEqual(checked,20)


if __name__ == '__main__':
    unittest.main()
