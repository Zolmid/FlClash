import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { waitForAcceptance, token, submissionFromCheckpoint } from '../macos_notary_wait.mjs';

const id = '11111111-1111-1111-1111-111111111111';
const response = (status, returnedId = id) => ({ok: true, status: 200, json: async () => ({data: {id: returnedId, attributes: {status}}})});
function options(responses) {
  let clock = 0;
  const calls = [], reports = [];
  return {calls, reports, now: () => clock, sleep: async ms => { clock += ms; }, budget: 180000,
    authorize: () => 'synthetic-authorization', report: value => reports.push(value),
    fetcher: async (url, args) => { calls.push([url, args]); return responses.shift(); }};
}

test('Linux waits for late acceptance with GET only', async () => {
  const config = options([response('In Progress'), response('InProgress'), response('Accepted')]);
  await waitForAcceptance(id, {}, config);
  assert.equal(config.calls.length, 3);
  assert.deepEqual(config.reports, ['In Progress', 'In Progress', 'Accepted']);
  assert.ok(config.calls.every(([url, args]) => url === `https://appstoreconnect.apple.com/notary/v2/submissions/${id}` && args.method === 'GET' && args.redirect === 'error'));
});

test('pending never becomes successful at the wait limit', async () => {
  const config = options(Array.from({length: 3}, () => response('In Progress')));
  await assert.rejects(waitForAcceptance(id, {}, config), /remains pending/);
});

test('invalid, unauthorized and mismatched responses fail closed', async () => {
  for (const result of [response('Invalid'), response('Accepted', 'foreign'), {ok: false, status: 403}]) {
    const config = options([result]);
    await assert.rejects(waitForAcceptance(id, {}, config));
    assert.equal(config.calls.length, 1);
  }
});

test('credentials are validated before polling and errors do not enter reports', async () => {
  assert.throws(() => token({APPLE_ASC_API_KEY_ID: 'bad'}), /Invalid API configuration/);
  const config = options([]);
  config.authorize = () => { throw new Error('synthetic-private-value'); };
  await assert.rejects(waitForAcceptance(id, {}, config));
  assert.deepEqual(config.reports, []);
  assert.deepEqual(config.calls, []);
});


test('waiter reads only digest-bound checkpoint IDs and rejects changed bytes', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'zolnit-wait-test-'));
  try {
    const bytes = Buffer.from('signed app');
    const receipt = {schema_version: 1, binding: {team_id: 'ABCDE12345', source_repository: 'Zolmid/FlClash'},
      stage: 'app', submission_id: id, payloads: {'notary-app.zip': {size: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex')}}};
    await writeFile(join(directory, 'pending-receipt.json'), JSON.stringify(receipt));
    await writeFile(join(directory, 'notary-app.zip'), bytes);
    assert.equal(await submissionFromCheckpoint(directory, 'app', 'ABCDE12345'), id);
    await assert.rejects(submissionFromCheckpoint(directory, 'dmg', 'ABCDE12345'));
    await assert.rejects(submissionFromCheckpoint(directory, 'app', 'WRONG12345'));
    await writeFile(join(directory, 'notary-app.zip'), 'changed');
    await assert.rejects(submissionFromCheckpoint(directory, 'app', 'ABCDE12345'));
  } finally { await rm(directory, {recursive: true, force: true}); }
});
