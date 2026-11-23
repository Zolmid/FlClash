#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from urllib.parse import urlencode

REPOSITORY = 'Zolmid/FlClash'
REPOSITORY_ID = 1420254999
WORKFLOW = '.github/workflows/client-release.yml'
WORKFLOW_ID = 410545194
BUILD_WORKFLOW = f'{REPOSITORY}/.github/workflows/build.yaml'
API_ROOT = f'repos/{REPOSITORY}/actions'
CHECKS = ('Dart', 'Plugins', 'Go core', 'Android unit tests', 'Rust', 'Windows helper test')
PREFLIGHT = 'Formal tag preflight'
TAG = re.compile(r'v(0|[1-9][0-9]{0,9})\.(0|[1-9][0-9]{0,9})\.(0|[1-9][0-9]{0,9})')
MAX_WAIT_SECONDS = 900
POLL_SECONDS = 30
API_TIMEOUT_SECONDS = 10
ACTIVE = ('queued', 'in_progress', 'waiting', 'pending', 'requested')


@dataclass(frozen=True)
class Decision:
    result: str
    reason: str
    source: tuple = ()
    checks: tuple = ()


def candidate(env):
    tag = env.get('GITHUB_REF_NAME', '')
    ref = f'refs/tags/{tag}'
    return (env.get('GITHUB_REPOSITORY') == REPOSITORY
            and env.get('GITHUB_REPOSITORY_ID') == str(REPOSITORY_ID)
            and env.get('GITHUB_EVENT_NAME') == 'push'
            and env.get('GITHUB_REF_TYPE') == 'tag'
            and env.get('GITHUB_REF') == ref
            and env.get('GITHUB_WORKFLOW_REF') == f'{BUILD_WORKFLOW}@{ref}'
            and env.get('GITHUB_SERVER_URL') == 'https://github.com'
            and env.get('GITHUB_API_URL') == 'https://api.github.com'
            and env.get('EVENT_DELETED') == 'false'
            and env.get('OFFICIAL_INPUT') == 'null'
            and TAG.fullmatch(tag) is not None
            and re.fullmatch(r'[0-9a-f]{40}', env.get('GITHUB_SHA', '')) is not None
            and env['GITHUB_SHA'] != '0' * 40)


def positive_integer(value):
    return type(value) is int and value > 0


def matching_run(run, env, source):
    if not isinstance(run, dict):
        return False
    for key in ('repository', 'head_repository'):
        repo = run.get(key)
        if not isinstance(repo, dict) or repo.get('id') != REPOSITORY_ID or repo.get('full_name') != REPOSITORY:
            return False
    return (all(positive_integer(value) for value in source)
            and positive_integer(run.get('id')) and positive_integer(run.get('run_attempt'))
            and (run.get('id'), run.get('run_attempt')) == source
            and run.get('workflow_id') == WORKFLOW_ID and run.get('path') == WORKFLOW
            and run.get('event') == 'push' and run.get('head_sha') == env['GITHUB_SHA']
            and run.get('head_branch') == env['GITHUB_REF_NAME'])


def matching_reference(run, env):
    references = run.get('referenced_workflows')
    if not isinstance(references, list) or any(not isinstance(item, dict) for item in references):
        return False
    build = [item for item in references if str(item.get('path', '')).split('@')[0] == BUILD_WORKFLOW]
    return (len(build) == 1 and build[0].get('path') == f"{BUILD_WORKFLOW}@{env['GITHUB_SHA']}"
            and build[0].get('sha') == env['GITHUB_SHA'] and build[0].get('ref') == env['GITHUB_REF'])


def complete_page(payload, key):
    return (isinstance(payload, dict) and isinstance(payload.get(key), list)
            and type(payload.get('total_count')) is int
            and payload['total_count'] == len(payload[key]) <= 100
            and all(isinstance(item, dict) for item in payload[key]))


def completed_job(job):
    try:
        start = datetime.fromisoformat(job['started_at'].replace('Z', '+00:00'))
        end = datetime.fromisoformat(job['completed_at'].replace('Z', '+00:00'))
        return start.tzinfo is not None and end.tzinfo is not None and end >= start
    except (KeyError, AttributeError, TypeError, ValueError):
        return False


def decide(run, payload, env, source):
    if not matching_run(run, env, source):
        return Decision('local', 'run_identity_or_attempt_changed', source)
    if run.get('status') not in (*ACTIVE, 'completed'):
        return Decision('local', 'unknown_run_status', source)
    if run.get('conclusion') not in (None, 'success', 'failure'):
        return Decision('local', 'run_cancelled_or_unusable', source)
    if (run['status'] == 'completed') != (run.get('conclusion') is not None):
        return Decision('local', 'inconsistent_run_status', source)
    if not complete_page(payload, 'jobs'):
        return Decision('local', 'incomplete_jobs_response', source)
    names = (PREFLIGHT, *(f'Standard CI / {name}' for name in CHECKS))
    selected = [job for job in payload['jobs'] if job.get('name') in names]
    if len({job['name'] for job in selected}) != len(selected):
        return Decision('local', 'duplicate_job_name', source)
    if any(not all(positive_integer(job.get(key)) for key in ('id', 'run_id', 'run_attempt'))
           or (job.get('run_id'), job.get('run_attempt')) != source
           or job.get('head_sha') != env['GITHUB_SHA'] or job.get('head_branch') != env['GITHUB_REF_NAME']
           for job in selected) or len({job.get('id') for job in selected}) != len(selected):
        return Decision('local', 'job_identity_or_attempt_changed', source)
    for job in selected:
        if job.get('status') == 'completed':
            allowed = ('success',) if job['name'] == PREFLIGHT else ('success', 'failure')
            if job.get('conclusion') not in allowed or not completed_job(job):
                return Decision('local', 'preflight_or_job_incomplete', source)
        elif job.get('status') not in ACTIVE or job.get('conclusion') is not None:
            return Decision('local', 'unknown_job_status', source)
    if len(selected) != len(names) or any(job['status'] != 'completed' for job in selected):
        if run['status'] == 'completed':
            return Decision('local', 'missing_or_unfinished_jobs', source)
        return Decision('wait', 'awaiting_standard_checks', source)
    if not matching_reference(run, env):
        return Decision('local', 'reusable_workflow_source_unconfirmed', source)
    checks = tuple((job['name'], job['id'], job['conclusion']) for job in selected if job['name'] != PREFLIGHT)
    result = 'failure' if any(item[2] == 'failure' for item in checks) else 'success'
    return Decision(result, 'completed_standard_checks', source, checks)


class ApiError(Exception):
    pass


def read_api(path, timeout):
    try:
        response = subprocess.run(
            ['gh', 'api', '--hostname', 'github.com', '--method', 'GET', path],
            stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise ApiError('api_timeout') from None
    except (OSError, UnicodeError):
        raise ApiError('api_unavailable') from None
    if response.returncode:
        status = re.search(r'\(HTTP ([0-9]{3})\)', response.stderr)
        raise ApiError(f'api_http_{status[1]}' if status else 'api_error') from None
    try:
        return json.loads(response.stdout)
    except (ValueError, TypeError):
        raise ApiError('api_invalid_json') from None


def observe(env, get=read_api, clock=time.monotonic, sleep=time.sleep, log=print):
    if not candidate(env):
        return Decision('local', 'not_an_independent_formal_tag_push')
    start = clock()
    deadline = start + MAX_WAIT_SECONDS
    source = ()

    def request(path):
        remaining = deadline - clock()
        if remaining <= 0:
            raise ApiError('observation_timeout')
        try:
            data = get(path, min(API_TIMEOUT_SECONDS, remaining))
        except ApiError as error:
            log(json.dumps({'api': path, 'result': str(error), 'elapsed_seconds': round(clock() - start)}))
            raise
        log(json.dumps({'api': path, 'result': 'ok', 'elapsed_seconds': round(clock() - start)}))
        if clock() >= deadline:
            raise ApiError('observation_timeout')
        return data

    while clock() < deadline:
        try:
            if not source:
                query = urlencode({'event': 'push', 'head_sha': env['GITHUB_SHA'],
                                   'branch': env['GITHUB_REF_NAME'], 'per_page': 100})
                runs = request(f'{API_ROOT}/workflows/{WORKFLOW_ID}/runs?{query}')
                if not complete_page(runs, 'workflow_runs') or len(runs['workflow_runs']) > 1:
                    return Decision('local', 'ambiguous_or_incomplete_run_list')
                if runs['workflow_runs']:
                    run = runs['workflow_runs'][0]
                    source = (run.get('id'), run.get('run_attempt'))
                    if not matching_run(run, env, source):
                        return Decision('local', 'run_identity_unconfirmed')
            decision = Decision('wait', 'awaiting_formal_run')
            if source:
                path = f'{API_ROOT}/runs/{source[0]}'
                run = request(path)
                if not matching_run(run, env, source):
                    return Decision('local', 'run_identity_or_attempt_changed', source)
                jobs = request(f'{path}/attempts/{source[1]}/jobs?per_page=100')
                decision = decide(run, jobs, env, source)
                if decision.result in ('success', 'failure'):
                    # A rerun must not mix the preceding attempt's completed jobs into the current one.
                    decision = decide(request(path), jobs, env, source)
            log(json.dumps({'result': decision.result, 'reason': decision.reason,
                            'source': source, 'elapsed_seconds': round(clock() - start)}))
            if decision.result != 'wait':
                return decision
        except ApiError as error:
            return Decision('local', str(error), source)
        sleep(min(POLL_SECONDS, max(0, deadline - clock())))
    return Decision('local', 'observation_timeout', source)


def report(decision, env):
    delegated = decision.result in ('success', 'failure')
    with Path(env['GITHUB_OUTPUT']).open('a') as output:
        output.write(f'delegated={str(delegated).lower()}\nresult={decision.result}\n')
    with Path(env['GITHUB_STEP_SUMMARY']).open('a') as summary:
        if delegated:
            run_id, attempt = decision.source
            summary.write(f'Standard CI reused **{decision.result}** from '
                          f'[{run_id}, attempt {attempt}](https://github.com/{REPOSITORY}/actions/runs/{run_id}/attempts/{attempt}).\n\n')
            for name, job_id, conclusion in decision.checks:
                summary.write(f'- {name}: {conclusion} (job {job_id})\n')
            summary.write('\nThe six local jobs are skipped; their completed results above were observed, not rerun.\n')
        else:
            summary.write(f'No Standard CI results reused ({decision.reason}). Original check conditions remain active.\n')
    print(json.dumps({'result': decision.result, 'reason': decision.reason, 'source': decision.source}))


def interrupted(_signum, _frame):
    raise KeyboardInterrupt


def main():
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        decision = observe(os.environ)
    except KeyboardInterrupt:
        report(Decision('local', 'observation_cancelled'), os.environ)
        return 130
    report(decision, os.environ)
    return 1 if decision.result == 'failure' else 0


if __name__ == '__main__':
    if sys.argv[1:] == ['--candidate']:
        print(f'observe={str(candidate(os.environ)).lower()}')
    else:
        raise SystemExit(main())
