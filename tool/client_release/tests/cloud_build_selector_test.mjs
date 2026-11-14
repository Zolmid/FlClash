import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { after, test } from 'node:test';
import { selectCloudBuild } from '../../ci/cloud_build_selector.mjs';

const MODULE = fileURLToPath(new URL('../../ci/cloud_build_selector.mjs', import.meta.url));
const WORKFLOW = fileURLToPath(new URL('../../../.github/workflows/cloud-build.yml', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'cloud-build-selector-test-'));
after(() => rmSync(scratch, {recursive: true, force: true}));

// Heredoc body of the select step at bfb49ed8a41a9b531a64783f9407959085e4444e, cloud-build.yml lines 78-102.
const BASE_SELECTOR = [
  "const fs = require('fs');",
  "const official = process.env.OFFICIAL_REQUESTED === 'true';",
  "if (official && (process.env.OFFICIAL_TRUSTED !== 'true' || process.env.PLATFORM !== 'all' || process.env.IOS_SOURCE !== 'project')) {",
  "  throw new Error('Official builds run only from client-release.yml on a Zolmid/FlClash tag push, for every platform');",
  "}",
  "if (process.env.ANDROID_RELEASE_REQUESTED === 'true' &&",
  "    (process.env.CLIENT_BRANCH !== 'true' || !['all', 'android'].includes(process.env.PLATFORM))) {",
  "  throw new Error('Android release requires a client branch and an Android target');",
  "}",
  "const targets = [",
  "  {platform: 'linux', os: 'ubuntu-22.04', arch: 'x64'},",
  "  {platform: 'windows', os: 'windows-2022', arch: 'x64'},",
  "  {platform: 'android', os: 'ubuntu-24.04', arch: 'arm64'},",
  "  {platform: 'macos', os: 'xcode-27', arch: 'arm64'},",
  "  {platform: 'macos', os: 'xcode-27', arch: 'x64', flutter_arch: 'x64'},",
  "].map(t => ({...t, safe_preview: false}))",
  "  .filter(t => process.env.PLATFORM === 'all' || t.platform === process.env.PLATFORM);",
  "if (process.env.CLIENT_BRANCH === 'true' && ['all', 'macos'].includes(process.env.PLATFORM)) {",
  "  targets.push({platform: 'macos', os: 'xcode-27', arch: 'arm64', safe_preview: true});",
  "}",
  "const clientBranch = process.env.CLIENT_BRANCH === 'true' || official;",
  "const androidRelease = process.env.ANDROID_RELEASE === 'true' || official;",
  "const nativeUi = process.env.NATIVE_BRANCH === 'true' || official;",
  "fs.appendFileSync(process.env.GITHUB_OUTPUT,",
  "  `platform=${process.env.PLATFORM}\\nios_source=${process.env.IOS_SOURCE}\\nandroid_release=${androidRelease}\\nofficial=${official}\\nclient_branch=${clientBranch}\\nnative_ui=${nativeUi}\\nmatrix=${JSON.stringify({include: targets})}\\nenabled=${targets.length > 0}\\n`);",
].map(line => line + '\n').join('');
const BASE_SELECTOR_SHA256 = 'ddd300ab8742c59d7432a2c0ebc3a4fe1e25ca61e4b37bf5a5c59fed644d11c5';

const ZC = 'refs/heads/codex/zolnit-client', NCS = 'refs/heads/codex/native-client-shared';
const IOS = 'refs/heads/codex/ios-support';
const OFFICIAL_ERROR = 'Official builds run only from client-release.yml on a Zolmid/FlClash tag push, for every platform';
const ANDROID_ERROR = 'Android release requires a client branch and an Android target';
const KEYS = ['platform', 'ios_source', 'android_release', 'official', 'client_branch', 'native_ui', 'matrix', 'enabled'];
const LINUX = {platform: 'linux', os: 'ubuntu-22.04', arch: 'x64', safe_preview: false};
const WINDOWS = {platform: 'windows', os: 'windows-2022', arch: 'x64', safe_preview: false};
const ANDROID = {platform: 'android', os: 'ubuntu-24.04', arch: 'arm64', safe_preview: false};
const MAC_ARM = {platform: 'macos', os: 'xcode-27', arch: 'arm64', safe_preview: false};
const MAC_X64 = {platform: 'macos', os: 'xcode-27', arch: 'x64', flutter_arch: 'x64', safe_preview: false};
const MAC_PREVIEW = {platform: 'macos', os: 'xcode-27', arch: 'arm64', safe_preview: true};
const ALL = [LINUX, WINDOWS, ANDROID, MAC_ARM, MAC_X64];

// Model of the select job env expressions: GitHub evaluates them, these tests never run GitHub itself.
const truthy = v => !(v === false || v === null || v === 0 || v === '');
const and = (...xs) => xs.some(x => !truthy(x)) ? xs.find(x => !truthy(x)) : xs.at(-1);
const or = (...xs) => xs.some(truthy) ? xs.find(truthy) : xs.at(-1);
const eq = (a, b) => typeof a === 'string' && typeof b === 'string' ? a.toLowerCase() === b.toLowerCase() : a === b;
const str = v => v === null ? '' : String(v);
function githubEnv({event, ref, refType = 'branch', repository = 'Zolmid/FlClash', repositoryId = '1420254999',
  workflowRef = '', inputs = {}}) {
  const input = name => inputs[name] ?? null;
  const clientRef = eq(ref, ZC) || eq(ref, NCS);
  return Object.fromEntries(Object.entries({
    PLATFORM: or(and(eq(event, 'push'), or(and(eq(ref, IOS), 'ios'), 'all')), input('platform'), 'all'),
    IOS_SOURCE: or(and(eq(event, 'push'), 'project'), input('ios_source'), 'project'),
    CLIENT_BRANCH: clientRef,
    NATIVE_BRANCH: eq(ref, NCS),
    ANDROID_RELEASE_REQUESTED: and(eq(event, 'workflow_dispatch'), input('android_release')),
    ANDROID_RELEASE: and(eq(event, 'workflow_dispatch'), input('android_release'), clientRef),
    OFFICIAL_REQUESTED: input('official_release') === true,
    OFFICIAL_TRUSTED: and(eq(event, 'push'), eq(repository, 'Zolmid/FlClash'), eq(repositoryId, '1420254999'),
      eq(refType, 'tag'), ref.toLowerCase().startsWith('refs/tags/v'),
      eq(workflowRef, `Zolmid/FlClash/.github/workflows/client-release.yml@${ref}`)),
    BUILD_PROFILE: input('build_profile'),
    GITHUB_EVENT_NAME: event,
  }).map(([k, v]) => [k, str(v)]));
}

const cases = [];
const add = (name, env) => cases.push({name, env});
for (const branch of ['main', 'codex/patched-integration', 'codex/ios-support', 'codex/upstream-0.9.1',
  'codex/zolnit-client', 'codex/native-client-shared']) {
  add(`push ${branch}`, githubEnv({event: 'push', ref: `refs/heads/${branch}`}));
}
for (const branch of ['main', 'codex/ios-support', 'codex/zolnit-client', 'codex/native-client-shared']) {
  for (const platform of ['all', 'macos', 'windows', 'android', 'ios', 'linux']) {
    for (const iosSource of ['project', 'patched-reference']) {
      for (const androidRelease of [false, true]) {
        add(`dispatch ${branch} ${platform} ${iosSource} android=${androidRelease}`, githubEnv({event: 'workflow_dispatch',
          ref: `refs/heads/${branch}`, inputs: {platform, ios_source: iosSource, android_release: androidRelease}}));
      }
    }
  }
}
const TAG = 'refs/tags/v1.2.3';
const workflowAt = (file, ref) => `Zolmid/FlClash/.github/workflows/${file}@${ref}`;
const release = (overrides = {}) => githubEnv({event: 'push', ref: TAG, refType: 'tag',
  workflowRef: workflowAt('client-release.yml', TAG), inputs: {official_release: true}, ...overrides});
add('official trusted', release());
add('official repository case folds', release({repository: 'zolmid/flclash'}));
add('official not requested', release({inputs: {official_release: false}}));
add('official input absent', release({inputs: {}}));
add('official wrong repository', release({repository: 'Other/FlClash'}));
add('official wrong repository id', release({repositoryId: '1'}));
add('official branch ref', release({ref: 'refs/heads/main', refType: 'branch',
  workflowRef: workflowAt('client-release.yml', 'refs/heads/main')}));
add('official non-v tag', release({ref: 'refs/tags/x1', workflowRef: workflowAt('client-release.yml', 'refs/tags/x1')}));
add('official other workflow', release({workflowRef: workflowAt('cloud-build.yml', TAG)}));
add('official workflow at other ref', release({workflowRef: workflowAt('client-release.yml', 'refs/tags/v9')}));
add('official from dispatch caller', release({event: 'workflow_dispatch'}));
add('official on client branch push', release({ref: ZC, refType: 'branch', workflowRef: workflowAt('client-release.yml', ZC)}));
add('workflow_call from dispatch without android input', githubEnv({event: 'workflow_dispatch', ref: ZC,
  inputs: {official_release: false}}));
add('env absent', {});
add('env all false', {PLATFORM: 'all', IOS_SOURCE: 'project', CLIENT_BRANCH: 'false', NATIVE_BRANCH: 'false',
  ANDROID_RELEASE_REQUESTED: 'false', ANDROID_RELEASE: 'false', OFFICIAL_REQUESTED: 'false', OFFICIAL_TRUSTED: 'false'});
add('env empty strings', {PLATFORM: 'all', IOS_SOURCE: 'project', CLIENT_BRANCH: '', ANDROID_RELEASE_REQUESTED: '',
  ANDROID_RELEASE: '', OFFICIAL_REQUESTED: '', OFFICIAL_TRUSTED: ''});
for (const value of ['TRUE', '1', ' true', 'true ']) {
  add(`env official ${JSON.stringify(value)}`, {PLATFORM: 'macos', IOS_SOURCE: 'project', OFFICIAL_REQUESTED: value});
  add(`env android requested ${JSON.stringify(value)}`, {PLATFORM: 'ios', IOS_SOURCE: 'project',
    ANDROID_RELEASE_REQUESTED: value});
}
add('env official trusted macos', {PLATFORM: 'macos', IOS_SOURCE: 'project', OFFICIAL_REQUESTED: 'true',
  OFFICIAL_TRUSTED: 'true'});
add('env official trusted patched', {PLATFORM: 'all', IOS_SOURCE: 'patched-reference', OFFICIAL_REQUESTED: 'true',
  OFFICIAL_TRUSTED: 'true'});
add('env official and android both invalid', {PLATFORM: 'ios', IOS_SOURCE: 'project', OFFICIAL_REQUESTED: 'true',
  ANDROID_RELEASE_REQUESTED: 'true'});
add('env android release without request', {PLATFORM: 'linux', IOS_SOURCE: 'project', ANDROID_RELEASE: 'true'});
add('env client ios', {PLATFORM: 'ios', IOS_SOURCE: 'project', CLIENT_BRANCH: 'true'});
add('env unknown platform', {PLATFORM: 'freebsd', IOS_SOURCE: 'project', CLIENT_BRANCH: 'true'});
add('env platform absent client', {IOS_SOURCE: 'project', CLIENT_BRANCH: 'true', ANDROID_RELEASE_REQUESTED: 'true'});

let runs = 0;
function execute(args, input, env) {
  const output = join(scratch, `output-${runs++}`);
  writeFileSync(output, '');
  const run = spawnSync(process.execPath, args, {input, env: {...env, GITHUB_OUTPUT: output}, timeout: 10000,
    encoding: 'utf8'});
  assert.equal(run.error, undefined);
  return {status: run.status, stdout: run.stdout, bytes: readFileSync(output),
    error: run.stderr.match(/^Error: .*$/m)?.[0] ?? null};
}

function parse(bytes) {
  const lines = bytes.toString('utf8').split('\n');
  assert.equal(lines.pop(), '');
  return Object.fromEntries(lines.map(line => [line.slice(0, line.indexOf('=')), line.slice(line.indexOf('=') + 1)]));
}

const results = new Map();
function resultOf(name) {
  if (!results.has(name)) {
    const found = cases.find(c => c.name === name);
    assert.ok(found, name);
    results.set(name, {base: execute([], BASE_SELECTOR, found.env), current: execute([MODULE], undefined, found.env)});
  }
  return results.get(name);
}

test('base reference is the unmodified inline selector', () => {
  assert.equal(createHash('sha256').update(BASE_SELECTOR).digest('hex'), BASE_SELECTOR_SHA256);
  assert.equal(new Set(cases.map(c => c.name)).size, cases.length);
});

test('base inline selector and module CLI agree on every case', () => {
  assert.equal(cases.length, 133);
  for (const {name, env} of cases) {
    const {base, current} = resultOf(name);
    assert.equal(current.status, base.status, name);
    assert.equal(current.error, base.error, name);
    assert.equal(current.stdout, '', name);
    assert.equal(base.stdout, '', name);
    assert.ok(current.bytes.equals(base.bytes), name);
    if (base.status === 0) {
      assert.equal(selectCloudBuild(env), base.bytes.toString('utf8'), name);
      assert.deepEqual(Object.keys(parse(base.bytes)), KEYS, name);
    } else {
      assert.equal(base.bytes.length, 0, name);
      assert.throws(() => selectCloudBuild(env), {message: base.error.slice('Error: '.length)}, name);
    }
  }
});

function expectOutput(name, expected) {
  const {matrix, ...flags} = expected;
  for (const result of Object.values(resultOf(name))) {
    assert.equal(result.status, 0, name);
    const parsed = parse(result.bytes);
    assert.deepEqual(JSON.parse(parsed.matrix), {include: matrix}, name);
    for (const [key, value] of Object.entries(flags)) assert.equal(parsed[key], value, `${name} ${key}`);
    assert.equal(parsed.enabled, String(matrix.length > 0), name);
  }
}

function expectRejection(name, message) {
  for (const result of Object.values(resultOf(name))) {
    assert.equal(result.status, 1, name);
    assert.equal(result.error, `Error: ${message}`, name);
    assert.equal(result.bytes.length, 0, name);
  }
}

const standard = {ios_source: 'project', android_release: 'false', official: 'false', client_branch: 'false',
  native_ui: 'false'};

test('push branches select the expected matrices', () => {
  expectOutput('push main', {...standard, platform: 'all', matrix: ALL});
  expectOutput('push codex/upstream-0.9.1', {...standard, platform: 'all', matrix: ALL});
  expectOutput('push codex/ios-support', {...standard, platform: 'ios', matrix: []});
  expectOutput('push codex/zolnit-client', {...standard, platform: 'all', client_branch: 'true',
    matrix: [...ALL, MAC_PREVIEW]});
  expectOutput('push codex/native-client-shared', {...standard, platform: 'all', client_branch: 'true',
    native_ui: 'true', matrix: [...ALL, MAC_PREVIEW]});
  assert.equal(resultOf('push main').base.bytes.toString('utf8'), 'platform=all\nios_source=project\n' +
    'android_release=false\nofficial=false\nclient_branch=false\nnative_ui=false\nmatrix=' +
    '{"include":[{"platform":"linux","os":"ubuntu-22.04","arch":"x64","safe_preview":false},' +
    '{"platform":"windows","os":"windows-2022","arch":"x64","safe_preview":false},' +
    '{"platform":"android","os":"ubuntu-24.04","arch":"arm64","safe_preview":false},' +
    '{"platform":"macos","os":"xcode-27","arch":"arm64","safe_preview":false},' +
    '{"platform":"macos","os":"xcode-27","arch":"x64","flutter_arch":"x64","safe_preview":false}]}\nenabled=true\n');
});

test('manual platforms keep order, runners and the client safe preview', () => {
  expectOutput('dispatch main macos project android=false', {...standard, platform: 'macos', matrix: [MAC_ARM, MAC_X64]});
  expectOutput('dispatch codex/zolnit-client macos project android=false', {...standard, platform: 'macos',
    client_branch: 'true', matrix: [MAC_ARM, MAC_X64, MAC_PREVIEW]});
  expectOutput('dispatch main windows project android=false', {...standard, platform: 'windows', matrix: [WINDOWS]});
  expectOutput('dispatch main linux project android=false', {...standard, platform: 'linux', matrix: [LINUX]});
  expectOutput('dispatch main android project android=false', {...standard, platform: 'android', matrix: [ANDROID]});
  expectOutput('dispatch main ios patched-reference android=false', {...standard, platform: 'ios',
    ios_source: 'patched-reference', matrix: []});
  expectOutput('dispatch codex/zolnit-client ios project android=false', {...standard, platform: 'ios',
    client_branch: 'true', matrix: []});
  expectOutput('dispatch main all patched-reference android=false', {...standard, platform: 'all',
    ios_source: 'patched-reference', matrix: ALL});
});

test('Android release needs a client branch and an Android target', () => {
  expectOutput('dispatch codex/zolnit-client android project android=true', {...standard, platform: 'android',
    android_release: 'true', client_branch: 'true', matrix: [ANDROID]});
  expectOutput('dispatch codex/native-client-shared all project android=true', {...standard, platform: 'all',
    android_release: 'true', client_branch: 'true', native_ui: 'true', matrix: [...ALL, MAC_PREVIEW]});
  for (const name of ['dispatch main android project android=true', 'dispatch codex/ios-support all project android=true',
    'dispatch codex/zolnit-client macos project android=true',
    'dispatch codex/zolnit-client ios patched-reference android=true', 'env platform absent client']) {
    expectRejection(name, ANDROID_ERROR);
  }
  for (const value of ['TRUE', '1', ' true', 'true ']) {
    expectOutput(`env android requested ${JSON.stringify(value)}`, {...standard, platform: 'ios', matrix: []});
  }
  expectOutput('env android release without request', {...standard, platform: 'linux', android_release: 'true',
    matrix: [LINUX]});
  expectOutput('workflow_call from dispatch without android input', {...standard, platform: 'all',
    client_branch: 'true', matrix: [...ALL, MAC_PREVIEW]});
  assert.equal(githubEnv({event: 'push', ref: ZC}).ANDROID_RELEASE_REQUESTED, 'false');
  assert.equal(githubEnv({event: 'workflow_dispatch', ref: ZC}).ANDROID_RELEASE_REQUESTED, '');
});

test('official builds require the trusted client-release tag push for every platform', () => {
  const official = {platform: 'all', ios_source: 'project', android_release: 'true', official: 'true',
    client_branch: 'true', native_ui: 'true'};
  expectOutput('official trusted', {...official, matrix: ALL});
  expectOutput('official repository case folds', {...official, matrix: ALL});
  expectOutput('official not requested', {...standard, platform: 'all', matrix: ALL});
  expectOutput('official input absent', {...standard, platform: 'all', matrix: ALL});
  for (const name of ['official wrong repository', 'official wrong repository id', 'official branch ref',
    'official non-v tag', 'official other workflow', 'official workflow at other ref', 'official from dispatch caller',
    'official on client branch push', 'env official trusted macos', 'env official trusted patched',
    'env official and android both invalid']) {
    expectRejection(name, OFFICIAL_ERROR);
  }
  for (const value of ['TRUE', '1', ' true', 'true ']) {
    expectOutput(`env official ${JSON.stringify(value)}`, {...standard, platform: 'macos', matrix: [MAC_ARM, MAC_X64]});
  }
});

test('absent and non-boolean env values fall back like the inline selector', () => {
  expectOutput('env absent', {...standard, platform: 'undefined', ios_source: 'undefined', matrix: []});
  expectOutput('env all false', {...standard, platform: 'all', matrix: ALL});
  expectOutput('env empty strings', {...standard, platform: 'all', matrix: ALL});
  expectOutput('env client ios', {...standard, platform: 'ios', client_branch: 'true', matrix: []});
  expectOutput('env unknown platform', {...standard, platform: 'freebsd', client_branch: 'true', matrix: []});
});

test('select job keeps its env expressions and only runs the checked-out selector', () => {
  const workflow = readFileSync(WORKFLOW, 'utf8');
  const job = workflow.slice(workflow.indexOf('\n  select:\n'), workflow.indexOf('\n  project:\n'));
  assert.equal(job, [
    '',
    '  select:',
    '    runs-on: ubuntu-24.04',
    '    outputs:',
    ...['matrix', 'enabled', ...KEYS.slice(0, 6)].map(key => `      ${key}: \${{ steps.select.outputs.${key} }}`),
    '    env:',
    "      PLATFORM: ${{ github.event_name == 'push' && (github.ref == 'refs/heads/codex/ios-support' && 'ios' || 'all') || inputs.platform || 'all' }}",
    "      IOS_SOURCE: ${{ github.event_name == 'push' && 'project' || inputs.ios_source || 'project' }}",
    "      CLIENT_BRANCH: ${{ github.ref == 'refs/heads/codex/zolnit-client' || github.ref == 'refs/heads/codex/native-client-shared' }}",
    "      NATIVE_BRANCH: ${{ github.ref == 'refs/heads/codex/native-client-shared' }}",
    "      ANDROID_RELEASE_REQUESTED: ${{ github.event_name == 'workflow_dispatch' && inputs.android_release }}",
    "      ANDROID_RELEASE: ${{ github.event_name == 'workflow_dispatch' && inputs.android_release && (github.ref == 'refs/heads/codex/zolnit-client' || github.ref == 'refs/heads/codex/native-client-shared') }}",
    '      OFFICIAL_REQUESTED: ${{ inputs.official_release == true }}',
    "      OFFICIAL_TRUSTED: ${{ github.event_name == 'push' && github.repository == 'Zolmid/FlClash' && github.repository_id == '1420254999' && github.ref_type == 'tag' && startsWith(github.ref, 'refs/tags/v') && github.workflow_ref == format('Zolmid/FlClash/.github/workflows/client-release.yml@{0}', github.ref) }}",
    '      BUILD_PROFILE: ${{ inputs.build_profile }}',
    '    steps:',
    '      - uses: actions/checkout@v5',
    '        with:',
    '          persist-credentials: false',
    '      - id: select',
    '        run: node tool/ci/cloud_build_selector.mjs',
    '',
  ].join('\n'));
});

test('importing the selector writes nothing and it reaches no process or network API', async () => {
  const probe = join(scratch, 'import-probe');
  const previous = process.env.GITHUB_OUTPUT;
  process.env.GITHUB_OUTPUT = probe;
  try {
    const module = await import(`${pathToFileURL(MODULE).href}?import-probe`);
    assert.equal(typeof module.selectCloudBuild, 'function');
  } finally {
    if (previous === undefined) delete process.env.GITHUB_OUTPUT; else process.env.GITHUB_OUTPUT = previous;
  }
  assert.equal(existsSync(probe), false);
  const source = readFileSync(MODULE, 'utf8');
  assert.deepEqual([...source.matchAll(/from '([^']+)'/g)].map(m => m[1]), ['node:fs', 'node:url']);
  assert.doesNotMatch(source, /import\(|require\(|child_process|fetch|https?:|node:net|spawn|exec/);
});
const PROFILE_ERROR = 'The zolnit build profile runs only from a manual dispatch with the project iOS source';
const NEW_REF = 'refs/heads/codex/refactor-candidate';
const PLATFORMS = ['all', 'macos', 'windows', 'android', 'ios', 'linux'];
const PUSH_REFS = ['main', 'codex/patched-integration', 'codex/ios-support', 'codex/upstream-0.9.1', 'codex/zolnit-client',
  'codex/native-client-shared'].map(branch => `refs/heads/${branch}`);
const dispatch = (ref, inputs) => githubEnv({event: 'workflow_dispatch', ref, inputs});
const outcome = run => {
  try {
    return {output: run()};
  } catch (error) {
    return {error: error.message};
  }
};

function runBaseSelector(env) {
  let written = '';
  const fs = {appendFileSync(file, data) {
    assert.equal(file, 'github-output');
    written += data;
  }};
  new Function('require', 'process', BASE_SELECTOR)(name => {
    assert.equal(name, 'fs');
    return fs;
  }, {env: {...env, GITHUB_OUTPUT: 'github-output'}});
  return written;
}

test('auto, empty and absent profiles keep every legacy byte', () => {
  for (const {name, env} of cases) {
    const base = outcome(() => runBaseSelector(env));
    const {base: spawned} = resultOf(name);
    assert.deepEqual(base, spawned.status === 0 ? {output: spawned.bytes.toString('utf8')}
      : {error: spawned.error.slice('Error: '.length)}, name);
    for (const value of [undefined, '', 'auto']) {
      const profiled = {...env, BUILD_PROFILE: value};
      if (value === undefined) delete profiled.BUILD_PROFILE;
      assert.deepEqual(outcome(() => selectCloudBuild(profiled)), base, `${name} ${value}`);
    }
  }
});

test('zolnit dispatch only turns on the client product flags', () => {
  const tally = {accepted: 0, android: 0, profile: 0};
  for (const ref of [...PUSH_REFS, NEW_REF, TAG]) {
    const clientRef = ref === ZC || ref === NCS;
    for (const platform of PLATFORMS) {
      for (const iosSource of ['project', 'patched-reference']) {
        for (const androidRelease of [false, true]) {
          const name = `${ref} ${platform} ${iosSource} android=${androidRelease}`;
          const inputs = {platform, ios_source: iosSource, android_release: androidRelease};
          const auto = dispatch(ref, {...inputs, build_profile: 'auto'});
          const base = outcome(() => runBaseSelector(auto));
          assert.deepEqual(outcome(() => selectCloudBuild(auto)), base, name);
          const current = outcome(() => selectCloudBuild(dispatch(ref, {...inputs, build_profile: 'zolnit'})));
          if (androidRelease && !(clientRef && ['all', 'android'].includes(platform))) {
            assert.deepEqual(current, {error: ANDROID_ERROR}, name);
            tally.android++;
          } else if (iosSource !== 'project') {
            assert.deepEqual(current, {error: PROFILE_ERROR}, name);
            tally.profile++;
          } else {
            const parsed = parse(Buffer.from(current.output));
            assert.deepEqual(Object.keys(parsed), KEYS, name);
            assert.deepEqual(parsed, {...parse(Buffer.from(base.output)), client_branch: 'true', native_ui: 'true'}, name);
            assert.equal(parsed.official, 'false', name);
            assert.equal(parsed.android_release, String(androidRelease), name);
            assert.equal(JSON.parse(parsed.matrix).include.some(t => t.safe_preview),
              clientRef && ['all', 'macos'].includes(platform), name);
            tally.accepted++;
          }
        }
      }
    }
  }
  assert.deepEqual(tally, {accepted: 52, android: 88, profile: 52});
});

test('the CLI writes zolnit candidate outputs and rejects what the profile cannot unlock', () => {
  const zolnit = (ref, platform, iosSource = 'project', androidRelease = false) => execute([MODULE], undefined,
    dispatch(ref, {platform, ios_source: iosSource, android_release: androidRelease, build_profile: 'zolnit'}));
  const bytes = (platform, androidRelease, matrix) => `platform=${platform}\nios_source=project\n` +
    `android_release=${androidRelease}\nofficial=false\nclient_branch=true\nnative_ui=true\n` +
    `matrix=${JSON.stringify({include: matrix})}\nenabled=${matrix.length > 0}\n`;
  for (const [run, expected] of [
    [zolnit(NEW_REF, 'all'), bytes('all', false, ALL)],
    [zolnit(NEW_REF, 'macos'), bytes('macos', false, [MAC_ARM, MAC_X64])],
    [zolnit(NEW_REF, 'android'), bytes('android', false, [ANDROID])],
    [zolnit(NEW_REF, 'ios'), bytes('ios', false, [])],
    [zolnit('refs/heads/main', 'windows'), bytes('windows', false, [WINDOWS])],
    [zolnit(ZC, 'macos'), bytes('macos', false, [MAC_ARM, MAC_X64, MAC_PREVIEW])],
    [zolnit(ZC, 'android', 'project', true), bytes('android', true, [ANDROID])],
  ]) {
    assert.equal(run.status, 0);
    assert.equal(run.stdout, '');
    assert.equal(run.bytes.toString('utf8'), expected);
  }
  for (const [run, message] of [
    [zolnit(NEW_REF, 'android', 'project', true), ANDROID_ERROR],
    [zolnit(NEW_REF, 'all', 'project', true), ANDROID_ERROR],
    [zolnit(TAG, 'android', 'project', true), ANDROID_ERROR],
    [zolnit(NEW_REF, 'all', 'patched-reference'), PROFILE_ERROR],
    [zolnit(NEW_REF, 'ios', 'patched-reference'), PROFILE_ERROR],
  ]) {
    assert.equal(run.status, 1);
    assert.equal(run.error, `Error: ${message}`);
    assert.equal(run.bytes.length, 0);
  }
});

test('the zolnit profile needs a manual dispatch and no official request', () => {
  const env = dispatch(NEW_REF, {platform: 'all', ios_source: 'project', build_profile: 'zolnit'});
  assert.equal(parse(Buffer.from(selectCloudBuild(env))).client_branch, 'true');
  for (const event of ['push', 'workflow_call', 'pull_request', 'schedule', 'WORKFLOW_DISPATCH', '', undefined]) {
    const moved = {...env, GITHUB_EVENT_NAME: event};
    if (event === undefined) delete moved.GITHUB_EVENT_NAME;
    assert.throws(() => selectCloudBuild(moved), {message: PROFILE_ERROR}, String(event));
  }
  for (const ref of [...PUSH_REFS, NEW_REF]) {
    assert.throws(() => selectCloudBuild({...githubEnv({event: 'push', ref}), BUILD_PROFILE: 'zolnit'}),
      {message: PROFILE_ERROR}, ref);
  }
  assert.throws(() => selectCloudBuild({...release(), BUILD_PROFILE: 'zolnit'}), {message: PROFILE_ERROR});
  assert.throws(() => selectCloudBuild({...release(), BUILD_PROFILE: 'zolnit', GITHUB_EVENT_NAME: 'workflow_dispatch'}),
    {message: PROFILE_ERROR});
  assert.throws(() => selectCloudBuild({...release({event: 'workflow_dispatch'}), BUILD_PROFILE: 'zolnit'}),
    {message: OFFICIAL_ERROR});
  const called = githubEnv({event: 'workflow_dispatch', ref: NEW_REF, inputs: {official_release: false}});
  assert.equal(called.BUILD_PROFILE, '');
  assert.equal(parse(Buffer.from(selectCloudBuild(called))).client_branch, 'false');
});

test('unknown profiles are rejected before anything is written', () => {
  const env = dispatch(NEW_REF, {platform: 'all', ios_source: 'project'});
  for (const value of ['ZOLNIT', 'Zolnit', ' zolnit', 'zolnit ', 'Auto', 'official', 'release', 'true', 'null']) {
    const run = execute([MODULE], undefined, {...env, BUILD_PROFILE: value});
    assert.equal(run.status, 1, value);
    assert.equal(run.error, `Error: Unknown build profile ${JSON.stringify(value)}; expected auto or zolnit`, value);
    assert.equal(run.bytes.length, 0, value);
  }
});

test('only the select job reads the profile and trust and signing gates ignore it', () => {
  const workflow = readFileSync(WORKFLOW, 'utf8');
  assert.deepEqual(workflow.split('\n').filter(line => /build_profile/i.test(line)),
    ['      build_profile:', '      BUILD_PROFILE: ${{ inputs.build_profile }}']);
  const dispatchInputs = workflow.slice(workflow.indexOf('\n  workflow_dispatch:\n'), workflow.indexOf('\n  workflow_call:\n'));
  assert.match(dispatchInputs, /\n {6}build_profile:\n {8}description: [^\n]+\n {8}type: choice\n {8}required: false\n {8}default: auto\n {8}options: \[auto, zolnit\]$/);
  const select = workflow.slice(workflow.indexOf('\n  select:\n'), workflow.indexOf('\n  project:\n'));
  const gates = select.split('\n')
    .filter(line => /^ {6}(PLATFORM|IOS_SOURCE|CLIENT_BRANCH|NATIVE_BRANCH|ANDROID_RELEASE(_REQUESTED)?|OFFICIAL_(REQUESTED|TRUSTED)):/.test(line));
  assert.equal(gates.length, 8);
  for (const line of gates) assert.doesNotMatch(line, /profile/i);
  const secretSteps = workflow.slice(workflow.indexOf('\njobs:\n')).split('\n      - ').filter(step => step.includes('secrets.'));
  assert.deepEqual(secretSteps.map(step => step.split('\n').slice(0, 2).join('\n')), [
    "name: Provision Android release signing\n        if: matrix.platform == 'android' && env.ANDROID_RELEASE == 'true'",
    "name: Compile Android release\n        if: matrix.platform == 'android' && env.ANDROID_RELEASE == 'true'",
  ]);
  assert.match(workflow, /\n {6}ANDROID_RELEASE: \$\{\{ needs\.select\.outputs\.android_release \}\}\n/);
  const lines = readFileSync(MODULE, 'utf8').split('\n');
  const legacyGates = [
    "  const official = env.OFFICIAL_REQUESTED === 'true';",
    "  if (official && (env.OFFICIAL_TRUSTED !== 'true' || env.PLATFORM !== 'all' || env.IOS_SOURCE !== 'project')) {",
    "  if (env.ANDROID_RELEASE_REQUESTED === 'true' &&",
    "      (env.CLIENT_BRANCH !== 'true' || !['all', 'android'].includes(env.PLATFORM))) {",
    "  if (env.CLIENT_BRANCH === 'true' && ['all', 'macos'].includes(env.PLATFORM)) {",
    "  const androidRelease = env.ANDROID_RELEASE === 'true' || official;",
  ];
  for (const line of legacyGates) assert.equal(lines.filter(l => l === line).length, 1, line);
  assert.deepEqual(lines.filter(l => /OFFICIAL_|ANDROID_RELEASE|safe_preview: true/.test(l)), [...legacyGates.slice(0, 3),
    "    targets.push({platform: 'macos', os: 'xcode-27', arch: 'arm64', safe_preview: true});", legacyGates[5]]);
});
