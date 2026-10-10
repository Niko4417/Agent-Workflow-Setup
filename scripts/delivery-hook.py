#!/usr/bin/env python3
"""Route recognized delivery commands without executing shell text; fail closed."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


def shell_changes_execution(command):
    quote = None
    escaped = False
    for i, character in enumerate(command):
        if escaped:
            escaped = False
            continue
        if character == '\\' and quote != "'":
            escaped = True
            continue
        if character in ("'", '"'):
            if quote == character:
                quote = None
            elif quote is None:
                quote = character
            continue
        if quote != "'" and (character == '`' or command[i:i+2] == '$('):
            return True
        if quote is None and character in ';|&<>\n':
            return True
    return False


def operation(command):
    # Ignore a simple heredoc body, but still inspect commands after its delimiter.
    # This is a bounded exclusion for editing commands, not a shell parser.
    lines = command.splitlines(keepends=True)
    if lines and '<<' in lines[0]:
        import re
        match = re.search(r"<<(-?)\s*(['\"]?)([A-Za-z_][A-Za-z_0-9]*)\2", lines[0])
        if match:
            delimiter = match[3]
            for end, line in enumerate(lines[1:], 1):
                if (line.lstrip('\t') if match[1] else line).rstrip('\r\n') == delimiter:
                    command = lines[0][:match.start()] + lines[0][match.end():] + '\n' + ''.join(lines[end + 1:])
                    break
    args = shlex.split(command)
    # Normalize line separators for recognition only; quoted argument text stays one token.
    lexer = shlex.shlex(command.replace('\n', ' ; '), posix=True, punctuation_chars=';&|<>')
    lexer.whitespace_split = True
    lexer.commenters = ''
    tokens = list(lexer)
    for index, token in enumerate(tokens):
        executable = Path(token).name
        # Only command positions count; quoted argument examples are not commands.
        if index and tokens[index - 1] not in (';', '&&', '||', '|', '&', '\n', '--', 'env', 'command', 'sudo') and '=' not in tokens[index - 1]:
            continue
        tail = tokens[index + 1:]
        boundary = next((i for i, word in enumerate(tail) if word in (';', '&&', '||', '|', '&', '\n')), len(tail))
        tail = tail[:boundary]
        if executable == 'gh' and 'pr' in tail:
            position = tail.index('pr')
            if position + 1 < len(tail) and tail[position + 1] in ('create','ready','merge'):
                if tail[position + 2:] in (['--help'], ['-h']):
                    return None, args
                return tail[position + 1], args
        if executable == 'git' and 'push' in tail:
            return 'push', args
    return None, args


MATCHES = {'audit-gate':('create','ready'), 'verify-gate':('create','ready'),
           'ready-gate':('ready',), 'epic-merge-gate':('merge',), 'push-gate':('push',)}
GATES = {'create':('verify-gate','audit-gate'),
         'ready':('verify-gate','audit-gate','ready-gate'),
         'merge':('epic-merge-gate',), 'push':('push-gate',)}
ENTRYPOINT = 'delivery-command.py'


def validate_root(value):
    if not isinstance(value, str) or not Path(value).is_absolute():
        raise ValueError('delivery requires an explicit absolute Git root')
    root = Path(value)
    if str(root.resolve()) != value:
        raise ValueError('delivery root must be canonical, without aliases')
    for name in ('GH_REPO','GH_HOST','GIT_DIR','GIT_WORK_TREE','GIT_COMMON_DIR',
                 'GIT_INDEX_FILE','GIT_NAMESPACE','GIT_CONFIG','GIT_CONFIG_COUNT',
                 'GIT_CONFIG_PARAMETERS'):
        if name in os.environ:
            raise ValueError('repository-changing environment is denied: ' + name)
    actual = subprocess.check_output(['git','rev-parse','--show-toplevel'], cwd=root, text=True).strip()
    if actual != value:
        raise ValueError('delivery root must be the exact Git top level')
    scripts = root / '.keiko-scripts'
    if scripts.resolve() != Path(__file__).resolve().parent:
        raise ValueError('target helpers must use the same reviewed source as the dispatcher')
    branch = subprocess.check_output(['git','symbolic-ref','--quiet','--short','HEAD'], cwd=root, text=True).strip()
    if not branch.startswith(('issue/','epic/','codex/')):
        raise ValueError('delivery requires an assigned issue, epic or codex branch')
    return root, branch


def validate_inner(args, branch):
    if args[:2] == ['git','push']:
        tail = args[2:]
        tail = [arg for arg in tail if arg not in ('-u','--set-upstream','--dry-run','-n','--porcelain','--verbose','-v','--quiet','-q')]
        refs = (branch,'HEAD:' + branch,branch + ':' + branch,'HEAD:refs/heads/' + branch)
        if len(tail) != 2 or tail[0] != 'origin' or tail[1] not in refs:
            raise ValueError('use git push [-u|--set-upstream] origin <current-branch>')
        return 'push'
    if len(args) < 3 or args[:2] != ['gh','pr'] or args[2] not in GATES:
        raise ValueError('unsupported delivery argv or executable prefix')
    action = args[2]
    if action == 'merge':
        # The existing merge gate parses every flag and binds the live head.
        return action
    if action == 'ready':
        if len(args) != 4 or not args[3].isascii() or not args[3].isdigit() or int(args[3]) <= 0:
            raise ValueError('use gh pr ready <positive PR number> without overrides')
        return action
    value_flags = {'--base','--head','--title','--body','--body-file','--label',
                   '--assignee','--reviewer','--milestone','--project',
                   '-B','-H','-t','-b','-F','-l','-a','-r','-m','-p'}
    seen = set()
    index = 3
    while index < len(args):
        flag, separator, value = args[index].partition('=')
        flag = {'-B':'--base','-H':'--head','-t':'--title','-b':'--body','-F':'--body-file'}.get(flag, flag)
        if flag in ('--draft','--dry-run') and not separator:
            index += 1
            continue
        if flag not in value_flags:
            raise ValueError('unsupported create flag or repository override: ' + flag)
        if not separator:
            if index + 1 >= len(args):
                raise ValueError('missing create flag value')
            value = args[index + 1]
            index += 1
        if not value or (flag in ('--base','--head') and flag in seen):
            raise ValueError('empty or repeated branch selector')
        if flag == '--head' and value != branch:
            raise ValueError('PR head must be the verified local branch')
        seen.add(flag)
        index += 1
    return action


def delivery_context(args, effective_workdir=None):
    if len(args) >= 2 and args[0] == 'python3' and Path(args[1]).name == ENTRYPOINT:
        if len(args) < 7 or args[2] != '--root' or args[4] != '--':
            raise ValueError('use python3 <root>/.keiko-scripts/delivery-command.py --root <root> -- <delivery argv>')
        root, branch = validate_root(args[3])
        expected = root / '.keiko-scripts' / ENTRYPOINT
        if args[1] != str(expected) or expected.resolve() != Path(__file__).resolve().with_name(ENTRYPOINT):
            raise ValueError('entrypoint path and declared root must match the reviewed source')
        inner = args[5:]
    else:
        if effective_workdir is None:
            raise ValueError('effective tool workdir is unavailable; use the explicit-root delivery entrypoint')
        root, branch = validate_root(effective_workdir)
        inner = args
    return root, inner, validate_inner(inner, branch)


def run_gate(root, gate, inner):
    helper = root / '.keiko-scripts' / (gate + '.sh')
    if not helper.is_file() or not os.access(helper, os.X_OK):
        raise ValueError('required helper missing or not executable: ' + str(helper))
    invocation = [str(helper)] + ([shlex.join(inner)] if gate in ('epic-merge-gate','ready-gate') else [])
    return 0 if subprocess.run(invocation, cwd=root).returncode == 0 else 2


def main(gate):
    payload = json.load(sys.stdin)
    command = payload.get('tool_input', {}).get('command', '')
    if not isinstance(command, str):
        raise ValueError('malformed shell command payload')
    action, args = operation(command)
    if gate not in MATCHES:
        raise ValueError('unknown delivery gate')
    if action not in MATCHES[gate]:
        return 0
    if shell_changes_execution(command):
        raise ValueError('delivery commands must be one command without shell chaining/substitution or cd')
    root, inner, action = delivery_context(args, payload.get('tool_input', {}).get('workdir'))
    return run_gate(root, gate, inner)


def entrypoint_main(args):
    # Revalidate at execution too: another tool or disabled hooks cannot skip proof.
    root, inner, action = delivery_context(['python3', sys.argv[0]] + args)
    for gate in GATES[action]:
        if run_gate(root, gate, inner):
            return 2
    return subprocess.run(inner, cwd=root).returncode

if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1]))
    except (ValueError, KeyError, IndexError, OSError, subprocess.CalledProcessError) as error:
        print('[delivery-gate] BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(2)
