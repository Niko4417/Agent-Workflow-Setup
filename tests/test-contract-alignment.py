#!/usr/bin/env python3
"""Target-contract boundary controls through real receipt and push entrypoints."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
BRANCH = 'codex/issue-3915-alignment'
SLUG = BRANCH.replace('/', '_')
ADR = 'docs/adr/ADR-0145-retire-the-agent-pre-pr-aggregate-gate.md'


class ContractAlignment(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cwd = Path(self.tmp.name)
        self.git('init', '-q')
        scripts = ['typecheck', 'lint', 'format:check', 'test', 'arch:check',
                   'arch:check:negative', 'gates:sonar', 'test:coverage:quality',
                   'check:package-surface:assembled']
        (self.cwd / 'package.json').write_text(json.dumps({'scripts': dict.fromkeys(scripts, 'true')}))
        (self.cwd / 'AGENTS.md').write_text('''### Minimum loop for any change
```bash
npm run typecheck
npm run lint
npm run format:check
npm test
npm run arch:check
npm run arch:check:negative
```
''')
        adr = self.cwd / ADR
        adr.parent.mkdir(parents=True)
        adr.write_text('Accepted')
        self.commit('policy')
        self.git('checkout', '-qb', BRANCH)
        self.git('update-ref', 'refs/remotes/origin/dev', self.sha)
        bindir = self.cwd / '.git/fixture-bin'
        bindir.mkdir()
        self.calls = self.cwd / '.git/npm-calls.jsonl'
        self.env = dict(os.environ, PATH=f'{bindir}:{os.environ["PATH"]}',
                        KEIKO_PROFILE='keiko-web', NPM_LOG=str(self.calls))
        self.executable(bindir / 'gh', '#!/bin/sh\nprintf "[]\\n"\n')
        self.executable(bindir / 'npm', '''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ['NPM_LOG'], 'a') as output:
    output.write(json.dumps(['npm', *args]) + '\\n')
pruned = pathlib.Path('.git/assembly-pruned')
if pruned.exists():
    sys.exit(9)
if args == ['run', 'check:package-surface:assembled']:
    pruned.touch()
if os.environ.get('GENERATED_PATH'):
    path = pathlib.Path(os.environ['GENERATED_PATH'])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('fixture output')
''')

    def executable(self, path, text):
        path.write_text(text)
        path.chmod(0o755)

    def run_cmd(self, *args, env=None):
        return subprocess.run(args, cwd=self.cwd, env=env or self.env,
                              text=True, capture_output=True)

    def git(self, *args):
        result = subprocess.run(['git', *args], cwd=self.cwd, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def commit(self, message):
        self.git('add', '.')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.test',
                 '-c', 'commit.gpgsign=false', 'commit', '-qm', message)
        self.sha = self.git('rev-parse', 'HEAD')

    def gate(self, script, *args, env=None):
        return self.run_cmd('/bin/bash', str(SCRIPTS / script), *args, env=env)

    def receipt_path(self, kind):
        return self.cwd / '.git' / ('keiko-' + kind) / (SLUG + '.json')

    def receipt(self, kind, data):
        path = self.receipt_path(kind)
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(data, separators=(',', ':')))

    def assert_allowed(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_blocked(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_untracked_input_blocks_verify_and_ui_before_execution(self):
        (self.cwd / 'new-source.ts').write_text('export const value = 1;')
        verify = self.gate('verify-receipt.sh', '3915', '--also', 'gates:sonar')
        self.assert_blocked(verify)
        self.assertIn('[proof-worktree] BLOCKED', verify.stderr)
        self.assertFalse(self.calls.exists())
        result = self.gate('ui-verify-receipt.sh', '3915', '--', 'sh', '-c',
                           'touch .git/journey-ran', env=dict(self.env, KEIKO_PROFILE='keiko-native'))
        self.assert_blocked(result)
        self.assertFalse((self.cwd / '.git/journey-ran').exists())
        for kind in ('verify', 'ui-verify'):
            self.assertFalse(self.receipt_path(kind).exists())

    def test_ui_generated_untracked_output_blocks_receipt_after_success(self):
        result = self.gate('ui-verify-receipt.sh', '3915', '--', 'sh', '-c',
                           'touch .git/journey-ran; echo fixture > generated-source.ts',
                           env=dict(self.env, KEIKO_PROFILE='keiko-native'))
        self.assertTrue((self.cwd / '.git/journey-ran').exists())
        self.assert_blocked(result)
        self.assertFalse(self.receipt_path('ui-verify').exists())

    def test_ignored_generated_notes_allow_all_receipts_and_consumers(self):
        with (self.cwd / '.git/info/exclude').open('a') as output:
            output.write('/notes/\n')
        self.assert_allowed(self.gate('verify-receipt.sh', '3915',
                                     env=dict(self.env, GENERATED_PATH='notes/status.md')))
        self.assert_allowed(self.gate('ui-verify-receipt.sh', '3915', '--', 'true',
                                     env=dict(self.env, KEIKO_PROFILE='keiko-native')))
        self.assert_allowed(self.gate('audit-receipt.sh', '3915', '--findings', '0',
                                     '--user-facing', 'true'))
        self.assert_allowed(self.gate('verify-gate.sh'))
        self.assert_allowed(self.gate('audit-gate.sh'))
        self.assertTrue((self.cwd / 'notes/status.md').exists())

    def test_untracked_input_invalidates_existing_ui_backed_audit(self):
        self.receipt('audit', {'audited_sha': self.sha, 'findings': '0', 'user_facing': 'true'})
        self.receipt('ui-verify', {'ui_verified_sha': self.sha})
        self.assert_allowed(self.gate('audit-gate.sh'))
        (self.cwd / 'new-source.ts').write_text('export const value = 1;')
        self.assert_blocked(self.gate('audit-gate.sh'))

    def test_bootstrap_requires_exact_supported_remote_base_ref(self):
        self.git('update-ref', '-d', 'refs/remotes/origin/dev')
        cases = [('refs/remotes/origin/dev', True),
                 ('refs/remotes/origin/epic/accepted', True),
                 ('refs/remotes/origin/codex/epic-accepted', True),
                 ('refs/remotes/origin/dev/experimental', False),
                 ('refs/remotes/origin/feat/accepted', False),
                 ('refs/remotes/origin/codex/epicaccepted', False),
                 ('refs/tags/dev', False)]
        for ref, allowed in cases:
            with self.subTest(ref=ref):
                self.git('update-ref', ref, self.sha)
                result = self.gate('push-gate.sh')
                self.assert_allowed(result) if allowed else self.assert_blocked(result)
                self.git('update-ref', '-d', ref)

    def test_ancestor_of_base_cannot_bootstrap_without_current_proof(self):
        baseline = self.sha
        (self.cwd / 'source.ts').write_text('export const value = 1;')
        self.commit('implementation')
        self.git('update-ref', 'refs/remotes/origin/dev', self.sha)
        self.git('reset', '--hard', baseline)
        self.assert_blocked(self.gate('push-gate.sh'))

    def test_modern_first_push_accepts_only_current_full_verify_without_early_audit(self):
        self.git('update-ref', 'refs/remotes/origin/dev', self.sha)
        (self.cwd / 'source.ts').write_text('export const value = 1;')
        self.commit('implementation')
        self.assert_blocked(self.gate('push-gate.sh'))
        for data in ({'verified_sha': self.sha, 'mode': 'fast'},
                     {'verified_sha': '0' * 40, 'mode': 'full'},
                     {'verified_sha': self.sha}):
            with self.subTest(receipt=data):
                self.receipt('verify', data)
                self.assert_blocked(self.gate('push-gate.sh'))
        self.receipt('verify', {'verified_sha': self.sha, 'mode': 'full'})
        self.assert_allowed(self.gate('push-gate.sh'))
        self.assertFalse(self.receipt_path('audit').exists())

    def test_older_web_and_native_keep_pre_pr_push_policy(self):
        (self.cwd / ADR).unlink()
        (self.cwd / 'source.ts').write_text('export const value = 1;')
        self.commit('older target implementation')
        for profile in ('keiko-web', 'keiko-native'):
            with self.subTest(profile=profile):
                self.assert_allowed(self.gate('push-gate.sh', env=dict(self.env, KEIKO_PROFILE=profile)))
        self.assertFalse(self.receipt_path('verify').exists())

    def test_assembly_runs_once_after_every_dependency_consumer(self):
        self.git('update-ref', 'refs/remotes/origin/dev', self.sha)
        result = self.gate('verify-receipt.sh', '3915', '--also',
                           'check:package-surface:assembled', '--also', 'test:coverage:quality',
                           '--also', 'check:package-surface:assembled')
        self.assert_allowed(result)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        expected = [['npm', 'run', 'typecheck'], ['npm', 'run', 'lint'],
                    ['npm', 'run', 'format:check'], ['npm', 'test'],
                    ['npm', 'run', 'arch:check'], ['npm', 'run', 'arch:check:negative'],
                    ['npm', 'run', 'gates:sonar'], ['npm', 'run', 'test:coverage:quality'],
                    ['npm', 'run', 'check:package-surface:assembled']]
        self.assertEqual(calls, expected)
        proof = json.loads(self.receipt_path('verify').read_text())
        self.assertEqual(proof['commands'], expected)
        self.assertEqual(proof['verified_sha'], self.sha)


if __name__ == '__main__':
    unittest.main()
