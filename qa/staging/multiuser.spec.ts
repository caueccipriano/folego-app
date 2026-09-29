import { expect, test, type APIRequestContext } from '@playwright/test';
import { assertIsolatedStaging, blockedDevProjectRef } from './staging-guard.mjs';

// DO NOT add this file to ordinary public-shell QA: it requires a separate
// HTTPS staging PWA built for a SEPARATE Supabase project and seeded fictional
// users. The staging guard runs before making any authenticated request.
const approved = assertIsolatedStaging(process.env);

const supabase = approved.supabaseUrl;
const apiKey = process.env.QA_SUPABASE_PUBLISHABLE_KEY!;
const identity = {
  a: {
    email: process.env.QA_FAKE_A_EMAIL!,
    password: process.env.QA_FAKE_A_PASSWORD!,
  },
  b: {
    email: process.env.QA_FAKE_B_EMAIL!,
    password: process.env.QA_FAKE_B_PASSWORD!,
  },
};

type Session = { access_token: string; user: { id: string } };

async function login(
  request: APIRequestContext,
  subject: { email: string; password: string },
): Promise<Session> {
  const response = await request.post(
    supabase + '/auth/v1/token?grant_type=password',
    {
      headers: {
        apikey: apiKey,
        'Content-Type': 'application/json',
      },
      data: subject,
      failOnStatusCode: false,
    },
  );
  // Do NOT emit server response bodies. They might include user information
  // or authentication diagnostics. A failed login is a fixture failure.
  expect(response.status(), 'fictional staging login rejected').toBe(200);
  const session: unknown = await response.json();
  if (
    typeof session !== 'object' || session === null ||
    !('access_token' in session) ||
    !('user' in session) ||
    typeof session.access_token !== 'string' ||
    !session.user || typeof session.user !== 'object' ||
    !('id' in session.user) || typeof session.user.id !== 'string'
  ) {
    throw Error('STAGING_INVALID_SYNTHETIC_LOGIN_RESPONSE');
  }
  return session as Session;
}

async function selectRows(
  request: APIRequestContext,
  session: Session,
  table: string,
  columns: string,
  column?: string,
  equals?: string,
): Promise<{ status: number; data: Array<Record<string, unknown>> }> {
  const query = new URLSearchParams({ select: columns, limit: '100' });
  if (column && equals) query.set(column, 'eq.' + equals);
  const response = await request.get(
    supabase + '/rest/v1/' + table + '?' + query.toString(),
    {
      headers: {
        apikey: apiKey,
        Authorization: 'Bearer ' + session.access_token,
      },
      failOnStatusCode: false,
    },
  );
  const status = response.status();
  if (status === 401 || status === 403) return { status, data: [] };
  expect(status, 'table missing or staging RLS unexpectedly failed').toBe(200);
  const parsed: unknown = await response.json();
  if (!Array.isArray(parsed)) throw Error('STAGING_MALFORMED_RLS_RESPONSE');
  return { status, data: parsed };
}

test('preview is HTTPS and compiled for the isolated Supabase project', async ({
  request,
}) => {
  const response = await request.get(approved.stagingSiteUrl);
  expect(response.ok(), 'isolated HTTPS preview must be available').toBe(true);
  const html = await response.text();
  expect(html).toContain('flutter_bootstrap.js');

  const jsUrl = new URL('main.dart.js', approved.stagingSiteUrl);
  const bundleResponse = await request.get(jsUrl.href);
  expect(bundleResponse.status(), 'Flutter staging bundle must be served').toBe(200);
  const bundle = await bundleResponse.text();
  expect(bundle.length).toBeGreaterThan(100_000);
  expect(bundle).toContain(approved.projectRef);
  expect(bundle).not.toContain(blockedDevProjectRef);
});

test('two real fictional logins see different owned financial spaces', async ({
  request,
}) => {
  const [a, b] = await Promise.all([
    login(request, identity.a),
    login(request, identity.b),
  ]);
  expect(a.user.id).not.toBe(b.user.id);

  const [spacesA, spacesB] = await Promise.all([
    selectRows(request, a, 'financial_spaces', 'id,owner_id'),
    selectRows(request, b, 'financial_spaces', 'id,owner_id'),
  ]);
  expect(spacesA.status).toBe(200);
  expect(spacesB.status).toBe(200);
  expect(spacesA.data.length, 'seed fake A financial space first').toBeGreaterThan(0);
  expect(spacesB.data.length, 'seed fake B financial space first').toBeGreaterThan(0);

  const ownedA = spacesA.data.filter(s => s.owner_id === a.user.id);
  const ownedB = spacesB.data.filter(s => s.owner_id === b.user.id);
  expect(ownedA.length).toBeGreaterThan(0);
  expect(ownedB.length).toBeGreaterThan(0);

  const aIds = new Set(spacesA.data.map(s => s.id));
  const bIds = new Set(spacesB.data.map(s => s.id));
  for (const id of aIds) expect(bIds.has(id)).toBe(false);
  for (const id of bIds) expect(aIds.has(id)).toBe(false);
});

test('B cannot fetch rows from A financial accounts, categories, events, imports', async ({
  request,
}) => {
  const [a, b] = await Promise.all([
    login(request, identity.a),
    login(request, identity.b),
  ]);
  const owned = await selectRows(request, a, 'financial_spaces', 'id,owner_id');
  const aSpace = owned.data.find(s => s.owner_id === a.user.id)?.id;
  expect(typeof aSpace).toBe('string');

  // A must have at least one fictional fixture row in EACH covered table,
  // otherwise an empty B result would be a false-positive RLS test.
  const tables = [
    { table: 'accounts', columns: 'id,space_id' },
    { table: 'categories', columns: 'id,space_id' },
    { table: 'financial_events', columns: 'id,space_id' },
    { table: 'import_rows', columns: 'id,space_id' },
  ];
  for (const item of tables) {
    const aRows = await selectRows(
      request, a, item.table, item.columns, 'space_id', String(aSpace),
    );
    expect(aRows.status, 'owner must read their synthetic ' + item.table).toBe(200);
    expect(
      aRows.data.length,
      'seed at least one synthetic A row in ' + item.table,
    ).toBeGreaterThan(0);

    const bRows = await selectRows(
      request, b, item.table, item.columns, 'space_id', String(aSpace),
    );
    expect(
      bRows.data,
      'B must not see any of A synthetic rows in ' + item.table,
    ).toEqual([]);
    expect([200, 401, 403]).toContain(bRows.status);
  }
});

test('device-Push RPC only identifies exact current owner and denies clients secrets', async ({
  request,
}) => {
  const [a, b] = await Promise.all([
    login(request, identity.a),
    login(request, identity.b),
  ]);
  const endpoint = process.env.QA_FAKE_A_PUSH_ENDPOINT!;
  const rpcUrl = supabase + '/rest/v1/rpc/get_my_push_device_recovery_status';

  async function ownStatus(session: Session) {
    const response = await request.post(rpcUrl, {
      headers: {
        apikey: apiKey,
        Authorization: 'Bearer ' + session.access_token,
        'Content-Type': 'application/json',
      },
      data: { p_endpoint: endpoint },
      failOnStatusCode: false,
    });
    expect(response.status(), 'owner-status RPC migration required').toBe(200);
    return (await response.json()) as unknown;
  }
  // A's fake endpoint must already be registered in this staging fixture,
  // under a valid signed A session; empty A would not actually prove RLS.
  expect(await ownStatus(a)).toBe('owned_active');
  expect(await ownStatus(b)).toBe('new_device');

  const serverOnly = await request.post(
    supabase + '/rest/v1/rpc/get_active_web_push_subscriptions',
    {
      headers: {
        apikey: apiKey,
        Authorization: 'Bearer ' + b.access_token,
        'Content-Type': 'application/json',
      },
      data: { p_user_id: a.user.id },
      failOnStatusCode: false,
    },
  );
  expect([401, 403], 'authenticated B must never access raw Push keys')
    .toContain(serverOnly.status());
});
