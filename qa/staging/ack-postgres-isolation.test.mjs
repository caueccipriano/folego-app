/**
 * Executes the ACTUAL FÔLEGO receipt SQL migration and RPCs on a disposable
 * PostgreSQL 17 service. Uses synthetic tenant/user/event UUIDs exclusively.
 * No network connection, credentials, data or changes to Supabase production.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const A = {
  space: '11111111-1111-4111-8111-111111111111',
  user: '11111111-aaaa-4aaa-8aaa-111111111111',
  integration: '11111111-3333-4333-8333-111111111111',
  event: '11111111-2222-4222-8222-111111111111',
};
const B = {
  space: '22222222-2222-4222-8222-222222222222',
  user: '22222222-bbbb-4bbb-8bbb-222222222222',
  integration: '22222222-3333-4333-8333-222222222222',
  event: '22222222-2222-4222-8222-999999999999',
};
const version = '2026-10-14T12:00:00Z';
const digest = 'a'.repeat(64);

function sql(query, { expectFailure = false } = {}) {
  try {
    const output = execFileSync('psql', [
      '-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-c', query,
    ], { encoding: 'utf8', timeout: 12000, stdio: ['ignore','pipe','pipe'] });
    if (expectFailure) assert.fail('A forbidden SQL operation unexpectedly succeeded');
    return output.trim();
  } catch (error) {
    if (!expectFailure) throw new Error('PostgreSQL scenario failed: ' +
      String(error.stderr || error.message).slice(0, 650));
    assert.match(String(error.stderr || error.message), /permission denied|not authorized/i);
    return 'blocked';
  }
}

const setup = `
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid
  LANGUAGE sql STABLE AS 'SELECT NULLIF(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
CREATE TABLE public.financial_spaces(id uuid PRIMARY KEY);
CREATE TABLE public.space_members(
  space_id uuid NOT NULL REFERENCES public.financial_spaces(id),
  user_id uuid NOT NULL,
  PRIMARY KEY(space_id,user_id)
);
CREATE TABLE public.financial_events(
  id uuid PRIMARY KEY,
  space_id uuid NOT NULL REFERENCES public.financial_spaces(id),
  status text NOT NULL,
  external_id text,
  updated_at timestamptz NOT NULL
);
CREATE TABLE public.sheet_sync_integrations(
  id uuid PRIMARY KEY,
  space_id uuid NOT NULL REFERENCES public.financial_spaces(id),
  enabled boolean NOT NULL
);
INSERT INTO public.financial_spaces VALUES ('${A.space}'),('${B.space}');
INSERT INTO public.space_members VALUES
  ('${A.space}','${A.user}'),('${B.space}','${B.user}');
INSERT INTO public.financial_events VALUES
  ('${A.event}','${A.space}','confirmed',NULL,'${version}'),
  ('${B.event}','${B.space}','confirmed',NULL,'${version}');
INSERT INTO public.sheet_sync_integrations VALUES
  ('${A.integration}','${A.space}',true),
  ('${B.integration}','${B.space}',true);
`;

function installFixture() {
  sql(setup);
  sql(readFileSync('supabase/migrations/20261014034000_sheet_delivery_ack_v1.sql','utf8'));
  sql(readFileSync('supabase/migrations/20261014034200_sheet_delivery_ack_explicit_deny.sql','utf8'));
}

function writeAsService(tenant, rowEvent, rowVersion=version, hash=digest) {
  return sql(`SET ROLE service_role;
SELECT public.record_folego_sheet_delivery_ack(
  '${tenant.integration}'::uuid,'${rowEvent}'::uuid,
  'event:${rowEvent}', '${rowVersion}'::timestamptz, '${hash}'
)->>'status';`);
}

function readAs(tenant, requestedSpace, requestedEvents) {
  return sql(`SET ROLE authenticated;
SET request.jwt.claim.sub = '${tenant.user}';
SELECT public.get_folego_sheet_delivery_receipts(
  '${requestedSpace}'::uuid,ARRAY[${requestedEvents.map(id => `'${id}'::uuid`).join(',')}]
)::text;`);
}

// These are tests of actual SQL/permissions, not merely static source or mocks.
// Run sequentially; every psql call opens a fresh session to the disposable DB.
test('setup: install unmodified SQL migration in ephemeral PostgreSQL 17', () => {
  installFixture();
  assert.equal(sql("SELECT count(*) FROM public.sheet_sync_delivery_receipts"), '0');
});

test('service receipt: correct tenant A/B event, no cross-space write', () => {
  assert.equal(writeAsService(A,A.event), 'applied');
  assert.equal(writeAsService(B,B.event), 'applied');
  assert.equal(writeAsService(A,B.event), 'event_not_found');
  assert.equal(writeAsService(B,A.event), 'event_not_found');
  assert.equal(sql("SELECT count(*) FROM public.sheet_sync_delivery_receipts"),'2');
});

test('idempotency, changed fingerprint and obsolete revision', () => {
  assert.equal(writeAsService(A,A.event), 'already_acknowledged');
  assert.equal(writeAsService(A,A.event,version,'b'.repeat(64)), 'receipt_conflict');
  assert.equal(writeAsService(A,A.event,'2026-10-13T12:00:00Z'), 'stale_version');
  assert.equal(sql("SELECT count(*) FROM public.sheet_sync_delivery_receipts"),'2');
});

test('authenticated and anonymous roles cannot write RPC or read raw receipt table', () => {
  sql(`SET ROLE authenticated;
SELECT public.record_folego_sheet_delivery_ack(
  '${A.integration}','${A.event}','event:${A.event}','${version}','${digest}');`,
  {expectFailure:true});
  sql('SET ROLE anon; SELECT count(*) FROM public.sheet_sync_delivery_receipts;',
    {expectFailure:true});
  sql('SET ROLE authenticated; SELECT count(*) FROM public.sheet_sync_delivery_receipts;',
    {expectFailure:true});
});

test('actual SECURITY DEFINER read scopes tenant A and B separately', () => {
  const a=JSON.parse(readAs(A,A.space,[A.event,B.event]));
  const b=JSON.parse(readAs(B,B.space,[A.event,B.event]));
  assert.deepEqual(a.map(x=>x.event_id),[A.event]);
  assert.deepEqual(b.map(x=>x.event_id),[B.event]);
  sql(`SET ROLE authenticated;SET request.jwt.claim.sub='${A.user}';
SELECT public.get_folego_sheet_delivery_receipts('${B.space}',ARRAY['${B.event}'::uuid]);`,
    {expectFailure:true});
  sql(`SET ROLE authenticated;SET request.jwt.claim.sub='${B.user}';
SELECT public.get_folego_sheet_delivery_receipts('${A.space}',ARRAY['${A.event}'::uuid]);`,
    {expectFailure:true});
});

test('current-version receipt invalidation and no financial event mutation', () => {
  sql(`UPDATE public.financial_events SET updated_at='2026-10-14T13:00:00Z'
    WHERE id='${A.event}';`);
  assert.deepEqual(JSON.parse(readAs(A,A.space,[A.event])),[]);
  assert.equal(JSON.parse(readAs(B,B.space,[B.event])).length,1);
  assert.equal(sql("SELECT count(*) FROM public.sheet_sync_delivery_receipts"),'2');
  assert.equal(sql("SELECT count(*) FROM public.financial_events"),'2');
});
