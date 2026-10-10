#!/usr/bin/env python3
"""Ordinary target-owned verification through the shipped runner."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
BRANCH = 'codex/issue-3915-alignment'
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

    def test_assembly_runs_once_after_every_dependency_consumer(self):
        self.git('update-ref', 'refs/remotes/origin/dev', self.sha)
        result = self.gate('verify.sh', '--also',
                           'check:package-surface:assembled', '--also', 'test:coverage:quality',
                           '--also', 'check:package-surface:assembled')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        expected = [['npm', 'run', 'typecheck'], ['npm', 'run', 'lint'],
                    ['npm', 'run', 'format:check'], ['npm', 'test'],
                    ['npm', 'run', 'arch:check'], ['npm', 'run', 'arch:check:negative'],
                    ['npm', 'run', 'gates:sonar'], ['npm', 'run', 'test:coverage:quality'],
                    ['npm', 'run', 'check:package-surface:assembled']]
        self.assertEqual(calls, expected)

    def test_failed_command_stops_verification(self):
        npm = self.cwd / '.git/fixture-bin/npm'
        self.executable(npm, '#!/bin/sh\nprintf "%s\\n" "$*" >> "$NPM_LOG"\nexit 7\n')
        result = self.gate('verify.sh', '--also', 'test:coverage:quality')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls.read_text().splitlines(), ['run typecheck'])

    def test_modern_target_ignores_retired_aggregate(self):
        package = self.cwd / 'package.json'
        data = json.loads(package.read_text())
        data['scripts']['agent:pre-pr'] = 'false'
        package.write_text(json.dumps(data))
        result = self.gate('verify.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertIn(['npm', 'run', 'format:check'], calls)
        self.assertIn(['npm', 'run', 'gates:sonar'], calls)
        self.assertNotIn(['npm', 'run', 'agent:pre-pr'], calls)

    def test_shipped_configs_have_no_delivery_interceptors(self):
        retired = ('delivery-hook', 'delivery-command', 'audit-gate', 'verify-gate',
                   'ready-gate', 'push-gate', 'epic-merge-gate', 'receipt')
        for name in ('codex/hooks.json', 'claude/settings.json'):
            config = json.loads((ROOT / name).read_text())
            for groups in config['hooks'].values():
                for group in groups:
                    for hook in group['hooks']:
                        command = hook.get('command', '')
                        self.assertFalse(any(value in command for value in retired), name)
            self.assertTrue(config['hooks']['SessionStart'])
            self.assertTrue(config['hooks']['Stop'])

    def test_memory_examples_do_not_install_command_or_filename_interceptors(self):
        for name in ('codex/hooks.json', 'claude/settings.json'):
            config = json.loads((ROOT / name).read_text())
            self.assertFalse(config['hooks'].get('PreToolUse'), name)
            self.assertTrue(config['hooks']['SessionStart'])
            self.assertTrue(config['hooks']['Stop'])


if __name__ == '__main__':
    unittest.main()
