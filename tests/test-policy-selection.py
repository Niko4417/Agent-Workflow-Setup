#!/usr/bin/env python3
"""Local policy order and obligations use committed target diff, not path labels alone."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('policy',ROOT/'scripts/verify-web-policy.py')
policy=importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)

class PolicySelection(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.git('init','-q')
        commands=['typecheck','format:check','check:activity-log','list:workflow-consumers','check:zizmor-anchors','check:e2e-suite-wiring','check:retrieval-quality','gates:sonar','test:coverage:quality','check:package-surface:assembled','check:eslint-lane','lint','test:coverage:ui','check:editor-release-evidence','check:update-ui-evidence']
        (self.root/'package.json').write_text(json.dumps({'scripts':dict.fromkeys(commands,'true')}))
        (self.root/'AGENTS.md').write_text('''### Minimum loop for any change
```bash
npm run typecheck
npm run format:check
```
### When you touched these areas, also run
| You changed | Also run |
| --- | --- |
| A new or changed activity-log line or `op` | `npm run check:activity-log` |
| Retrieval / RAG / grounding | `check:retrieval-quality` |
| Any file under `.github/workflows/` | `npm run list:workflow-consumers` FIRST, then `npm run check:zizmor-anchors` and `npm run check:e2e-suite-wiring` |
| Any code at all | `npm run gates:sonar` |
''')
        self.git('add','.')
        self.git('-c','user.name=Test','-c','user.email=test@example.test','commit','-qm','baseline')
        self.git('update-ref','refs/remotes/origin/dev','HEAD')

    def git(self,*args):
        return subprocess.run(['git',*args],cwd=self.root,text=True,capture_output=True,check=True)

    def test_only_workflow_consumer_listing_precedes_build(self):
        planned=policy.plan(self.root,['.github/workflows/ci.yml'])
        inventory=('npm','run','list:workflow-consumers')
        build=('npm','run','typecheck')
        wiring=('npm','run','check:e2e-suite-wiring')
        self.assertEqual(planned[0],inventory)
        self.assertLess(planned.index(build),planned.index(wiring))

    def test_gateway_op_change_requires_activity_inventory(self):
        planned=policy.plan(self.root,['packages/keiko-model-gateway/src/gateway.ts'])
        self.assertIn(('npm','run','check:activity-log'),planned)

    def test_accepted_retrieval_plan_selects_current_quality_gate(self):
        planned=policy.plan(self.root,['packages/keiko-knowledge/src/index.ts'],['check:retrieval-quality'])
        self.assertIn(('npm','run','check:retrieval-quality'),planned)

    def test_docs_change_does_not_add_unrelated_area_gates(self):
        planned=policy.plan(self.root,['docs/readme.md'])
        self.assertNotIn(('npm','run','check:activity-log'),planned)
        self.assertNotIn(('npm','run','check:retrieval-quality'),planned)

    def test_semantic_gates_are_selected_by_plan_not_filename(self):
        planned=policy.plan(self.root,['packages/keiko-tools/src/index.ts','package.json','docs/release.md'])
        for name in ('test:coverage:quality','check:package-surface:assembled','check:eslint-lane'):
            self.assertNotIn(('npm','run',name),planned)
            self.assertIn(('npm','run',name),policy.plan(self.root,[],[name]))

    def test_test_only_diff_does_not_invent_runtime_activity_change(self):
        for path in ('packages/keiko-tools/src/tool.test.ts','packages/keiko-tools/src/__tests__/tool.ts'):
            self.assertNotIn(('npm','run','check:activity-log'),policy.plan(self.root,[path]))

    def test_destructive_surface_check_runs_after_dependency_consumers(self):
        planned=policy.plan(self.root,['packages/keiko-tools/src/index.ts'],['check:package-surface:assembled','test:coverage:quality'])
        self.assertEqual(planned[-1],('npm','run','check:package-surface:assembled'))
        self.assertLess(planned.index(('npm','run','test:coverage:quality')),len(planned)-1)
        self.assertLess(planned.index(('npm','run','check:activity-log')),len(planned)-1)

    def test_ui_scope_runs_workspace_and_release_checks(self):
        planned = policy.plan(self.root, ['packages/keiko-ui/src/component.tsx'])
        self.assertIn(('npm', 'run', 'typecheck', '--workspace', '@oscharko-dev/keiko-ui'), planned)
        self.assertIn(('npm', 'run', 'lint', '--workspace', '@oscharko-dev/keiko-ui'), planned)
        self.assertIn(('npm', 'run', 'test:coverage:ui'), planned)
        self.assertIn(('npm', 'run', 'check:editor-release-evidence'), planned)
        self.assertNotIn(('npm', 'run', 'check:update-ui-evidence'), planned)

    def test_updater_scope_adds_freshness_check(self):
        planned = policy.plan(self.root, ['packages/keiko-ui/src/lib/api.ts'])
        self.assertIn(('npm', 'run', 'check:update-ui-evidence'), planned)

    def test_unknown_plan_command_cannot_disappear(self):
        with self.assertRaises(ValueError): policy.plan(self.root,[],['missing-required-gate'])

if __name__ == '__main__': unittest.main()
