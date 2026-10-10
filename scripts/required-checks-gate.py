#!/usr/bin/env python3
"""Read live App-bound branch checks and exact-head PR settlement; never mutate GitHub."""
import json
import re
import subprocess
import sys
from urllib.parse import quote


def gh(*args):
    result = subprocess.run(['gh', *args], text=True, capture_output=True)
    if result.returncode:
        raise ValueError('required GitHub evidence unavailable')
    return json.loads(result.stdout)


def required_checks(branch, required=True):
    if not required and branch.get("protected") is False:
        return {}
    if branch.get('protected') is not True:
        raise ValueError('merge target is not protected')
    protection = branch.get('protection')
    if not isinstance(protection, dict):
        raise ValueError('configured target protection unavailable')
    policy = protection.get('required_status_checks')
    if not required and policy is None:
        return {}
    if not isinstance(policy, dict):
        raise ValueError('required status-check policy unavailable')
    checks = policy.get('checks')
    if not required and checks == [] and policy.get('contexts', []) == []:
        return {}
    if not isinstance(checks, list) or not checks:
        raise ValueError('required App-bound checks unavailable')
    expected = {}
    for check in checks:
        context, app = check.get('context'), check.get('app_id')
        if not isinstance(context, str) or not context or type(app) is not int or app <= 0:
            raise ValueError('required check has no explicit trusted App binding')
        if context in expected:
            raise ValueError('duplicate required check policy')
        expected[context] = app
    if set(policy.get('contexts', [])) != set(expected):
        raise ValueError('required contexts and App bindings disagree')
    return expected


def evaluate(expected, runs, sha):
    for name, app in expected.items():
        candidates = [run for run in runs if run.get('name') == name and run.get('app', {}).get('id') == app]
        if not candidates:
            raise ValueError('required check missing: ' + name)
        latest = max(candidates, key=lambda run: int(run['id']))
        if latest.get('head_sha') != sha or latest.get('status') != 'completed' or latest.get('conclusion') != 'success':
            raise ValueError('required check not successful on current head: ' + name)


def all_checks(repository, sha):
    runs = []
    for page in range(1, 11):
        response = gh('api', f'repos/{repository}/commits/{sha}/check-runs?per_page=100&filter=latest&page={page}')
        values = response['check_runs']
        if not isinstance(values, list):
            raise ValueError('malformed check-run inventory')
        runs.extend(values)
        if len(values) < 100:
            return runs
    raise ValueError('check-run pagination exceeded bound')


def settled(repository, number, sha):
    owner, name = repository.split('/')
    cursor = None
    query = '''query($owner:String!,$name:String!,$number:Int!,$cursor:String){repository(owner:$owner,name:$name){pullRequest(number:$number){headRefOid reviewThreads(first:100,after:$cursor){nodes{isResolved} pageInfo{hasNextPage endCursor}}}}}'''
    for _ in range(10):
        args = ['api','graphql','-f',f'query={query}','-f',f'owner={owner}','-f',f'name={name}','-F',f'number={number}']
        if cursor is not None:
            args += ['-f',f'cursor={cursor}']
        response = gh(*args)
        if response.get('errors'):
            raise ValueError('review-thread evidence unavailable')
        pull = response['data']['repository']['pullRequest']
        if pull['headRefOid'] != sha:
            raise ValueError('PR head moved during settlement read')
        threads = pull['reviewThreads']
        if not isinstance(threads['nodes'], list) or any(t.get('isResolved') is not True for t in threads['nodes']):
            raise ValueError('unresolved or malformed review conversations')
        if threads['pageInfo']['hasNextPage'] is False:
            return
        cursor = threads['pageInfo']['endCursor']
        if not isinstance(cursor, str) or not cursor:
            raise ValueError('review-thread pagination incomplete')
    raise ValueError('review-thread pagination exceeded bound')


def main(number, base, sha):
    if not re.fullmatch(r'[0-9a-f]{40}', sha) or not number.isdigit():
        raise ValueError('invalid PR identity')
    repository = gh('repo', 'view', '--json', 'nameWithOwner')['nameWithOwner']
    if not re.fullmatch(r'[\w.-]+/[\w.-]+', repository):
        raise ValueError('invalid repository identity')
    # Every child proves dev's current matrix; target protection may add checks.
    expected = required_checks(gh('api', f'repos/{repository}/branches/dev'))
    actual = {}
    if base != 'dev':
        actual = required_checks(gh('api', f'repos/{repository}/branches/{quote(base, safe="")}'), required=False)
    runs = all_checks(repository, sha)
    evaluate(expected, runs, sha)
    evaluate(actual, runs, sha)
    settled(repository, number, sha)
    current = gh('pr', 'view', number, '--json', 'headRefOid,baseRefName,state,isDraft')
    if current != {'headRefOid':sha,'baseRefName':base,'state':'OPEN','isDraft':False}:
        raise ValueError('PR moved, changed base, closed, or is draft')
    print('[required-checks] all current-head App-bound checks and review threads are green')

if __name__ == '__main__':
    try:
        main(*sys.argv[1:])
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError) as error:
        print('[required-checks] BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)
