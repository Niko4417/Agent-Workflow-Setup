#!/usr/bin/env python3
"""Explicit-root delivery uses real gates and fixture-only executables."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BRANCH = 'codex/issue-3915-foundation'


class ExplicitRootDelivery(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name).resolve()
        self.root = self.base/'target with spaces'; self.root.mkdir()
        self.other = self.base/'detached-session'; self.other.mkdir()
        self.real_git = shutil.which('git')
        for folder in (self.root,self.other):
            subprocess.run([self.real_git,'init','-q',str(folder)],check=True)
            subprocess.run([self.real_git,'-c','user.name=Test','-c','user.email=test@example.test',
                            'commit','-q','--allow-empty','-m','init'],cwd=folder,check=True)
            (folder/'.keiko-scripts').symlink_to(ROOT/'scripts')
        subprocess.run([self.real_git,'checkout','-q','-b',BRANCH],cwd=self.root,check=True)
        subprocess.run([self.real_git,'checkout','-q','--detach'],cwd=self.other,check=True)
        self.sha = subprocess.check_output([self.real_git,'rev-parse','HEAD'],cwd=self.root,text=True).strip()
        self.entry = self.root/'.keiko-scripts/delivery-command.py'
        bindir = self.base/'bin'; bindir.mkdir()
        self.log = self.base/'execution.jsonl'
        self.env = dict(os.environ,PATH=f'{bindir}:{os.environ["PATH"]}',EXECUTION_LOG=str(self.log),REAL_GIT=self.real_git,
                        TEST_BRANCH=BRANCH,TEST_SHA=self.sha)
        for executable in ('git','gh'):
            mock = bindir/executable
            mock.write_text('''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
args=sys.argv[1:]
name=pathlib.Path(sys.argv[0]).name
if name=='git' and (not args or args[0]!='push'):
    sys.exit(subprocess.run([os.environ['REAL_GIT']]+args).returncode)
if name=='gh' and args[:2]==['pr','list']:
    print('[{"state":"OPEN","baseRefName":"codex/epic-quality"}]')
    sys.exit(0)
if name=='gh' and args[:2]==['pr','view']:
    print(json.dumps({'headRefName':os.environ['TEST_BRANCH'],'headRefOid':os.environ['TEST_SHA']}))
    sys.exit(0)
with open(os.environ['EXECUTION_LOG'],'a') as log:
    log.write(json.dumps({'executable':name,'cwd':os.getcwd(),'args':args})+'\\n')
''')
            mock.chmod(0o755)

    def proof(self, name):
        folder = self.root/'.git'/('keiko-'+name); folder.mkdir(exist_ok=True)
        data = {'verified_sha':self.sha,'mode':'full'} if name=='verify' else {
            'audited_sha':self.sha,'findings':'0','user_facing':'false'}
        (folder/(BRANCH.replace('/','_')+'.json')).write_text(json.dumps(data,separators=(',',':')))

    def invocation(self, *args):
        return ['python3',str(self.entry),'--root',str(self.root),'--',*args]

    def execute(self, *args):
        return subprocess.run(self.invocation(*args),cwd=self.other,env=self.env,text=True,capture_output=True)

    def hook(self, gate, argv, **fields):
        payload={'cwd':str(self.other),'tool_name':'Bash','tool_input':{'command':shlex.join(argv),**fields}}
        return subprocess.run(['python3',str(ROOT/'scripts/delivery-hook.py'),gate],input=json.dumps(payload),
                              cwd=self.other,env=self.env,text=True,capture_output=True)

    def test_alternate_root_missing_proof_denied_by_hook_and_entrypoint(self):
        argv=self.invocation('gh','pr','create','--title','fixture')
        for gate in ('verify-gate','audit-gate'):
            result=self.hook(gate,argv)
            self.assertEqual(result.returncode,2,result.stderr)
            self.assertIn('has not passed',result.stderr) if gate=='verify-gate' else self.assertIn('BLOCKED',result.stderr)
        result=self.execute('gh','pr','create','--title','fixture')
        self.assertEqual(result.returncode,2,result.stderr)
        self.assertFalse(self.log.exists())

    def test_entrypoint_always_checks_audit_after_verify(self):
        self.proof('verify')
        result=self.execute('gh','pr','create','--title','fixture')
        self.assertEqual(result.returncode,2,result.stderr)
        self.assertIn('audit',result.stderr)
        self.assertFalse(self.log.exists())

    def test_positive_create_ready_push_execute_exact_argv_at_verified_root(self):
        self.proof('verify');self.proof('audit')
        commands=[['gh','pr','create','--head',BRANCH,'--title','literal ; $(never)'],
                  ['gh','pr','ready','99'],['git','push','-u','origin',BRANCH]]
        for args in commands:
            result=self.execute(*args)
            self.assertEqual(result.returncode,0,result.stderr)
        calls=[json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual([c['cwd'] for c in calls],[str(self.root)]*3)
        self.assertEqual([[c['executable'],*c['args']] for c in calls],commands)
        self.assertFalse((self.other/'execution.jsonl').exists())

    def test_positive_hook_does_not_execute_the_delivery(self):
        self.proof('verify');self.proof('audit')
        result=self.hook('verify-gate',self.invocation('gh','pr','create','--title','fixture'))
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertFalse(self.log.exists())

    def test_ready_cannot_use_local_proof_for_another_branch_or_stale_head(self):
        self.proof('verify');self.proof('audit')
        for fields in ({'TEST_BRANCH':'codex/issue-999-unrelated'}, {'TEST_SHA':'a'*40}):
            result=subprocess.run(self.invocation('gh','pr','ready','99'),cwd=self.other,
                                  env=dict(self.env,**fields),text=True,capture_output=True)
            self.assertEqual(result.returncode,2,result.stderr)
        self.assertFalse(self.log.exists())

    def test_merge_keeps_canonical_guard(self):
        self.proof('verify');self.proof('audit')
        result=self.execute('gh','pr','merge','0','--auto','--squash','--match-head-commit',self.sha)
        self.assertEqual(result.returncode,2,result.stderr)
        self.assertIn('use only:',result.stderr)
        self.assertFalse(self.log.exists())

    def test_raw_calls_cannot_use_session_cwd_or_unqualified_cwd_field(self):
        for command in (['gh','pr','create'],['gh','pr','ready','99'],['git','push','origin',BRANCH]):
            gate='push-gate' if command[0]=='git' else 'verify-gate'
            for fields in ({},{'cwd':str(self.root)}):
                result=self.hook(gate,command,**fields)
                self.assertEqual(result.returncode,2,result.stderr)
                self.assertIn('effective tool workdir is unavailable',result.stderr)

    def test_observable_effective_workdir_uses_the_same_root_validation(self):
        self.proof('verify');self.proof('audit')
        result=self.hook('verify-gate',['gh','pr','create'],workdir=str(self.root))
        self.assertEqual(result.returncode,0,result.stderr)
        result=self.hook('verify-gate',['gh','pr','create'],workdir=str(self.other))
        self.assertEqual(result.returncode,2,result.stderr)

    def test_entrypoint_root_aliases_prefixes_overrides_and_missing_helpers_denied(self):
        self.proof('verify');self.proof('audit')
        canonical=self.invocation('gh','pr','create')
        invalid=[['env',*canonical],['python3','-u',*canonical[1:]],
                 [canonical[0],str(ROOT/'scripts/delivery-command.py'),*canonical[2:]],
                 [*canonical[:3],str(self.other),*canonical[4:]],
                 [*canonical[:3],str(self.root)+'/../target with spaces',*canonical[4:]],
                 [*canonical[:4],'--extra',*canonical[4:]],
                 self.invocation('gh','--repo','other/repo','pr','create'),
                 self.invocation('gh','pr','create','--repo','other/repo'),
                 self.invocation('gh','pr','create','--head','unverified-branch'),
                 self.invocation('gh','pr','ready','99','--repo','other/repo'),
                 self.invocation('git','-C',str(self.other),'push','origin',BRANCH),
                 self.invocation('git','push','--force','origin',BRANCH),
                 self.invocation('git','push','origin'),
                 self.invocation('git','push','origin','HEAD:dev')]
        for argv in invalid:
            gate='push-gate' if 'git' in argv else 'verify-gate'
            result=self.hook(gate,argv)
            self.assertEqual(result.returncode,2,str(argv)+result.stderr)
        (self.root/'.keiko-scripts').unlink()
        result=self.execute('gh','pr','create')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.log.exists())

    def test_shell_chaining_and_substitution_stay_denied(self):
        command=shlex.join(self.invocation('gh','pr','create'))
        for text in (command+'; true',command+' && true',command+' | cat',command+' > out',
                     command+' --title "$(pwd)"',command+' --title "`pwd`"'):
            payload={'cwd':str(self.other),'tool_input':{'command':text}}
            result=subprocess.run(['python3',str(ROOT/'scripts/delivery-hook.py'),'verify-gate'],
                                  input=json.dumps(payload),cwd=self.other,env=self.env,text=True,capture_output=True)
            self.assertEqual(result.returncode,2,text+result.stderr)

    def test_repository_environment_overrides_denied_even_without_hooks(self):
        for name in ('GH_REPO','GIT_DIR','GIT_WORK_TREE','GIT_CONFIG_COUNT'):
            result=subprocess.run(self.invocation('gh','pr','create'),cwd=self.other,
                                  env=dict(self.env,**{name:'override'}),text=True,capture_output=True)
            self.assertEqual(result.returncode,2,result.stderr)
            self.assertIn('repository-changing environment',result.stderr)
        self.assertFalse(self.log.exists())

    def test_entrypoint_rejects_dirty_proof_and_inner_overrides_without_hooks(self):
        self.proof('verify');self.proof('audit')
        for args in (('gh','pr','create','--repo','other/repo'),
                     ('gh','pr','create','--head','unverified'),
                     ('gh','pr','ready','99','--repo','other/repo'),
                     ('git','push','--force','origin',BRANCH),
                     ('git','push','origin','HEAD:dev')):
            result=self.execute(*args)
            self.assertEqual(result.returncode,2,result.stderr)
        tracked=self.root/'tracked.txt';tracked.write_text('before')
        subprocess.run([self.real_git,'add','tracked.txt'],cwd=self.root,check=True)
        subprocess.run([self.real_git,'-c','user.name=Test','-c','user.email=test@example.test',
                        'commit','-qm','tracked'],cwd=self.root,check=True)
        self.sha=subprocess.check_output([self.real_git,'rev-parse','HEAD'],cwd=self.root,text=True).strip()
        self.proof('verify');self.proof('audit')
        tracked.write_text('after')
        result=self.execute('gh','pr','create')
        self.assertEqual(result.returncode,2,result.stderr)
        self.assertIn('tracked edits',result.stderr)
        self.assertFalse(self.log.exists())


    def test_benign_metadata_dry_run_and_heredoc_examples(self):
        self.proof('verify');self.proof('audit')
        for args in (('gh','pr','create','--dry-run','-t','fixture','-l','docs'),
                     ('git','push','--dry-run','--porcelain','origin',BRANCH),
                     ('gh','pr','create','--title','cd')):
            result=self.execute(*args)
            self.assertEqual(result.returncode,0,result.stderr)
        for command in ("cat <<'EOF' > notes\ngh pr create --repo example/other\nEOF\n",
                        "python3 - <<'PY'\ns = 'gh pr merge --admin'\nPY\n",
                        "printf '%s' 'gh pr create'", "echo 'git push --force'"):
            payload={'tool_input':{'command':command}}
            result=subprocess.run(['python3',str(ROOT/'scripts/delivery-hook.py'),'verify-gate'],
                                  input=json.dumps(payload),env=self.env,text=True,capture_output=True)
            self.assertEqual(result.returncode,0,command+result.stderr)
        for command in ("cat <<'EOF'\ngh pr create\nEOF\ngh pr create --repo other/repo\n",
                        "cat <<'EOF'; gh pr create --repo other/repo\nexample\nEOF\n"):
            payload={'tool_input':{'command':command}}
            result=subprocess.run(['python3',str(ROOT/'scripts/delivery-hook.py'),'verify-gate'],
                                  input=json.dumps(payload),env=self.env,text=True,capture_output=True)
            self.assertEqual(result.returncode,2,result.stderr)


if __name__ == '__main__':
    unittest.main()
