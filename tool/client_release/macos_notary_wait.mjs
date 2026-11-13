import { createHash, createPrivateKey, sign } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { readFile, lstat, readdir } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
export const MAX_WAIT_MS = 5 * 60 * 60 * 1000;
const requireValue = (condition, message) => { if (!condition) throw new Error(message); };

export async function submissionFromCheckpoint(directory, stage, team) {
  requireValue(['app', 'dmg'].includes(stage) && /^[A-Z0-9]{10}$/.test(team), 'Invalid wait configuration');
  const receiptPath = join(directory, 'pending-receipt.json');
  const receiptStat = await lstat(receiptPath);
  requireValue(receiptStat.isFile() && !receiptStat.isSymbolicLink(), 'Invalid checkpoint receipt');
  const receipt = JSON.parse(await readFile(receiptPath, 'utf8'));
  requireValue(receipt.schema_version === 1 && receipt.binding?.team_id === team &&
    receipt.binding.source_repository === 'Zolmid/FlClash' && ['app', 'dmg'].includes(receipt.stage), 'Checkpoint binding mismatch');
  requireValue(stage !== 'dmg' || receipt.stage === 'dmg', 'DMG checkpoint missing');
  const expected = receipt.stage === 'app' ? ['notary-app.zip'] : ['notary-app.zip', 'notary-dmg.dmg'];
  const names = await readdir(directory);
  requireValue(names.length === expected.length + 1 && expected.every(name => names.includes(name)) &&
    Object.keys(receipt.payloads).sort().join() === expected.sort().join(), 'Unexpected checkpoint files');
  for (const name of expected) {
    const path = join(directory, name), stat = await lstat(path), item = receipt.payloads[name];
    requireValue(stat.isFile() && !stat.isSymbolicLink() && stat.size === item.size && stat.size > 0, 'Checkpoint payload mismatch');
    const hash = createHash('sha256');
    for await (const chunk of createReadStream(path)) hash.update(chunk);
    requireValue(hash.digest('hex') === item.sha256, 'Checkpoint payload mismatch');
  }
  const id = stage === 'app' && receipt.stage === 'dmg' ? receipt.app_notary_id : receipt.submission_id;
  requireValue(typeof id === 'string' && uuid.test(id), 'Submission ID missing; reconcile with Apple');
  return id;
}

export function token(env, now = Date.now()) {
  requireValue(/^[A-Z0-9]{10,}$/.test(env.APPLE_ASC_API_KEY_ID || '') && uuid.test(env.APPLE_ASC_ISSUER_ID || ''), 'Invalid API configuration');
  const key = createPrivateKey(Buffer.from(env.APPLE_ASC_P8_BASE64 || '', 'base64'));
  requireValue(key.asymmetricKeyType === 'ec' && key.asymmetricKeyDetails.namedCurve === 'prime256v1', 'Unsupported API key');
  const enc = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const iat = Math.floor(now / 1000);
  const message = `${enc({alg: 'ES256', kid: env.APPLE_ASC_API_KEY_ID, typ: 'JWT'})}.${enc({iss: env.APPLE_ASC_ISSUER_ID, iat, exp: iat + 1200, aud: 'appstoreconnect-v1'})}`;
  return `${message}.${sign('sha256', Buffer.from(message), {key, dsaEncoding: 'ieee-p1363'}).toString('base64url')}`;
}

export async function waitForAcceptance(id, env, {
  fetcher = fetch, now = Date.now, sleep = ms => new Promise(r => setTimeout(r, ms)),
  authorize = token, report = status => process.stdout.write(`notary status: ${status}\n`),
  budget = MAX_WAIT_MS,
} = {}) {
  requireValue(uuid.test(id) && budget > 0 && budget <= MAX_WAIT_MS, 'Invalid wait request');
  const deadline = now() + budget;
  while (now() < deadline) {
    const authorization = `Bearer ${authorize(env, now())}`;
    let response;
    try {
      response = await fetcher(`https://appstoreconnect.apple.com/notary/v2/submissions/${id}`, {
        method: 'GET', redirect: 'error', signal: AbortSignal.timeout(30000),
        headers: {Authorization: authorization, Accept: 'application/json'},
      });
    } catch {
      report('unavailable');
      await sleep(Math.min(60000, Math.max(0, deadline - now())));
      continue;
    }
    if (response.status === 429 || response.status >= 500) {
      report('unavailable');
    } else {
      requireValue(response.ok, 'Notary status request rejected');
      const body = await response.json();
      requireValue(body.data?.id?.toLowerCase() === id.toLowerCase(), 'Notary response ID mismatch');
      const status = body.data?.attributes?.status;
      requireValue(['Accepted', 'Invalid', 'Rejected', 'In Progress', 'InProgress'].includes(status), 'Unknown notary status');
      report(status === 'InProgress' ? 'In Progress' : status);
      requireValue(!['Invalid', 'Rejected'].includes(status), 'Notarization rejected');
      if (status === 'Accepted') return;
    }
    await sleep(Math.min(60000, Math.max(0, deadline - now())));
  }
  throw new Error('Notarization remains pending; resume the saved checkpoint');
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [, , directory, stage] = process.argv;
    const id = await submissionFromCheckpoint(directory, stage, process.env.MACOS_TEAM_ID || '');
    await waitForAcceptance(id, process.env);
  } catch {
    process.stderr.write('::error::Notary wait did not establish acceptance; checkpoint retained\n');
    process.exitCode = 1;
  }
}
