import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
const addon = fs.readFileSync('integrations/apps-script/folego-row-ack-addon.gs', 'utf8');
const endpoint = fs.readFileSync('supabase/functions/sheet-row-ack/index.ts', 'utf8');
const migration = fs.readFileSync('supabase/migrations/20261014034000_sheet_delivery_ack_v1.sql', 'utf8');

function environment(ids, responseStatuses = []) {
  let flushes = 0;
  const sent = [];
  const readRows = [];
  const headers = Array.from({ length: 36 }, () => '');
  headers[1] = 'ID'; headers[4] = 'Descrição';
  headers[5] = 'Valor'; headers[6] = 'Tipo';
  headers[7] = 'Categoria'; headers[8] = 'Conta / cartão'; headers[9] = 'Status';
  const rows = Object.fromEntries(ids.map(([number, id]) => {
    const row = Array.from({ length: 36 }, () => '');
    row[1] = id; row[4] = 'test item'; row[5] = '12.00';
    row[6] = 'Despesa'; row[7] = 'Comida'; row[8] = 'Conta'; row[9] = 'Confirmado';
    return [number, row];
  }));
  const sheet = {
    getRange(row, col, height, width) {
      assert.equal(col, 1);
      assert.equal(height, 1);
      readRows.push(row);
      return { getDisplayValues: () => [row === 4 ? headers : rows[row]] };
    },
  };
  const context = {
    Number, Array, JSON, Error, String,
    SpreadsheetApp: { flush() { flushes++; } },
    Utilities: {
      DigestAlgorithm: { SHA_256: 'sha256' },
      Charset: { UTF_8: 'utf8' },
      computeDigest(alg, value) {
        assert.equal(alg, 'sha256');
        return [...crypto.createHash('sha256').update(value).digest()];
      },
    },
    UrlFetchApp: {
      fetch(url, options) {
        assert.equal(url, 'https://example.com/ack');
        const p = JSON.parse(options.payload);
        assert.equal(p.action, 'pull_ack');
        assert.equal(options.headers['x-spreadsheet-id'], 'test-spreadsheet');
        assert.equal(options.headers['x-folego-sync-token'], 'test-token');
        sent.push(...p.rows);
        return {
          getResponseCode: () => 200,
          getContentText: () => JSON.stringify({
            ok: true,
            results: p.rows.map((row, i) => ({
              id: row.id, status: responseStatuses[i] || 'applied',
            })),
          }),
        };
      },
    },
  };
  vm.runInNewContext(addon, context);
  return {
    send: context.folegoEnviarAckAposGravacao_,
    sheet, sent, readRows, get flushes() { return flushes; },
  };
}

test('ACK is sent only after flush and rereading matching written row IDs', () => {
  const env = environment([[5, 'event:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'],
                           [6, 'sheet-item-b']]);
  const outcomes = env.send({
    sheet: env.sheet, endpoint: 'https://example.com/ack',
    spreadsheetId: 'test-spreadsheet', token: 'test-token',
    applied: [
      { rowNumber: 5, id: 'event:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        updated_at: '2026-10-14T03:00:00.000Z' },
      { rowNumber: 6, id: 'wrong-id', updated_at: '2026-10-14T03:00:00Z' },
      { rowNumber: 5, id: 'event:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        updated_at: '2026-10-14T03:00:00.000Z' },
    ],
  });
  assert.equal(env.flushes, 1);
  assert.equal(env.sent.length, 1);
  assert.match(env.sent[0].sha256, /^[0-9a-f]{64}$/);
  assert.equal(outcomes[0].status, 'applied');
});

test('per-row errors are not silently marked successful', () => {
  const env = environment([[5, 'event:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa']],
                          ['stale_version']);
  const results = env.send({
    sheet: env.sheet, endpoint: 'https://example.com/ack',
    spreadsheetId: 'test-spreadsheet', token: 'test-token',
    applied: [{ rowNumber: 5,
      id: 'event:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      updated_at: '2026-10-14T03:00:00Z' }],
  });
  assert.equal(results[0].status, 'stale_version');
});

test('a missing existing token blocks requests instead of guessing credentials', () => {
  const env = environment([[5, 'x']]);
  assert.throws(() => env.send({
    sheet: env.sheet, endpoint: 'https://example.com/ack',
    spreadsheetId: 'test-spreadsheet', token: '',
    applied: [],
  }), /ack_config_incompleta/);
  assert.equal(env.sent.length, 0);
});

test('server feature has no direct financial ledger mutations', () => {
  assert.match(endpoint, /record_folego_sheet_delivery_ack/);
  assert.match(endpoint, /x-folego-sync-token/);
  assert.match(endpoint, /stale_version|record_folego_sheet_delivery_ack/);
  assert.doesNotMatch(endpoint, /\.from\(["']financial_events["']\)\s*\.update/);
  assert.match(migration, /enable row level security/);
  assert.match(migration, /from public, anon, authenticated/);
  assert.match(migration, /e.updated_at = r.event_updated_at/);
});
