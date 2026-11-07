import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, mkdir, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, test } from 'node:test';
import { MAX_PART_BYTES, MIN_NONFINAL_PART_BYTES } from '../contracts.mjs';
import { EDGE, PendingError, ReleaseError, publish } from '../publish_release.mjs';

const TAG = 'v1.2.3', SHA = 'c'.repeat(40), RUN = 4242, OIDC = 'https://oidc.example/token?api-version=2.0';
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const ENV = { GITHUB_REF_NAME: TAG, GITHUB_REF_TYPE: 'tag', GITHUB_REF: `refs/tags/${TAG}`, GITHUB_EVENT_NAME: 'push',
  GITHUB_REPOSITORY: 'Zolmid/FlClash', GITHUB_REPOSITORY_ID: '1420254999', GITHUB_SHA: SHA, GITHUB_RUN_ID: String(RUN),
  GITHUB_WORKFLOW_REF: `Zolmid/FlClash/.github/workflows/client-release.yml@refs/tags/${TAG}`,
  ACTIONS_ID_TOKEN_REQUEST_URL: OIDC, ACTIONS_ID_TOKEN_REQUEST_TOKEN: 'request-token' };

let root, files;
beforeEach(async () => {
  root = await mkdtemp(join(tmpdir(), 'zolnit-publish-test-'));
  await mkdir(join(root, TAG));
  files = {
    'ZolNit-1.2.3-linux-x64.deb': Buffer.alloc(MAX_PART_BYTES + 12345, 7),
    'ZolNit-1.2.3-macos-arm64.dmg': Buffer.from('small dmg'),
  };
  for (const [name, data] of Object.entries(files)) await writeFile(join(root, TAG, name), data);
});
afterEach(() => rm(root, { recursive: true, force: true }));

function release(notes = 'notes') {
  const assets = Object.entries(files).map(([name, data]) => ({ name, url: `https://link.zolmid.com/client/downloads/${TAG}/${name}`,
    size: data.length, sha256: sha(data) }));
  const manifest = { schema_version: 1, app_id: 'com.zolmid.zolnit', updates_enabled: true, releases: [{ tag: TAG, notes, assets }] };
  const receipt = { schema_version: 1, repository_id: '1420254999', source_sha: SHA, tag: TAG, build: 5,
    core_sha: '8380d0e7462f061a964323e9bf3129a236fcc5d5', ci_run_id: RUN,
    assets: assets.map((asset, index) => ({ name: asset.name, size: asset.size, sha256: asset.sha256, platform: 'linux', arch: 'x64',
      ci_run_id: RUN, artifact_id: 100 + index })),
    checks: { all_platform_builds: true, standard_ci: true, package_hashes: true } };
  return { manifest, receipt };
}

function edge({ enabled = true, notice = 'notified', faults = [], sessionState, staleNotice = false } = {}) {
  const state = { tokens: [], requests: [], sessions: new Map(), parts: new Map(), counter: 0 };
  const fail = (status, error) => Response.json({ error }, { status });
  state.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    if (url.origin + url.pathname === 'https://oidc.example/token') {
      assert.equal(url.searchParams.get('audience'), 'zolnit-client-release-edge');
      assert.equal(init.headers.authorization, 'Bearer request-token');
      const value = `jwt-${++state.counter}`;
      state.tokens.push(value);
      return Response.json({ value });
    }
    assert.equal(url.origin, EDGE, `unexpected outbound request ${url}`);
    assert.ok(url.pathname.startsWith('/__release/v1/'), 'the publisher never calls the origin hook');
    const bearer = init.headers.authorization.slice(7);
    assert.equal(bearer, state.tokens.at(-1), 'every request carries a freshly minted token');
    assert.ok(!state.requests.some(item => item.bearer === bearer), 'tokens are not reused');
    const route = url.pathname.slice('/__release/v1'.length);
    state.requests.push({ method: init.method, route, bearer });
    const fault = faults.find(item => item.match(init.method, route) && item.times > 0);
    if (fault) {
      fault.times--;
      if (fault.error) throw fault.error;
      return fail(fault.status, fault.code);
    }
    if (init.method === 'POST' && route === '/sessions') {
      const body = JSON.parse(init.body);
      assert.equal(body.notes, body.manifest.releases[0].notes);
      const digest = sha(JSON.stringify({ receipt: body.receipt, manifest: body.manifest }));
      const prior = state.sessions.get(TAG);
      if (prior) return prior.digest === digest ? Response.json({ id: prior.id, state: prior.state, idempotent: true }) : fail(409, 'tag_digest_conflict');
      const session = { id: 'session-1', digest, state: sessionState ?? 'uploading', manifest: body.manifest };
      state.sessions.set(TAG, session);
      return Response.json({ id: session.id, state: session.state });
    }
    const part = /^\/sessions\/([^/]+)\/assets\/([^/]+)\/parts\/(\d+)$/.exec(route);
    if (init.method === 'PUT' && part) {
      const session = state.sessions.get(TAG), name = decodeURIComponent(part[2]), n = Number(part[3]);
      const asset = session.manifest.releases[0].assets.find(item => item.name === name);
      const data = Buffer.from(init.body), final = init.headers['x-final-part'] === 'true', offset = (n - 1) * MAX_PART_BYTES;
      if (init.headers['x-content-sha256'] !== sha(data)) return fail(422, 'part_digest');
      if (data.length > MAX_PART_BYTES || (!final && data.length < MIN_NONFINAL_PART_BYTES) ||
          data.length !== Math.min(MAX_PART_BYTES, asset.size - offset) || final !== (offset + data.length === asset.size)) return fail(422, 'part_boundary');
      const key = `${name}/${n}`, prior = state.parts.get(key);
      if (prior && prior !== sha(data)) return fail(409, 'part_conflict');
      state.parts.set(key, sha(data));
      return new Response(null, { status: 204 });
    }
    if (init.method === 'POST' && route === '/sessions/session-1/complete') {
      const session = state.sessions.get(TAG);
      if (session.state === 'uploading') {
        for (const asset of session.manifest.releases[0].assets) {
          const count = Math.max(1, Math.ceil(asset.size / MAX_PART_BYTES));
          for (let n = 1; n <= count; n++) if (!state.parts.has(`${asset.name}/${n}`)) return fail(422, 'incomplete_asset');
        }
        session.state = 'published';
      }
      return Response.json({ state: enabled ? session.state : 'staged', tag: TAG });
    }
    if (init.method === 'POST' && route === '/sessions/session-1/origin-notified') {
      if (!enabled) return fail(409, 'downloads_disabled');
      if (staleNotice) return fail(409, 'stale_version');
      if (notice === 'pending') return Response.json({ state: 'published', notice_pending: true }, { status: 202 });
      state.sessions.get(TAG).state = 'notified';
      return Response.json({ state: 'notified' });
    }
    return fail(404, 'not_found');
  };
  return state;
}

const run = (server, overrides = {}) => {
  const { manifest, receipt } = release();
  return publish({ receipt, manifest, root, env: ENV, fetch: server.fetch, sleep: async () => {}, attempts: 3, ...overrides });
};
const routes = server => server.requests.map(item => `${item.method} ${item.route}`);

test('enabled edge uploads 8 MiB parts, publishes and reports notified', async () => {
  const server = edge();
  assert.deepEqual(await run(server), { tag: TAG, source_sha: SHA, session_id: 'session-1', state: 'notified', downloads_enabled: true, notice_pending: false });
  assert.deepEqual(routes(server), ['POST /sessions', 'PUT /sessions/session-1/assets/ZolNit-1.2.3-linux-x64.deb/parts/1',
    'PUT /sessions/session-1/assets/ZolNit-1.2.3-linux-x64.deb/parts/2', 'PUT /sessions/session-1/assets/ZolNit-1.2.3-macos-arm64.dmg/parts/1',
    'POST /sessions/session-1/complete', 'POST /sessions/session-1/origin-notified']);
  assert.equal(server.tokens.length, server.requests.length);
});

test('disabled downloads stay staged and never request a notification', async () => {
  const server = edge({ enabled: false });
  const result = await run(server);
  assert.equal(result.state, 'staged');
  assert.equal(result.downloads_enabled, false);
  assert.ok(!routes(server).some(route => route.endsWith('origin-notified')));
});

test('a durable pending notice is a successful publication', async () => {
  const result = await run(edge({ notice: 'pending' }));
  assert.deepEqual([result.state, result.downloads_enabled, result.notice_pending], ['published', true, true]);
});

test('transient failures retry the same request with a new token', async () => {
  const server = edge({ faults: [
    { match: (method, route) => method === 'PUT' && route.endsWith('/parts/2'), times: 1, status: 503, code: 'busy' },
    { match: (method, route) => route.endsWith('/complete'), times: 1, error: new TypeError('fetch failed') },
    { match: (method, route) => route === '/sessions', times: 1, status: 429, code: 'slow_down' }] });
  assert.equal((await run(server)).state, 'notified');
  assert.equal(routes(server).filter(route => route.endsWith('/parts/2')).length, 2);
  assert.equal(new Set(server.requests.map(item => item.bearer)).size, server.requests.length);
});

test('a rerun resumes the same session and identical parts are accepted', async () => {
  const server = edge({ faults: [{ match: (method, route) => route.endsWith('/complete'), times: 3, status: 503, code: 'busy' }] });
  await assert.rejects(run(server), PendingError);
  const result = await run(server);
  assert.equal(result.state, 'notified');
  assert.equal(server.sessions.size, 1);
});

test('an already published session skips uploads', async () => {
  const server = edge({ sessionState: 'published' });
  assert.equal((await run(server)).state, 'notified');
  assert.ok(!routes(server).some(route => route.startsWith('PUT')));
});

test('conflicts and stale versions fail immediately without retry', async () => {
  const stale = edge({ staleNotice: true });
  await assert.rejects(run(stale), error => error instanceof ReleaseError && !(error instanceof PendingError) && /409 stale_version/.test(error.message));
  assert.equal(routes(stale).filter(route => route.endsWith('origin-notified')).length, 1);

  const conflict = edge();
  await run(conflict);
  const { manifest, receipt } = release('different notes');
  await assert.rejects(publish({ receipt, manifest, root, env: ENV, fetch: conflict.fetch, sleep: async () => {} }), /409 tag_digest_conflict/);

  const owner = edge({ faults: [{ match: method => method === 'PUT', times: 1, status: 403, code: 'session_owner_mismatch' }] });
  await assert.rejects(run(owner), /403 session_owner_mismatch/);
});

test('a persistent outage ends as pending after the bounded attempts', async () => {
  const server = edge({ faults: [{ match: () => true, times: 99, status: 503, code: 'origin_notification_pending' }] });
  await assert.rejects(run(server), error => error instanceof PendingError && /after 3 attempts/.test(error.message));
  assert.equal(server.requests.length, 3);
});

test('unknown edge states are not treated as success', async () => {
  const server = edge();
  const fetch = async (input, init) => {
    const response = await server.fetch(input, init);
    return String(input).endsWith('/origin-notified') ? Response.json({ state: 'published' }) : response;
  };
  await assert.rejects(run(server, { fetch }), /unknown notification state/);
});

test('evidence and package mismatches stop before any network request', async () => {
  const cases = [
    [{ env: { ...ENV, GITHUB_REF_TYPE: 'branch' } }, /formal tag push/],
    [{ env: { ...ENV, GITHUB_WORKFLOW_REF: `Zolmid/FlClash/.github/workflows/build.yaml@refs/tags/${TAG}` } }, /formal tag push/],
    [{ env: { ...ENV, GITHUB_SHA: 'd'.repeat(40) } }, /receipt does not match/],
    [{ env: { ...ENV, GITHUB_RUN_ID: '1' } }, /does not match the manifest/],
    [{ env: { ...ENV, ACTIONS_ID_TOKEN_REQUEST_URL: '' } }, /OIDC/],
  ];
  for (const [overrides, pattern] of cases) {
    const server = edge();
    await assert.rejects(run(server, overrides), pattern);
    assert.equal(server.requests.length + server.tokens.length, 0);
  }
  const server = edge();
  await writeFile(join(root, TAG, 'ZolNit-1.2.3-macos-arm64.dmg'), 'tampered');
  await assert.rejects(run(server), /wrong size|digest/);
  await rm(join(root, TAG, 'ZolNit-1.2.3-macos-arm64.dmg'));
  await writeFile(join(root, 'elsewhere'), files['ZolNit-1.2.3-macos-arm64.dmg']);
  await symlink(join(root, 'elsewhere'), join(root, TAG, 'ZolNit-1.2.3-macos-arm64.dmg'));
  await assert.rejects(run(server), /missing or has the wrong size/);
  assert.equal(server.requests.length, 0);
});

test('receipts must list exactly the manifest assets', async () => {
  const { manifest, receipt } = release();
  receipt.assets[1] = { ...receipt.assets[0] };
  await assert.rejects(publish({ receipt, manifest, root, env: ENV, fetch: edge().fetch, sleep: async () => {} }), /does not match the manifest/);
  const other = release();
  other.receipt.core_sha = '0'.repeat(40);
  await assert.rejects(publish({ ...other, root, env: ENV, fetch: edge().fetch, sleep: async () => {} }), /receipt does not match/);
});
