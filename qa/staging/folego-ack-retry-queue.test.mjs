import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';

const source = fs.readFileSync('integrations/apps-script/FolegoSync.gs', 'utf8');
const retry = fs.readFileSync('integrations/apps-script/FolegoAckRetry.gs', 'utf8');
const original = {
  id: 'event:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  status: 'Confirmado',
  updated_at: '2026-10-14T12:00:00.000Z',
  occurred_at: '2026-10-14T11:30:00.000Z',
  event_type: 'expense',
  description: 'Despesa sintética',
  amount: 21.75,
  type: 'Despesa',
  payment_method: 'Conta',
  account_card: 'Fictícia',
  category: 'Teste',
};

function cellsFor(row) {
  const data = Array(20).fill('');
  data[0] = row.id; data[1] = new Date(row.occurred_at);
  data[2] = row.payment_method;
  data[3] = row.description;
  data[4] = row.amount; data[5] = row.type;
  data[6] = row.category; data[7] = row.account_card;
  data[8] = 'Confirmado'; data[9] = 'Fôlego App'; data[19] = 'PULLED';
  return data;
}

function fixture({reply = 'applied', failSave = false} = {}) {
  const properties = {
    FOLEGO_SYNC_CURSOR: '2026-10-01T00:00:00.000Z',
    FOLEGO_SHEET_ACK_ENABLED: 'true',
    FOLEGO_CATEGORIES_INSTALLED: 'true',
    FOLEGO_SYNC_TOKEN: 'synthetic-token',
  };
  const records = new Map();
  let rowsFromServer = [original], calls = 0, pullCalls = 0, flushes = 0;
  let response = reply;
  const range = (row, col, height, width) => {
    if (row === 5 && col === 2 && width === 1) {
      return {getDisplayValues: () =>
        Array.from({length: height}, (_, i) => [records.get(5 + i)?.[0] || ''])};
    }
    if (col === 2 && height === 1 && width === 20) {
      return {getValues: () => [records.get(row) || Array(20).fill('')]};
    }
    throw Error('Unexpected sheet range ' + [row, col, height, width]);
  };
  const sheet = {
    getMaxRows: () => 12,
    getRange: range,
  };
  const book = {getSheetByName: () => sheet};
  const scriptProperties = {
    getProperty: key => properties[key] ?? null,
    setProperty: (key, value) => {
      if (failSave && key.startsWith('FOLEGO_ACK_RETRY_V1_')) {
        throw Error('synthetic_quota');
      }
      properties[key] = String(value);
    },
    getProperties: () => ({...properties}),
    deleteProperty: key => {delete properties[key];},
  };
  const context = {
    Date, Math, Number, String, Map, Object, Array, JSON, Error,
    PropertiesService: {getScriptProperties: () => scriptProperties},
    SpreadsheetApp: {flush: () => {flushes++;}},
    Utilities: {
      DigestAlgorithm: {SHA_256: 'sha256'},
      Charset: {UTF_8: 'utf8'},
      computeDigest(algorithm, input) {
        assert.equal(algorithm, 'sha256');
        return [...crypto.createHash('sha256').update(input).digest()];
      },
    },
    console: {log() {}},
  };
  vm.runInNewContext(source, context);
  vm.runInNewContext(retry, context);
  context._folegoSyncApi_ = () => {
    pullCalls++;
    return {rows: rowsFromServer, cursor:'2026-10-14T12:00:00.000Z'};
  };
  context._folegoSyncFirstEmptyIdRow_ = () => 5;
  context._folegoSyncAppendLaunch_ = (_, n, row) => {records.set(n, cellsFor(row));};
  context._folegoSyncUpdateExistingLaunch_ = () => {};
  context.folegoEnviarAckAposGravacao_ = opts => {
    calls++;
    assert.equal(opts.token,'synthetic-token');
    assert.match(opts.endpoint, /\/sheet-row-ack$/);
    if (response === 'offline') throw Error('synthetic_connection_lost');
    return opts.applied.map(item => ({id:item.id,status:response}));
  };
  return {
    context, properties, records,
    run: () => context._folegoSyncPull_(book),
    get pending() {return context.folegoAckRetryStatus();},
    get calls() {return calls;},
    get pullCalls() {return pullCalls;},
    get flushes() {return flushes;},
    get cursor() {return properties.FOLEGO_SYNC_CURSOR;},
    setReply: v => {response = v;},
    noNewEvents: () => {rowsFromServer = [];},
    enableImmediateRetry() {
      for (const k of Object.keys(properties).filter(x=>x.startsWith('FOLEGO_ACK_RETRY_V1_'))) {
        const obj = JSON.parse(properties[k]);
        obj.nextAttemptAt = 0;
        properties[k] = JSON.stringify(obj);
      }
    },
  };
}

test('network outage after persisted readback survives cursor advancement', () => {
  const x = fixture({reply:'offline'});
  x.run();
  assert.equal(x.cursor,original.updated_at);
  assert.equal(x.pending.waiting,1);
  assert.equal(x.pending.review,0);
  assert.equal(x.calls,1);
  assert.ok(x.flushes > 0);
  const item = Object.entries(x.properties).find(([key])=>key.startsWith('FOLEGO_ACK_RETRY_V1_'));
  assert.ok(item);
  assert.doesNotMatch(item[1], /Despesa sintética|synthetic-token|21\.75|Fictícia/);
});

test('later cycle with empty pull retries the persisted receipt idempotently', () => {
  const x = fixture({reply:'offline'});
  x.run();
  x.setReply('already_acknowledged');
  x.noNewEvents();
  x.enableImmediateRetry(); // simulate passage of scheduled backoff
  x.run();
  assert.equal(x.pending.waiting,0);
  assert.equal(x.pending.review,0);
  assert.equal(x.calls,2);
});

test('stale backend version becomes visible for manual review, never auto-cleared', () => {
  const x = fixture({reply:'stale_version'});
  x.run();
  assert.equal(x.pending.waiting,0);
  assert.equal(x.pending.review,1);
  const oldCalls = x.calls;
  x.noNewEvents();
  x.run();
  assert.equal(x.calls,oldCalls);
});

test('a local edit between initial failure and retry blocks acknowledgement', () => {
  const x = fixture({reply:'offline'});
  x.run();
  const edited = x.records.get(5);
  edited[6] = 'Categoria alterada localmente';
  x.noNewEvents();
  x.enableImmediateRetry();
  const attempts = x.calls;
  x.run();
  assert.equal(x.calls,attempts);
  assert.equal(x.pending.review,1);
  assert.equal(x.pending.waiting,0);
});

test('a duplicate sheet ID blocks retry, retaining an unresolved review state', () => {
  const x = fixture({reply:'offline'});
  x.run();
  x.records.set(6, cellsFor(original));
  x.noNewEvents();
  x.enableImmediateRetry();
  const attempts = x.calls;
  x.run();
  assert.equal(x.calls,attempts);
  assert.equal(x.pending.review,1);
});

test('incorrect per-item ID in successful HTTP response cannot discard outbox', () => {
  const x = fixture();
  x.context.folegoEnviarAckAposGravacao_ = () => [{id:'some-other-id',status:'applied'}];
  x.run();
  assert.equal(x.pending.waiting,1);
});

test('property-store failure stops cursor before an eligible ACK is lost', () => {
  const x = fixture({failSave:true});
  assert.throws(()=>x.run(),/synthetic_quota/);
  assert.equal(x.cursor,'2026-10-01T00:00:00.000Z');
});

test('capacity full refuses another pull and preserves the cursor', () => {
  const x = fixture();
  const prefix = 'FOLEGO_ACK_RETRY_V1_';
  for (let i=0;i<240;i++) {
    const hex = i.toString(16).padStart(12,'0');
    const id = 'event:11111111-1111-1111-1111-'+hex;
    const key = x.context._folegoAckRetryKey_(id,original.updated_at);
    x.properties[key] = JSON.stringify({
      id,updated_at:original.updated_at,rowNumber:5,
      fingerprint:'a'.repeat(64),status:'review',reason:'synthetic',failures:0,nextAttemptAt:0,
    });
  }
  x.run();
  assert.equal(x.pullCalls,0);
  assert.equal(x.cursor,'2026-10-01T00:00:00.000Z');
  assert.equal(x.pending.review,240);
});

test('feature remains opt-in: disabled flag does not create an outbox', () => {
  const x = fixture();
  x.properties.FOLEGO_SHEET_ACK_ENABLED = 'false';
  x.run();
  assert.equal(x.pending.waiting,0);
  assert.equal(x.calls,0);
});
