import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
import { stripTypeScriptTypes } from 'node:module';

const edge = fs.readFileSync('supabase/functions/sheet-row-ack/index.ts', 'utf8');
const migration = fs.readFileSync('supabase/migrations/20261014034000_sheet_delivery_ack_v1.sql', 'utf8');
const denyMigration = fs.readFileSync('supabase/migrations/20261014034200_sheet_delivery_ack_explicit_deny.sql', 'utf8');

const A = Object.freeze({
  user: 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',
  space: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  event: 'aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa',
  integration: 'aaaaaaaa-3333-4333-8333-aaaaaaaaaaaa',
  sheet: 'synthetic-spreadsheet-a',
  token: 'only-for-isolated-test-a',
});
const B = Object.freeze({
  user: 'bbbbbbbb-1111-4111-8111-bbbbbbbbbbbb',
  space: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  event: 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb',
  integration: 'bbbbbbbb-3333-4333-8333-bbbbbbbbbbbb',
  sheet: 'synthetic-spreadsheet-b',
  token: 'only-for-isolated-test-b',
});
const version = '2026-10-14T12:00:00.000Z';
const hash = 'a'.repeat(64);
const ackRow = (user, extra = {}) => ({
  id: 'event:' + user.event, updated_at: version, sha256: hash, ...extra,
});

function makeSandbox() {
  const integrations = [A, B].map(x => ({
    id: x.integration, space_id: x.space, spreadsheet_id: x.sheet,
    enabled: true, token_hash: crypto.createHash('sha256').update(x.token).digest('hex'),
  }));
  const events = [A, B].map(x => ({
    id: x.event, space_id: x.space, external_id: null,
    updated_at: version, status: 'confirmed',
  }));
  const receipts = new Map();
  const mutations = [];
  const queries = [];

  // In-memory dependency double. It DOES NOT claim to execute PostgreSQL RLS.
  const createClient = () => ({
    from(table) {
      queries.push(table);
      const filters = [];
      return {
        select() { return this; },
        eq(key, value) { filters.push([key, value]); return this; },
        async maybeSingle() {
          const source = table === 'sheet_sync_integrations' ? integrations :
            table === 'financial_events' ? events : [];
          const matches = source.filter(row => filters.every(([key, value]) => row[key] === value));
          return { data: matches[0] ?? null, error: matches.length > 1 ? { message:'not_unique' } : null };
        },
      };
    },
    async rpc(name, args) {
      assert.equal(name, 'record_folego_sheet_delivery_ack');
      const integration = integrations.find(x => x.id === args.p_integration_id && x.enabled);
      if (!integration) return { data: { status:'integration_disabled' }, error:null };
      const event = events.find(x => x.id === args.p_event_id &&
        x.space_id === integration.space_id && x.status === 'confirmed');
      if (!event) return { data: { status:'event_not_found' }, error:null };
      const expectedId = 'event:' + event.id;
      if (args.p_sheet_row_id !== expectedId &&
          args.p_sheet_row_id !== event.external_id &&
          'sheet:' + args.p_sheet_row_id !== event.external_id) {
        return { data: { status:'row_identity_conflict' }, error:null };
      }
      if (event.updated_at !== args.p_expected_updated_at) {
        return { data: { status:'stale_version' }, error:null };
      }
      const key = [integration.id, event.id, event.updated_at].join(':');
      const existing = receipts.get(key);
      if (existing) return { data: {
        status: existing.rowId === args.p_sheet_row_id &&
          existing.sha === args.p_content_sha256 ? 'already_acknowledged' : 'receipt_conflict',
      },error:null };
      receipts.set(key, {rowId:args.p_sheet_row_id, sha:args.p_content_sha256});
      mutations.push('receipt_only');
      return {data:{status:'applied'},error:null};
    },
  });

  let handler;
  const src = stripTypeScriptTypes(
    edge.replace(/^import \{ createClient \} from "npm:@supabase\/supabase-js@2\.116\.0";/m, ''),
    {mode:'strip'},
  );
  assert.doesNotMatch(src, /npm:@supabase/);
  vm.runInNewContext(src, {
    Deno: {
      env: { get: name => name === 'SUPABASE_URL' ? 'https://isolated.invalid' :
        name === 'SUPABASE_SERVICE_ROLE_KEY' ? 'fake-only' : null },
      serve: fn => { handler = fn; },
    },
    createClient, crypto: crypto.webcrypto, TextEncoder, Response, Request, Uint8Array,
  }, {timeout:1000});
  assert.equal(typeof handler, 'function');

  async function send(user, rows, opts={}) {
    const request = new Request('https://isolated.invalid/functions/v1/sheet-row-ack',{
      method:'POST',
      headers:{
        'content-type':'application/json',
        'x-spreadsheet-id':opts.sheet ?? user.sheet,
        'x-folego-sync-token':opts.token ?? user.token,
      },
      body:JSON.stringify({
        action:opts.action ?? 'pull_ack',
        rows,
        space_id:opts.spoofedSpace, // must be ignored by the actual Edge handler
      }),
    });
    const response = await handler(request);
    return {code:response.status,data:await response.json()};
  }
  return {send,events,receipts,mutations,queries};
}

test('real Edge handler authenticates two independent synthetic sheet tokens', async () => {
  const env = makeSandbox();
  const a = await env.send(A,[ackRow(A)]);
  const b = await env.send(B,[ackRow(B)]);
  assert.equal(a.code,200);assert.equal(b.code,200);
  assert.equal(a.data.results[0].status,'applied');
  assert.equal(b.data.results[0].status,'applied');
  assert.equal(env.receipts.size,2);
  assert.deepEqual(env.mutations,['receipt_only','receipt_only']);
});

test('valid tenant A token cannot acknowledge event belonging to tenant B', async () => {
  const env = makeSandbox();
  const rejected = await env.send(A,[ackRow(B)],{spoofedSpace:B.space});
  assert.equal(rejected.code,200); // batch HTTP 200 is not per-row success
  assert.equal(rejected.data.results[0].status,'event_not_found');
  assert.equal(env.receipts.size,0);
});

test('valid tenant B token cannot acknowledge tenant A event', async () => {
  const env=makeSandbox();
  const rejected=await env.send(B,[ackRow(A)]);
  assert.equal(rejected.data.results[0].status,'event_not_found');
  assert.equal(env.receipts.size,0);
});

test('bad token or fake spreadsheet ID are rejected before any receipt attempt',async()=>{
  const env=makeSandbox();
  const badToken=await env.send(A,[ackRow(A)],{token:'invalid'});
  const badSheet=await env.send(A,[ackRow(A)],{sheet:'foreign-spreadsheet'});
  assert.equal(badToken.code,401); assert.equal(badSheet.code,401);
  assert.equal(env.receipts.size,0);
  assert.equal(env.queries.includes('financial_events'),false);
});

test('idempotent repeat returns already_acknowledged, changed digest conflicts', async()=>{
  const env=makeSandbox();
  const first=await env.send(A,[ackRow(A)]);
  const repeated=await env.send(A,[ackRow(A)]);
  const altered=await env.send(A,[ackRow(A,{sha256:'b'.repeat(64)})]);
  assert.equal(first.data.results[0].status,'applied');
  assert.equal(repeated.data.results[0].status,'already_acknowledged');
  assert.equal(altered.data.results[0].status,'receipt_conflict');
  assert.equal(env.receipts.size,1);
});

test('old event version cannot be acknowledged, even with correct token',async()=>{
  const env=makeSandbox();
  const bad=await env.send(A,[ackRow(A,{updated_at:'2026-10-13T12:00:00.000Z'})]);
  assert.equal(bad.data.results[0].status,'stale_version');
  assert.equal(env.receipts.size,0);
});

test('invalid row identity, hash and oversized batch never produce receipts',async()=>{
  const env=makeSandbox();
  const wrong=await env.send(A,[ackRow(A,{id:'event:cccccccc-cccc-4ccc-8ccc-cccccccccccc'})]);
  const badHash=await env.send(A,[ackRow(A,{sha256:'not-a-hash'})]);
  const big=await env.send(A,Array.from({length:101},()=>ackRow(A)));
  assert.equal(wrong.data.results[0].status,'event_not_found');
  assert.equal(badHash.data.results[0].status,'invalid_request');
  assert.equal(big.code,400);
  assert.equal(env.receipts.size,0);
});

test('SQL permissions and current-version member guard are explicitly present',()=>{
  assert.match(migration,/e\.space_id\s*=\s*v_space_id/);
  assert.match(migration,/e\.updated_at\s*=\s*r\.event_updated_at/);
  assert.match(migration,/m\.space_id\s*=\s*p_space_id\s+and m\.user_id\s*=\s*\(select auth\.uid\(\)\)/);
  assert.match(migration,/revoke all on function public\.record_folego_sheet_delivery_ack[\s\S]*?from public, anon, authenticated/);
  assert.match(migration,/grant execute on function public\.get_folego_sheet_delivery_receipts[\s\S]*?to authenticated/);
  assert.match(denyMigration,/as restrictive/);
  assert.match(denyMigration,/using \(false\)/);
  assert.doesNotMatch(edge,/\.from\(["']financial_events["']\)\s*\.update/);
});
