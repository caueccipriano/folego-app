import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import crypto from 'node:crypto';

// Uses a mocked spreadsheet and mocked Supabase API: no production reads/writes.
const source = readFileSync('integrations/apps-script/FolegoSync.gs', 'utf8');

function scenario({
  initialStatus = 'OK',
  changed = true,
  kind = 'Transferência',
  origin = 'Bradesco',
  categoriesInstalled = false,
  categoryConflict = false,
} = {}) {
  const properties = {
    FOLEGO_CATEGORIES_INSTALLED: String(categoriesInstalled),
    FOLEGO_SHEET_ACK_ENABLED: 'false',
  };
  const row = Array(categoriesInstalled ? 35 : 22).fill('');
  row[0] = 'QA-SYNTHETIC-TRANSFER-001';
  row[1] = new Date('2026-10-14T10:00:00.000Z');
  row[2] = 'PIX';
  row[3] = 'Movimento FICTICIO, nenhum banco real';
  row[4] = 10.12;
  row[5] = kind;
  row[6] = kind === 'Transferência' ? 'Transferências' : 'Alimentação';
  row[7] = 'Conta de teste';
  row[8] = 'Confirmado';
  row[9] = origin;
  row[11] = 'Apenas QA';
  row[12] = 2026;
  row[13] = 10;
  row[15] = 'Não duplicado';
  row[16] = 0;
  row[19] = initialStatus;
  if (categoriesInstalled) {
    row[25] = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    row[28] = row[6];
    row[29] = '';
    row[30] = '';
    row[31] = '';
    row[32] = '';
    row[33] = '';
    row[34] = categoryConflict ? 'PENDENTE: conferir categorias' : '';
    if (categoryConflict) row[28] = 'Categoria anterior';
  }

  const submitted = [];
  const script = {
    Number, Date, Map, Array, String, JSON, Error,
    console: { log() {} },
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: (key) => properties[key] ?? null,
      }),
    },
    Utilities: {
      DigestAlgorithm: { SHA_256: 'sha256' },
      Charset: { UTF_8: 'utf8' },
      computeDigest(algorithm, value) {
        assert.equal(algorithm, 'sha256');
        return [...crypto.createHash('sha256').update(value).digest()];
      },
    },
  };
  runInNewContext(source, script);
  // B:T business fingerprint, exactly as the installed sync source computes it.
  row[21] = script._folegoSyncHash_(row.slice(0, 19));
  if (changed) row[3] += ' - editado';
  let writeCount = 0;
  const sheet = {
    getLastRow: () => 5,
    getRange(start, col, height, width) {
      assert.equal(start, 5);
      assert.equal(height, 1);
      if (col === 2 && width === (categoriesInstalled ? 35 : 22)) {
        return { getValues: () => [row.slice()] };
      }
      if (col === 21 && width === 3) {
        return { setValues(values) {
          writeCount++;
          [row[19], row[20], row[21]] = values[0];
        } };
      }
      throw new Error('Unexpected spreadsheet range: ' + [start, col, height, width].join(','));
    },
  };
  const book = {
    getSheetByName(name) {
      assert.equal(name, 'Lancamentos');
      return sheet;
    },
  };
  script._folegoSyncApi_ = (request) => {
    assert.equal(request.action, 'push');
    submitted.push(...request.rows);
    return {
      results: request.rows.map((item) => ({ id: item.id, status: 'updated' })),
    };
  };
  return {
    run: () => script._folegoSyncPush_(book),
    get submitted() { return submitted; },
    get status() { return row[19]; },
    get writeCount() { return writeCount; },
    get storedHash() { return row[21]; },
  };
}

test('historical edited transfer is held for review; no push or duplicate', () => {
  const x = scenario({ initialStatus: 'OK', changed: true });
  x.run();
  assert.equal(x.submitted.length, 0);
  assert.equal(x.status, 'REVISAR MOV.');
  assert.equal(x.writeCount, 1);
});

test('already reviewed transfer stays held and preserves status', () => {
  const x = scenario({ initialStatus: 'REVISAR MOV.', changed: true });
  x.run();
  assert.equal(x.submitted.length, 0);
  assert.equal(x.status, 'REVISAR MOV.');
  assert.equal(x.writeCount, 0);
});

test('unchanged historical transfer produces no push', () => {
  const x = scenario({ initialStatus: 'OK', changed: false });
  x.run();
  assert.equal(x.submitted.length, 0);
  assert.equal(x.writeCount, 0);
});

test('new unbaselined transfer goes from Sheet to API once', () => {
  const x = scenario({ initialStatus: '', changed: false });
  x.run();
  assert.equal(x.submitted.length, 1);
  assert.equal(x.submitted[0].type, 'Transferência');
  assert.equal(x.submitted[0].amount, 10.12);
  assert.equal(x.status, 'OK');
  const saved = x.storedHash;
  x.run();
  assert.equal(x.submitted.length, 1);
  assert.equal(x.storedHash, saved);
});

test('app-originated row is never echoed back to the API', () => {
  const x = scenario({ initialStatus: 'PULLED', changed: true, origin: 'Fôlego App' });
  x.run();
  assert.equal(x.submitted.length, 0);
  assert.equal(x.status, 'PULLED');
});

test('category conflict blocks financial row push and protects local edits', () => {
  const x = scenario({
    initialStatus: 'OK', changed: true,
    categoriesInstalled: true, categoryConflict: true,
  });
  x.run();
  assert.equal(x.submitted.length, 0);
  assert.equal(x.writeCount, 0);
  assert.equal(x.status, 'OK');
});

test('edited non-transfer expense goes to API and saves its fingerprint', () => {
  const x = scenario({ initialStatus: 'OK', changed: true, kind: 'Despesa' });
  x.run();
  assert.equal(x.submitted.length, 1);
  assert.equal(x.submitted[0].type, 'Despesa');
  assert.equal(x.status, 'OK');
  x.run();
  assert.equal(x.submitted.length, 1);
});
