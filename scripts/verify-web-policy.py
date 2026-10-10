#!/usr/bin/env python3
"""Execute individual commands from the live web target's AGENTS.md, not a cached aggregate."""
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys


def plan(root, paths, additional=()):
    agents = (root / 'AGENTS.md').read_text()
    scripts = json.loads((root / 'package.json').read_text())['scripts']
    minimum = re.search(r'### Minimum loop for any change\s+```bash\n(.*?)```', agents, re.S)
    if minimum is None:
        raise ValueError('current target minimum-loop contract is unavailable')
    result = []
    for line in minimum[1].splitlines():
        args = shlex.split(line.split('#', 1)[0])
        if args:
            if args != ['npm', 'test'] and (args[:2] != ['npm', 'run'] or args[2] not in scripts):
                raise ValueError('minimum-loop command is not a current target script')
            result.append(args)
    selected = ['gates:sonar', *additional]
    runtime = any((p.startswith('src/') or (p.startswith('packages/') and '/src/' in p))
                  and re.search(r'\.(?:[cm]?[jt]sx?)$', p)
                  and not re.search(r'(?:\.(?:test|spec)\.|/__tests__/|/test[s]?/)', p) for p in paths)
    if runtime:
        selected.append('check:activity-log')
    if any(p.startswith('packages/keiko-ui/') for p in paths):
        result.extend([['npm','run','typecheck','--workspace','@oscharko-dev/keiko-ui'],
                       ['npm','run','lint','--workspace','@oscharko-dev/keiko-ui']])
        selected.extend(['test:coverage:ui','check:editor-release-evidence'])
        updater = ('src/lib/i18n-messages.de.ts','src/lib/i18n-messages.en.ts',
                   'src/lib/api.ts')
        if any(p.startswith('packages/keiko-ui/') and (p.endswith(updater) or
               p.endswith('/globals.css') or '/desktop/update/' in p) for p in paths):
            selected.append('check:update-ui-evidence')
    if any(p.startswith('tests/e2e/') for p in paths):
        selected.append('check:e2e-suite-wiring')
    if any(p.startswith('.github/workflows/') for p in paths):
        result.insert(0, ['npm','run','list:workflow-consumers'])
        selected.extend(['check:zizmor-anchors','check:e2e-suite-wiring'])
    for name in selected:
        if name not in scripts or name.startswith('generate:'):
            raise ValueError('selected touched-area command is not a current checking script: ' + name)
        result.append(['npm','run',name])
    return list(dict.fromkeys(tuple(args) for args in result))


def options(args):
    additional = []
    show_plan = False
    while args:
        value = args.pop(0)
        if value == '--plan' and not show_plan:
            show_plan = True
        elif value == '--also' and args:
            additional.append(args.pop(0))
        else:
            raise ValueError('use [--plan] [--also <current npm checking script>]')
    return show_plan, additional


def main():
    root = Path.cwd()
    base = subprocess.check_output(['git', 'merge-base', 'HEAD', 'origin/dev'], text=True).strip()
    paths = subprocess.check_output(['git', 'diff', '--name-only', base, 'HEAD'], text=True).splitlines()
    show_plan, additional = options(sys.argv[1:])
    planned = plan(root, paths, additional)
    if show_plan:
        print(json.dumps(planned))
        return
    for args in planned:
        print('[verify-policy] ' + shlex.join(args), flush=True)
        subprocess.run(args, check=True)

if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, IndexError, subprocess.CalledProcessError) as error:
        print('[verify-policy] BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)
