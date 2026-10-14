import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const source = readFileSync('integrations/apps-script/FolegoSync.gs', 'utf8');
const remote = Object.freeze({
  id: 'event:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  updated_at: '2026-10-14T10:00:00.000Z',
  status: 'Confirmado',
  source: 'Fôlego App',
  event_type: 'expense',
  description: 'Conta fictícia',
  occurred_at: '2026-10-14T09:30:00.000Z',
  payment_method: 'Conta',
  amount: 42.50,
  type: 'Despesa',
  account_card: 'Teste',
  category: 'Moradia',
});

function environment({
  enabled = false, categoriesInstalled = true, existing = false, mismatch = false,
  mismatchDate = false, mismatchPayment = false, duplicateId = false,
  externalRow = false, ackStatus = 'applied', addon = true,
} = {}) {
  const properties = {
    FOLEGO_SHEET_ACK_ENABLED: String(enabled),
    FOLEGO_CATEGORIES_INSTALLED: String(categoriesInstalled),
    FOLEGO_SYNC_TOKEN: 'synthetic-token',
    FOLEGO_SYNC_CURSOR: '2026-10-01T00:00:00.000Z',
  };
  const observed = new Map();
  const payload = externalRow ? { ...remote, id: 'legacy-sheet-row-123' } : remote;
  if (existing) {
    observed.set(5, buildCells({
      ...payload, category: mismatch ? 'Outra' : remote.category,
      occurred_at: mismatchDate ? '2026-10-13T09:30:00.000Z' : remote.occurred_at,
      payment_method: mismatchPayment ? 'Cartão' : remote.payment_method,
    }));
  }
  if (duplicateId) {
    observed.set(6, buildCells(payload));
    if (!existing) observed.set(5, buildCells(payload));
  }
  let called = 0, flushed = 0, applied = null;
  const script = {
    Number, Date, Map, Array, String, JSON, Error, console: { log() {} },
    SpreadsheetApp: { flush() { flushed++; } },
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: (key) => properties[key] ?? null,
        setProperty: (key, value) => { properties[key] = value; },
      }),
    },
  };
  runInNewContext(source, script);
  const sheet = {
    getMaxRows: () => 15,
    getRange(row, col, length, width) {
      if (row === 5 && col === 2 && width === 1) {
        return { getDisplayValues: () => Array.from({ length }, (_, i) => [observed.get(5 + i)?.[0] || '']) };
      }
      if (col === 2 && length === 1 && width === 20) {
        return { getValues: () => [observed.get(row) || Array(20).fill('')] };
      }
      throw new Error('Unexpected range: ' + [row,col,length,width].join(','));
    },
  };
  const book = { getSheetByName: () => sheet };
  script._folegoSyncApi_ = () => ({ rows: [payload], cursor: '2026-10-14T10:00:00.000Z' });
  script._folegoSyncFirstEmptyIdRow_ = () => 5;
  script._folegoSyncAppendLaunch_ = (_, rowNumber, item) => { observed.set(rowNumber, buildCells(item)); };
  script._folegoSyncUpdateExistingLaunch_ = () => {};
  if (addon) {
    script.folegoEnviarAckAposGravacao_ = function (opts) {
      called++;
      applied = opts.applied;
      assert.equal(opts.token, 'synthetic-token');
      assert.match(opts.endpoint, /\/sheet-row-ack$/);
      return opts.applied.map(() => ({ status: ackStatus }));
    };
  }
  return {
    run: () => script._folegoSyncPull_(book),
    get called() { return called; },
    get flushed() { return flushed; },
    get applied() { return applied; },
    get cursor() { return properties.FOLEGO_SYNC_CURSOR; },
  };
}

function buildCells(item) {
  const cells = Array(20).fill('');
  cells[0] = item.id; cells[1] = new Date(item.occurred_at);
  cells[2] = item.payment_method;
  cells[3] = item.description; cells[4] = item.amount;
  cells[5] = item.type; cells[6] = item.category; cells[7] = item.account_card;
  cells[8] = 'Confirmado'; cells[9] = 'Fôlego App'; cells[19] = 'PULLED';
  return cells;
}

test('flag off by default: no new acknowledgement requests', () => {
  const x = environment();
  x.run();
  assert.equal(x.called, 0);
  assert.equal(x.cursor, '2026-10-14T10:00:00.000Z');
});

test('written row is re-read after flush before an ACK is requested', () => {
  const x = environment({enabled:true});
  x.run();
  assert.equal(x.called, 1);
  assert.ok(x.flushed > 0);
  assert.equal(x.applied.length, 1);
  assert.equal(x.applied[0].id, remote.id);
  assert.equal(x.applied[0].updated_at, remote.updated_at);
});

test('user-edited category is protected: no fake success', () => {
  const x = environment({enabled:true, existing:true, mismatch:true});
  x.run();
  assert.equal(x.called, 0);
});

test('matching existing row can be checked but never changes its values', () => {
  const x = environment({enabled:true, existing:true});
  x.run();
  assert.equal(x.called, 1);
});

test('without add-on, sync remains read/write operational and does not claim ACK', () => {
  const x = environment({enabled:true, addon:false});
  x.run();
  assert.equal(x.called, 0);
});

test('stale or disputed response is not silently promoted to receipt', () => {
  const x = environment({enabled:true, ackStatus:'stale_version'});
  x.run();
  assert.equal(x.called, 1);
  assert.equal(x.cursor, '2026-10-14T10:00:00.000Z');
});

test('no receipt for a timestamp changed in the spreadsheet', () => {
  const x = environment({ enabled: true, existing: true, mismatchDate: true });
  x.run();
  assert.equal(x.called, 0);
});

test('no receipt for a locally changed payment method', () => {
  const x = environment({ enabled: true, existing: true, mismatchPayment: true });
  x.run();
  assert.equal(x.called, 0);
});

test('duplicate row identifiers are never acknowledged', () => {
  const x = environment({ enabled: true, existing: true, duplicateId: true });
  x.run();
  assert.equal(x.called, 0);
});

test('initial pilot excludes sheet-origin external IDs', () => {
  const x = environment({ enabled: true, existing: true, externalRow: true });
  x.run();
  assert.equal(x.called, 0);
});

test('ACK is blocked when bidirectional category CAS protection is missing', () => {
  const x = environment({ enabled: true, categoriesInstalled: false });
  x.run();
  assert.equal(x.called, 0);
});
