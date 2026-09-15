const FOLEGO_SYNC_CONFIG = Object.freeze({
  endpoint: 'https://ycumrvkwqizlnehelhek.supabase.co/functions/v1/sheet-sync',
  spreadsheetId: '1zGaE3YSppcolxpXEp5VDpMuxPtchkm_OxRSISRtIxIE',
  launchesSheet: 'Lancamentos',
  cardsSheet: 'Cartões',
  headerRow: 4,
  firstDataRow: 5,
  syncStatusColumn: 21, // U
  syncAtColumn: 22,     // V
  syncHashColumn: 23,   // W
  maxPushPerRun: 150,
  maxPullPerRun: 200,
});

/**
 * Instala a sincronização Fôlego <-> Controle Financeiro 2026.
 *
 * Pré-requisito: definir FOLEGO_SYNC_TOKEN nas Script Properties.
 * Este módulo NÃO declara doPost(), portanto não altera o Web App V3.3
 * já usado pelo atalho do iPhone.
 */
function folegoSyncInstall() {
  const props = PropertiesService.getScriptProperties();
  const token = props.getProperty('FOLEGO_SYNC_TOKEN');
  if (!token) {
    throw new Error('Defina FOLEGO_SYNC_TOKEN em Configurações do projeto > Propriedades do script antes de instalar.');
  }

  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  if (spreadsheet.getId() !== FOLEGO_SYNC_CONFIG.spreadsheetId) {
    throw new Error('Este sincronizador pertence à planilha Controle Financeiro 2026 configurada para o Fôlego.');
  }

  _folegoSyncApi_({ action: 'health' });

  const sheet = spreadsheet.getSheetByName(FOLEGO_SYNC_CONFIG.launchesSheet);
  if (!sheet) throw new Error('A aba Lancamentos não foi encontrada.');

  sheet.getRange('U4:W4').setValues([['Sync Fôlego', 'Sync em', 'Sync hash']]);
  sheet.hideColumns(FOLEGO_SYNC_CONFIG.syncStatusColumn, 3);

  const maxRow = Math.max(sheet.getLastRow(), FOLEGO_SYNC_CONFIG.firstDataRow - 1);
  if (maxRow >= FOLEGO_SYNC_CONFIG.firstDataRow) {
    const count = maxRow - FOLEGO_SYNC_CONFIG.firstDataRow + 1;
    const rows = sheet.getRange(FOLEGO_SYNC_CONFIG.firstDataRow, 2, count, 19).getValues(); // B:T
    const now = new Date();
    const syncValues = rows.map((row) => {
      const id = String(row[0] || '').trim();
      if (!id) return ['', '', ''];
      return ['BASE', now, _folegoSyncHash_(row)];
    });
    sheet.getRange(FOLEGO_SYNC_CONFIG.firstDataRow, FOLEGO_SYNC_CONFIG.syncStatusColumn, count, 3).setValues(syncValues);
  }

  const cursor = new Date().toISOString();
  props.setProperties({
    FOLEGO_SYNC_BASELINED: 'true',
    FOLEGO_SYNC_CURSOR: cursor,
    FOLEGO_SYNC_INSTALLED_AT: cursor,
  }, false);

  ScriptApp.getProjectTriggers()
    .filter((trigger) => trigger.getHandlerFunction() === 'folegoSyncRun')
    .forEach((trigger) => ScriptApp.deleteTrigger(trigger));

  ScriptApp.newTrigger('folegoSyncRun')
    .timeBased()
    .everyMinutes(5)
    .create();

  folegoSyncRun();
}

/** Executa um ciclo bidirecional. Também pode ser executado manualmente. */
function folegoSyncRun() {
  const props = PropertiesService.getScriptProperties();
  if (props.getProperty('FOLEGO_SYNC_BASELINED') !== 'true') {
    throw new Error('Execute folegoSyncInstall() uma vez antes de sincronizar.');
  }

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) return;

  try {
    const spreadsheet = SpreadsheetApp.openById(FOLEGO_SYNC_CONFIG.spreadsheetId);
    _folegoSyncPush_(spreadsheet);
    _folegoSyncPull_(spreadsheet);
    props.setProperty('FOLEGO_SYNC_LAST_RUN', new Date().toISOString());
  } finally {
    lock.releaseLock();
  }
}

/** Retorna um resumo simples para diagnóstico no editor do Apps Script. */
function folegoSyncStatus() {
  const props = PropertiesService.getScriptProperties();
  const health = _folegoSyncApi_({ action: 'health' });
  const status = {
    ok: Boolean(health && health.ok),
    spreadsheetId: FOLEGO_SYNC_CONFIG.spreadsheetId,
    installedAt: props.getProperty('FOLEGO_SYNC_INSTALLED_AT'),
    lastRun: props.getProperty('FOLEGO_SYNC_LAST_RUN'),
    cursor: props.getProperty('FOLEGO_SYNC_CURSOR'),
    triggerCount: ScriptApp.getProjectTriggers().filter((t) => t.getHandlerFunction() === 'folegoSyncRun').length,
  };
  console.log(JSON.stringify(status, null, 2));
  return status;
}

function _folegoSyncPush_(spreadsheet) {
  const sheet = spreadsheet.getSheetByName(FOLEGO_SYNC_CONFIG.launchesSheet);
  if (!sheet) throw new Error('A aba Lancamentos não foi encontrada.');

  const maxRow = sheet.getLastRow();
  if (maxRow < FOLEGO_SYNC_CONFIG.firstDataRow) return;

  const count = maxRow - FOLEGO_SYNC_CONFIG.firstDataRow + 1;
  const values = sheet.getRange(FOLEGO_SYNC_CONFIG.firstDataRow, 2, count, 22).getValues(); // B:W
  const syncValues = values.map((row) => [row[19], row[20], row[21]]); // U:W
  const pending = [];
  let technicalChanged = false;

  for (let index = 0; index < values.length && pending.length < FOLEGO_SYNC_CONFIG.maxPushPerRun; index += 1) {
    const row = values[index];
    const id = String(row[0] || '').trim();
    if (!id) continue;

    const origin = String(row[9] || '').trim();
    if (_folegoSyncNormalize_(origin) === 'folego app') continue;

    const currentHash = _folegoSyncHash_(row.slice(0, 19)); // B:T
    const syncStatus = String(row[19] || '').trim();
    const storedHash = String(row[21] || '').trim();
    if (syncStatus && currentHash === storedHash) continue;

    // Movimentações históricas já baselinadas não são alteradas automaticamente:
    // categoria não é finalidade econômica e a alteração precisa ser deliberada.
    const type = _folegoSyncNormalize_(row[5]);
    if (syncStatus && (type === 'transferencia' || type === 'transfer')) {
      if (syncStatus !== 'REVISAR MOV.') {
        syncValues[index][0] = 'REVISAR MOV.';
        syncValues[index][1] = new Date();
        technicalChanged = true;
      }
      continue;
    }

    pending.push({
      index,
      hash: currentHash,
      payload: {
        id,
        occurred_at: row[1],
        payment_method: row[2],
        description: row[3],
        amount: row[4],
        type: row[5],
        category: row[6],
        account_card: row[7],
        status: row[8],
        source: origin,
        card_last_four: row[10],
        observation: row[11],
        installment: row[14],
        possible_duplicate: row[15],
        future_commitment: row[16],
        transaction_hash: row[17],
        vinculo_cartao: row[18],
      },
    });
  }

  if (pending.length) {
    const response = _folegoSyncApi_({ action: 'push', rows: pending.map((item) => item.payload) });
    const results = Array.isArray(response.results) ? response.results : [];
    const resultById = new Map(results.map((result) => [String(result.id || ''), result]));
    const now = new Date();

    pending.forEach((item) => {
      const result = resultById.get(String(item.payload.id));
      if (!result) {
        syncValues[item.index][0] = 'ERRO: sem resposta';
        syncValues[item.index][1] = now;
        technicalChanged = true;
        return;
      }

      const resultStatus = String(result.status || 'error');
      let label = '';
      let saveHash = false;
      if (resultStatus === 'inserted' || resultStatus === 'updated') {
        label = 'OK';
        saveHash = true;
      } else if (resultStatus === 'ignored_status' || resultStatus === 'ignored_duplicate') {
        label = 'IGNORADO';
        saveHash = true;
      } else if (resultStatus === 'conflict_amount') {
        label = 'REVISAR: VALOR';
      } else if (resultStatus === 'needs_review') {
        label = 'REVISAR';
      } else {
        label = ('ERRO: ' + String(result.error || resultStatus)).slice(0, 120);
      }

      syncValues[item.index][0] = label;
      syncValues[item.index][1] = now;
      if (saveHash) syncValues[item.index][2] = item.hash;
      technicalChanged = true;
    });
  }

  if (technicalChanged) {
    sheet.getRange(FOLEGO_SYNC_CONFIG.firstDataRow, FOLEGO_SYNC_CONFIG.syncStatusColumn, count, 3).setValues(syncValues);
  }
}

function _folegoSyncPull_(spreadsheet) {
  const props = PropertiesService.getScriptProperties();
  const cursor = props.getProperty('FOLEGO_SYNC_CURSOR') || new Date().toISOString();
  const response = _folegoSyncApi_({ action: 'pull', since: cursor, limit: FOLEGO_SYNC_CONFIG.maxPullPerRun });
  const rows = Array.isArray(response.rows) ? response.rows : [];
  if (!rows.length) {
    if (response.cursor) props.setProperty('FOLEGO_SYNC_CURSOR', String(response.cursor));
    return;
  }

  const launches = spreadsheet.getSheetByName(FOLEGO_SYNC_CONFIG.launchesSheet);
  if (!launches) throw new Error('A aba Lancamentos não foi encontrada.');

  const existingIds = new Set(
    launches.getRange(FOLEGO_SYNC_CONFIG.firstDataRow, 2, Math.max(1, launches.getMaxRows() - FOLEGO_SYNC_CONFIG.firstDataRow + 1), 1)
      .getDisplayValues()
      .flat()
      .map((value) => String(value || '').trim())
      .filter(Boolean),
  );

  for (const row of rows) {
    if (_folegoSyncNormalize_(row.status) !== 'confirmado') continue;

    const id = String(row.id || '').trim();
    if (!id) continue;

    if (!existingIds.has(id)) {
      const targetRow = _folegoSyncFirstEmptyIdRow_(launches);
      _folegoSyncAppendLaunch_(launches, targetRow, row);
      existingIds.add(id);
    }

    if (row.event_type === 'card_purchase') {
      _folegoSyncEnsureCardPurchase_(spreadsheet, row);
    }
  }

  if (response.cursor) props.setProperty('FOLEGO_SYNC_CURSOR', String(response.cursor));
}

function _folegoSyncAppendLaunch_(sheet, targetRow, row) {
  const templateRow = FOLEGO_SYNC_CONFIG.firstDataRow;
  sheet.getRange(templateRow, 1, 1, 23).copyTo(
    sheet.getRange(targetRow, 1, 1, 23),
    SpreadsheetApp.CopyPasteType.PASTE_NORMAL,
    false,
  );

  const occurredAt = new Date(row.occurred_at);
  const timezone = sheet.getParent().getSpreadsheetTimeZone() || 'America/Sao_Paulo';
  const year = Number(Utilities.formatDate(occurredAt, timezone, 'yyyy'));
  const month = Number(Utilities.formatDate(occurredAt, timezone, 'M'));
  const observation = row.category_path ? 'Categoria app: ' + row.category_path : '';
  const status = 'Confirmado';

  // A:P. Q/S/T mantêm as fórmulas relativas copiadas do template.
  sheet.getRange(targetRow, 1, 1, 16).setValues([[
    'Sincronizado do Fôlego',
    row.id,
    occurredAt,
    row.payment_method || 'App',
    row.description || '',
    Number(row.amount || 0),
    row.type || 'Despesa',
    row.category || 'Outros',
    row.account_card || '',
    status,
    'Fôlego App',
    row.card_last_four || '',
    observation,
    year,
    month,
    '',
  ]]);

  sheet.getRange(targetRow, 18).setValue(false); // R: Compromisso futuro

  const businessValues = sheet.getRange(targetRow, 2, 1, 19).getValues()[0]; // B:T
  sheet.getRange(targetRow, FOLEGO_SYNC_CONFIG.syncStatusColumn, 1, 3).setValues([[
    'PULLED',
    new Date(),
    _folegoSyncHash_(businessValues),
  ]]);
}

function _folegoSyncEnsureCardPurchase_(spreadsheet, row) {
  const sheet = spreadsheet.getSheetByName(FOLEGO_SYNC_CONFIG.cardsSheet);
  if (!sheet) throw new Error('A aba Cartões não foi encontrada.');

  const launchId = String(row.id || '').trim();
  if (!launchId) return;

  const existing = sheet.getRange(13, 10, 249, 1).getDisplayValues().flat(); // J13:J261
  if (existing.some((value) => String(value || '').trim() === launchId)) return;

  const registry = sheet.getRange(6, 1, 3, 5).getDisplayValues(); // A6:E8
  const wantedName = _folegoSyncNormalize_(row.account_card);
  const wantedFinal = String(row.card_last_four || '').replace(/\D/g, '').slice(-4);
  let cardId = '';

  for (const card of registry) {
    const registryName = _folegoSyncNormalize_(card[1]);
    const registryFinal = String(card[4] || '').replace(/\D/g, '').slice(-4);
    if ((wantedName && registryName === wantedName) || (wantedFinal && registryFinal === wantedFinal)) {
      cardId = String(card[0] || '').trim();
      break;
    }
  }

  if (!cardId) throw new Error('Cartão do lançamento ' + launchId + ' não foi encontrado no Cadastro Central de Cartões.');

  const freeOffset = existing.findIndex((value) => !String(value || '').trim());
  if (freeOffset < 0) throw new Error('A área Compras No Cartão (linhas 13:261) está sem espaço livre.');
  const targetRow = 13 + freeOffset;

  // A linha 261 é o template em branco com as fórmulas relativas do bloco de compras.
  if (targetRow !== 261) {
    sheet.getRange(261, 1, 1, 14).copyTo(
      sheet.getRange(targetRow, 1, 1, 14),
      SpreadsheetApp.CopyPasteType.PASTE_NORMAL,
      false,
    );
  }

  sheet.getRange(targetRow, 4).setValue(cardId); // D: ID Cartão
  sheet.getRange(targetRow, 6).setValue(Math.max(1, Number(row.installments_count || 1))); // F
  sheet.getRange(targetRow, 10).setValue(launchId); // J: ID Lançamento Origem
  SpreadsheetApp.flush();
}

function _folegoSyncFirstEmptyIdRow_(sheet) {
  const first = FOLEGO_SYNC_CONFIG.firstDataRow;
  const values = sheet.getRange(first, 2, sheet.getMaxRows() - first + 1, 1).getDisplayValues();
  const offset = values.findIndex((row) => !String(row[0] || '').trim());
  if (offset >= 0) return first + offset;
  sheet.insertRowsAfter(sheet.getMaxRows(), 50);
  return sheet.getMaxRows() - 49;
}

function _folegoSyncApi_(body) {
  const token = PropertiesService.getScriptProperties().getProperty('FOLEGO_SYNC_TOKEN');
  if (!token) throw new Error('FOLEGO_SYNC_TOKEN não está definido nas Script Properties.');

  const response = UrlFetchApp.fetch(FOLEGO_SYNC_CONFIG.endpoint, {
    method: 'post',
    contentType: 'application/json',
    headers: {
      'x-spreadsheet-id': FOLEGO_SYNC_CONFIG.spreadsheetId,
      'x-folego-sync-token': token,
    },
    payload: JSON.stringify(body),
    muteHttpExceptions: true,
  });

  const status = response.getResponseCode();
  const text = response.getContentText();
  let parsed = {};
  try {
    parsed = text ? JSON.parse(text) : {};
  } catch (error) {
    throw new Error('Resposta inválida do sincronizador Fôlego (HTTP ' + status + ').');
  }

  if (status < 200 || status >= 300 || parsed.ok === false || parsed.error) {
    throw new Error('Fôlego Sync HTTP ' + status + ': ' + String(parsed.detail || parsed.error || text).slice(0, 300));
  }
  return parsed;
}

function _folegoSyncHash_(row) {
  const normalized = row.map((value) => {
    if (value instanceof Date) return value.toISOString();
    if (typeof value === 'number') return String(value);
    if (typeof value === 'boolean') return value ? '1' : '0';
    return String(value == null ? '' : value).trim();
  }).join('\u001f');

  const bytes = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    normalized,
    Utilities.Charset.UTF_8,
  );
  return bytes.map((byte) => ((byte + 256) % 256).toString(16).padStart(2, '0')).join('');
}

function _folegoSyncNormalize_(value) {
  return String(value == null ? '' : value)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}
