#!/usr/bin/env node
// Uploads one verified formal release to the ZolNit release edge with a fresh
// GitHub OIDC token per request. The edge decides whether downloads go live;
// the origin notification is its job and is never called from here.
import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { lstat, open, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { MAX_PART_BYTES, TAG, validateManifest } from './contracts.mjs';

export const EDGE = 'https://link.zolmid.com';
export const AUDIENCE = 'zolnit-client-release-edge';
const REPOSITORY = 'Zolmid/FlClash', REPOSITORY_ID = '1420254999';
const CORE = '8380d0e7462f061a964323e9bf3129a236fcc5d5';
const SESSION_ID = /^[A-Za-z0-9-]{1,128}$/;

export class ReleaseError extends Error {}
export class PendingError extends ReleaseError {}

export function checkEvidence(receipt, manifest, env) {
  const release = validateManifest(manifest), tag = env.GITHUB_REF_NAME ?? '';
  if (!TAG.test(tag) || env.GITHUB_REF_TYPE !== 'tag' || env.GITHUB_REF !== `refs/tags/${tag}` ||
      env.GITHUB_EVENT_NAME !== 'push' || env.GITHUB_REPOSITORY !== REPOSITORY || env.GITHUB_REPOSITORY_ID !== REPOSITORY_ID ||
      env.GITHUB_WORKFLOW_REF !== `${REPOSITORY}/.github/workflows/client-release.yml@refs/tags/${tag}`) {
    throw new ReleaseError('not running from client-release.yml on a formal tag push of Zolmid/FlClash');
  }
  const checks = receipt?.checks ?? {};
  if (receipt?.schema_version !== 1 || receipt.repository_id !== REPOSITORY_ID || receipt.tag !== tag || release.tag !== tag ||
      receipt.source_sha !== env.GITHUB_SHA || receipt.core_sha !== CORE || !Number.isInteger(receipt.build) || receipt.build < 1 ||
      checks.all_platform_builds !== true || checks.standard_ci !== true || checks.package_hashes !== true ||
      !Array.isArray(receipt.assets) || receipt.assets.length !== release.assets.length) {
    throw new ReleaseError('formal release receipt does not match this run');
  }
  const listed = new Map(release.assets.map(asset => [asset.name, asset]));
  for (const item of receipt.assets) {
    const asset = listed.get(item?.name);
    if (!asset || item.size !== asset.size || item.sha256 !== asset.sha256 || item.ci_run_id !== Number(env.GITHUB_RUN_ID) ||
        !Number.isInteger(item.artifact_id)) throw new ReleaseError(`receipt asset ${item?.name} does not match the manifest`);
    listed.delete(item.name);
  }
  return release;
}

export async function verifyPackages(root, release) {
  for (const asset of release.assets) {
    const path = join(root, release.tag, asset.name), info = await lstat(path);
    if (!info.isFile() || info.size !== asset.size) throw new ReleaseError(`${asset.name} is missing or has the wrong size`);
    const hash = createHash('sha256');
    for await (const bytes of createReadStream(path)) hash.update(bytes);
    if (hash.digest('hex') !== asset.sha256) throw new ReleaseError(`${asset.name} does not match the manifest digest`);
  }
}

async function errorCode(response) {
  try {
    const body = await response.json();
    return typeof body?.error === 'string' ? ` ${body.error}` : '';
  } catch {
    return '';
  }
}

export function edgeClient({ fetch, oidcUrl, oidcToken, attempts = 5, timeoutMs = 300000, sleep, log = () => {} }) {
  if (!oidcUrl || !oidcToken) throw new ReleaseError('GitHub OIDC (id-token: write) is required');
  async function token() {
    const url = new URL(oidcUrl);
    url.searchParams.set('audience', AUDIENCE);
    const response = await fetch(url, { headers: { authorization: `Bearer ${oidcToken}`, accept: 'application/json' },
      signal: AbortSignal.timeout(30000) });
    if (!response.ok) throw Error(`OIDC token request returned ${response.status}`);
    const value = (await response.json())?.value;
    if (typeof value !== 'string' || !value) throw new ReleaseError('OIDC token response has no token');
    return value;
  }
  return async function call(label, path, init, accepted) {
    let last = '';
    for (let attempt = 1; attempt <= attempts; attempt++) {
      let response;
      try {
        const bearer = await token();
        response = await fetch(EDGE + path, { ...init, headers: { ...init.headers, authorization: `Bearer ${bearer}` },
          signal: AbortSignal.timeout(timeoutMs) });
      } catch (error) {
        if (error instanceof ReleaseError) throw error;
        last = error?.message || String(error);
      }
      if (response) {
        if (accepted.includes(response.status)) return response;
        const code = await errorCode(response);
        if (response.status !== 429 && response.status < 500) {
          throw new ReleaseError(`${label} rejected with ${response.status}${code}`);
        }
        last = `${response.status}${code}`;
      }
      if (attempt < attempts) {
        log(`${label}: attempt ${attempt} failed (${last}); retrying`);
        await sleep(Math.min(30000, 1000 * 2 ** (attempt - 1)));
      }
    }
    throw new PendingError(`${label} still unavailable after ${attempts} attempts (${last}); rerunning resumes the same session`);
  };
}

async function json(response, label) {
  try {
    return await response.json();
  } catch {
    throw new ReleaseError(`${label} returned malformed JSON`);
  }
}

async function uploadAsset(call, root, release, session, asset) {
  const file = await open(join(root, release.tag, asset.name), 'r');
  try {
    for (let offset = 0, part = 1; offset < asset.size; part++) {
      const chunk = Buffer.alloc(Math.min(MAX_PART_BYTES, asset.size - offset));
      for (let used = 0; used < chunk.length;) {
        const { bytesRead } = await file.read(chunk, used, chunk.length - used, offset + used);
        if (!bytesRead) throw new ReleaseError(`${asset.name} shrank during upload`);
        used += bytesRead;
      }
      const final = offset + chunk.length === asset.size;
      const path = `/__release/v1/sessions/${encodeURIComponent(session)}/assets/${encodeURIComponent(asset.name)}/parts/${part}`;
      await call(`upload ${asset.name} part ${part}`, path, { method: 'PUT', body: chunk, headers: {
        'content-type': 'application/octet-stream', 'x-content-sha256': createHash('sha256').update(chunk).digest('hex'),
        'x-final-part': String(final) } }, [200, 204]);
      offset += chunk.length;
    }
  } finally {
    await file.close();
  }
}

export async function publish({ receipt, manifest, root, env, fetch, sleep = ms => new Promise(done => setTimeout(done, ms)),
  log = () => {}, attempts, timeoutMs }) {
  const release = checkEvidence(receipt, manifest, env);
  await verifyPackages(root, release);
  const call = edgeClient({ fetch, oidcUrl: env.ACTIONS_ID_TOKEN_REQUEST_URL, oidcToken: env.ACTIONS_ID_TOKEN_REQUEST_TOKEN,
    attempts, timeoutMs, sleep, log });
  const result = { tag: release.tag, source_sha: receipt.source_sha };

  const opened = await json(await call('open session', '/__release/v1/sessions', { method: 'POST',
    headers: { 'content-type': 'application/json' }, body: JSON.stringify({ receipt, manifest, notes: release.notes }) }, [200]),
  'open session');
  if (!SESSION_ID.test(opened?.id ?? '') || !['uploading', 'published', 'notified'].includes(opened.state)) {
    throw new ReleaseError('release edge returned an unknown session state');
  }
  result.session_id = opened.id;
  if (opened.state === 'uploading') {
    for (const asset of release.assets) await uploadAsset(call, root, release, opened.id, asset);
  }

  const session = `/__release/v1/sessions/${encodeURIComponent(opened.id)}`;
  const completed = await json(await call('complete', `${session}/complete`, { method: 'POST' }, [200]), 'complete');
  if (completed?.tag !== undefined && completed.tag !== release.tag) throw new ReleaseError('release edge completed another tag');
  if (completed?.state === 'staged') return { ...result, state: 'staged', downloads_enabled: false, notice_pending: false };
  if (!['published', 'notified'].includes(completed?.state)) throw new ReleaseError('release edge did not publish the manifest');

  const notified = await call('origin notification', `${session}/origin-notified`, { method: 'POST' }, [200, 202]);
  const notice = await json(notified, 'origin notification');
  if (notified.status === 200 && notice?.state === 'notified') {
    return { ...result, state: 'notified', downloads_enabled: true, notice_pending: false };
  }
  if (notified.status === 202 && notice?.state === 'published' && notice.notice_pending === true) {
    return { ...result, state: 'published', downloads_enabled: true, notice_pending: true };
  }
  throw new ReleaseError('release edge returned an unknown notification state');
}

async function main() {
  const [receiptPath, manifestPath, root] = process.argv.slice(2);
  if (!receiptPath || !manifestPath || !root) throw new ReleaseError('usage: publish_release.mjs RECEIPT MANIFEST PACKAGE_ROOT');
  const result = await publish({ receipt: JSON.parse(await readFile(receiptPath, 'utf8')),
    manifest: JSON.parse(await readFile(manifestPath, 'utf8')), root, env: process.env, fetch: globalThis.fetch,
    log: message => console.error(message) });
  console.log(JSON.stringify(result));
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main().catch(error => {
    const message = error instanceof ReleaseError ? error.message : `release publisher failed: ${error?.message ?? error}`;
    console.error(`::error::${message}`);
    process.exit(1);
  });
}
