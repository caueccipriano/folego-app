const FOLEGO_SYNC_CONFIG = Object.freeze({
  endpoint: 'https://ycumrvkwqizlnehelhek.supabase.co/functions/v1/sheet-sync',
  spreadsheetId: '1zGaE3YSppcolxpXEp5VDpMuxPtchkm_OxRSISRtIxIE',
  launchesSheet: 'Lancamentos',
  cardsSheet: 'Cartões',
  headerRow: 4,
  firstDataRow: 5,

  // Histórico já reconstruído e auditado no Fôlego.
  // Tudo depois desta linha entra no app no primeiro ciclo.
  baselineThroughRow: 192,
  initialPullSince: '2026-06-01T00:00:00.000Z',

  syncStatusColumn: 21, // U
  syncAtColumn: 22, // V
  syncHashColumn: 23, // W
  categoryGroupColumn: 24, // X
  subcategoryColumn: 25, // Y
  categoryPathColumn: 26, // Z

  maxPushPerRun: 150,
  maxPullPerRun: 200,
});

/**
 * Instala a sincronização Fôlego <-> Controle Financeiro 2026.
 *
 * Contrato:
 * - A planilha captura data, valor, descrição e conta/cartão.
 * - O Fôlego é a fonte da classificação econômica.
 * - A classificação volta para H + X:Y:Z da mesma linha.
 *
 * Pré-requisito: FOLEGO_SYNC_TOKEN nas Script Properties.
 * Este módulo NÃO declara doPost(), portanto não altera o Web App V3.3
 * usado pelo atalho do iPhone.
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
  _folegoSyncPrepareColumns_(sheet);

  // Baseline SOMENTE até a linha 192. Linhas novas ficam sem hash e serão enviadas.
  const baselineEndRow = Math.min(sheet.getLastRow(), FOLEGO_SYNC_CONFIG.baselineThroughRow);
  if (baselineEndRow >= FOLEGO_SYNC_CONFIG.firstDataRow) {
    const count = baselineEndRow - FOLEGO_SYNC_CONFIG.firstDataRow + 1;
    const rows = sheet.getRange(FOLEGO_SYNC_CONFIG.firstDataRow, 2, count, 19).getValues(); // B:T
    const existingSync = sheet.getRange(
      FOLEGO_SYNC_CONFIG.firstDataRow,
      FOLEGO_SYNC_CONFIG.syncStatusColumn,
      count,
      3,
    ).getValues();
    const now = new Date();

    const syncValues = rows.map((row, index) => {
      const id = String(row[0] || '').trim();
      if (!id) return ['', '', ''];
      const existingStatus = String(existingSync[index][0] || '').trim();
      const existingAt = existingSync[index][1] || '';
      const existingHash = String(existingSync[index][2] || '').trim();
      if (existingStatus && existingHash) return [existingStatus, existingAt, existingHash];
      return ['BASE', now, _folegoSyncHash_(row)];
    });

    sheet.getRange(
      FOLEGO_SYNC_CONFIG.firstDataRow,
      FOLEGO_SYNC_CONFIG.syncStatusColumn,
      count,
      3,
    ).setValues(syncValues);
  }

  const installedAt = new Date().toISOString();
  props.setProperties({
    FOLEGO_SYNC_BASELINED: 'true',
    FOLEGO_SYNC_CURSOR: FOLEGO_SYNC_CONFIG.initialPullSince,
    FOLEGO_SYNC_INSTALLED_AT: installedAt,
    FOLEGO_SYNC_BASELINE_THROUGH_ROW: String(FOLEGO_SYNC_CONFIG.baselineThroughRow),
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
    const launches = spreadsheet.getSheetByName(FOLEGO_SYNC_CONFIG.launchesSheet);
    if (launches) _folegoSyncPrepareColumns_(launches);
    _folegoSyncPush_(spreadsheet);
    _folegoSyncPull_(spreadsheet);
    props.setProperty('FOLEGO_SYNC_LAST_RUN', new Date().toISOString());
  } finally {
    lock.releaseLock();
  }
}

/** Retorna um resumo de diagnóstico no editor do Apps Script. */
function folegoSyncStatus() {
  const props = PropertiesService.getScriptProperties();
  const health = _folegoSyncApi_({ action: 'health' });
  const spreadsheet = SpreadsheetApp.openById(FOLEGO_SYNC_CONFIG.spreadsheetId);
  const sheet = spreadsheet.getSheetByName(FOLEGO_SYNC_CONFIG.launchesSheet);
  let pendingSheetRows = 0;
  let errorRows = 0;

  if (sheet && sheet.getLastRow() >= FOLEGO_SYNC_CONFIG.firstDataRow) {
    const count = sheet.getLastRow() - FOLEGO_SYNC_CONFIG.firstDataRow + 1;
    const values = sheet.getRange(FOLEGO_SYNC_CONFIG.firstDataRow, 2, count, 20).getDisplayValues(); // B:U
    values.forEach((row) => {
      const id = String(row[0] || '').trim();
      if (!id) return;
      const origin = _folegoSyncNormalize_(row[9]); // K
      const syncStatus = String(row[19] || '').trim(); // U
      if (origin !== 'folego app' && !syncStatus) pendingSheetRows += 1;
      if (/^(ERRO|REVISAR)/i.test(syncStatus)) errorRows += 1;
    });
  }

  const status = {
    ok: Boolean(health && health.ok),
    mode: health && health.mode,
    spreadsheetId: FOLEGO_SYNC_CONFIG.spreadsheetId,
    baselineThroughRow: FOLEGO_SYNC_CONFIG.baselineThroughRow,
    installedAt: props.getProperty('FOLEGO_SYNC_INSTALLED_AT'),
    lastRun: props.getProperty('FOLEGO_SYNC_LAST_RUN'),
    cursor: props.getProperty('FOLEGO_SYNC_CURSOR'),
    pendingSheetRows,
    errorRows,
    triggerCount: ScriptApp.getProjectTriggers()
      .filter((t) => t.getHandlerFunction() === 'folegoSyncRun').length,
  };
  console.log(JSON.stringify(status, null, 2));
  return status;
}

function _folegoSyncPrepareColumns_(sheet) {
  sheet.getRange('U4:Z4').setValues([[
    'Sync Fôlego',
    'Sync em',
    'Sync hash',
    'Categoria Fôlego',
    'Subcategoria Fôlego',
    'Caminho Fôlego',
  ]]);
  sheet.hideColumns(FOLEGO_SYNC_CONFIG.syncStatusColumn, 3); // U:W
  sheet.showColumns(FOLEGO_SYNC_CONFIG.categoryGroupColumn, 2); // X:Y
  sheet.hideColumns(FOLEGO_SYNC_CONFIG.categoryPathColumn, 1); // Z
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

    const origin = String(row[9] || '').trim(); // K
    if (_folegoSyncNormalize_(origin) === 'folego app') continue;

    const currentHash = _folegoSyncHash_(row.slice(0, 19)); // B:T
    const syncStatus = String(row[19] || '').trim(); // U
    const storedHash = String(row[21] || '').trim(); // W
    if (syncStatus && currentHash === storedHash) continue;

    // Histórico baselinado: transferências alteradas pedem revisão.
    // Transferências novas (sem syncStatus) seguem normalmente.
    const type = _folegoSyncNormalize_(row[5]); // G
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
        category: row[6], // contexto; o app é dono da classificação
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
    sheet.getRange(
      FOLEGO_SYNC_CONFIG.firstDataRow,
      FOLEGO_SYNC_CONFIG.syncStatusColumn,
      count,
      3,
    ).setValues(syncValues);
  }
}

function _folegoSyncPull_(spreadsheet) {
  const props = PropertiesService.getScriptProperties();
  const cursor = props.getProperty('FOLEGO_SYNC_CURSOR') || FOLEGO_SYNC_CONFIG.initialPullSince;
  const response = _folegoSyncApi_({
    action: 'pull',
    since: cursor,
    limit: FOLEGO_SYNC_CONFIG.maxPullPerRun,
  });
  const rows = Array.isArray(response.rows) ? response.rows : [];

  if (!rows.length) {
    if (response.cursor) props.setProperty('FOLEGO_SYNC_CURSOR', String(response.cursor));
    return;
  }

  const launches = spreadsheet.getSheetByName(FOLEGO_SYNC_CONFIG.launchesSheet);
  if (!launches) throw new Error('A aba Lancamentos não foi encontrada.');

  const maxRows = Math.max(1, launches.getMaxRows() - FOLEGO_SYNC_CONFIG.firstDataRow + 1);
  const idValues = launches
    .getRange(FOLEGO_SYNC_CONFIG.firstDataRow, 2, maxRows, 1)
    .getDisplayValues()
    .flat();
  const rowById = new Map();
  idValues.forEach((value, offset) => {
    const id = String(value || '').trim();
    if (id && !rowById.has(id)) rowById.set(id, FOLEGO_SYNC_CONFIG.firstDataRow + offset);
  });

  for (const row of rows) {
    if (_folegoSyncNormalize_(row.status) !== 'confirmado') continue;
    const id = String(row.id || '').trim();
    if (!id) continue;

    let targetRow = rowById.get(id);
    if (targetRow) {
      _folegoSyncUpdateExistingLaunch_(launches, targetRow, row);
    } else {
      targetRow = _folegoSyncFirstEmptyIdRow_(launches);
      _folegoSyncAppendLaunch_(launches, targetRow, row);
      rowById.set(id, targetRow);
    }

    if (row.event_type === 'card_purchase') {
      _folegoSyncEnsureCardPurchase_(spreadsheet, row);
    }
  }

  if (response.cursor) props.setProperty('FOLEGO_SYNC_CURSOR', String(response.cursor));
}

function _folegoSyncUpdateExistingLaunch_(sheet, targetRow, row) {
  if (_folegoSyncIsClassifiable_(row)) {
    const parts = _folegoSyncCategoryParts_(row);
    sheet.getRange(targetRow, 8).setValue(row.category || 'A classificar'); // H
    sheet.getRange(targetRow, FOLEGO_SYNC_CONFIG.categoryGroupColumn, 1, 3).setValues([[
      parts.group,
      parts.subcategory,
      parts.path,
    ]]);
  }

  // Hash depois da escrita de H: impede o eco Planilha -> App.
  const businessValues = sheet.getRange(targetRow, 2, 1, 19).getValues()[0]; // B:T
  sheet.getRange(targetRow, FOLEGO_SYNC_CONFIG.syncStatusColumn, 1, 3).setValues([[
    'PULLED',
    new Date(),
    _folegoSyncHash_(businessValues),
  ]]);
}

function _folegoSyncAppendLaunch_(sheet, targetRow, row) {
  const templateRow = FOLEGO_SYNC_CONFIG.firstDataRow;
  sheet.getRange(templateRow, 1, 1, 26).copyTo(
    sheet.getRange(targetRow, 1, 1, 26),
    SpreadsheetApp.CopyPasteType.PASTE_NORMAL,
    false,
  );

  const occurredAt = new Date(row.occurred_at);
  const timezone = sheet.getParent().getSpreadsheetTimeZone() || 'America/Sao_Paulo';
  const year = Number(Utilities.formatDate(occurredAt, timezone, 'yyyy'));
  const month = Number(Utilities.formatDate(occurredAt, timezone, 'M'));
  const category = _folegoSyncLegacyCategoryForRow_(row);
  const observation = row.category_path ? 'Categoria app: ' + row.category_path : '';

  sheet.getRange(targetRow, 1, 1, 16).setValues([[
    'Sincronizado do Fôlego',
    row.id,
    occurredAt,
    row.payment_method || 'App',
    row.description || '',
    Number(row.amount || 0),
    row.type || 'Despesa',
    category,
    row.account_card || '',
    'Confirmado',
    'Fôlego App',
    row.card_last_four || '',
    observation,
    year,
    month,
    '',
  ]]);
  sheet.getRange(targetRow, 18).setValue(false); // R

  if (_folegoSyncIsClassifiable_(row)) {
    const parts = _folegoSyncCategoryParts_(row);
    sheet.getRange(targetRow, FOLEGO_SYNC_CONFIG.categoryGroupColumn, 1, 3).setValues([[
      parts.group,
      parts.subcategory,
      parts.path,
    ]]);
  } else {
    sheet.getRange(targetRow, FOLEGO_SYNC_CONFIG.categoryGroupColumn, 1, 3).clearContent();
  }

  const businessValues = sheet.getRange(targetRow, 2, 1, 19).getValues()[0];
  sheet.getRange(targetRow, FOLEGO_SYNC_CONFIG.syncStatusColumn, 1, 3).setValues([[
    'PULLED',
    new Date(),
    _folegoSyncHash_(businessValues),
  ]]);
}

function _folegoSyncLegacyCategoryForRow_(row) {
  if (_folegoSyncIsClassifiable_(row)) return row.category || 'A classificar';
  const type = _folegoSyncNormalize_(row.event_type).replace(/ /g, '_');
  if (type === 'card_payment') return 'Pagamento de cartão';
  if (type === 'reserve_transfer') return 'Investimentos';
  if (type === 'transfer') return 'Transferências';
  return row.category || 'Outros';
}

function _folegoSyncIsClassifiable_(row) {
  const type = _folegoSyncNormalize_(row.event_type).replace(/ /g, '_');
  return [
    'expense',
    'income',
    'card_purchase',
    'benefit_expense',
    'benefit_credit',
    'refund',
    'reimbursement',
  ].includes(type);
}

function _folegoSyncCategoryParts_(row) {
  const rawPath = String(row.category_path || '').trim();
  const fallback = String(row.category || '').trim();
  const path = rawPath || (
    fallback && _folegoSyncNormalize_(fallback) !== 'a classificar' ? fallback : ''
  );

  if (!path) {
    return {
      group: fallback || 'A classificar',
      subcategory: '',
      path: fallback || 'A classificar',
    };
  }

  const parts = path.split('>').map((part) => String(part || '').trim()).filter(Boolean);
  if (!parts.length) {
    return { group: fallback || 'A classificar', subcategory: '', path: fallback || 'A classificar' };
  }

  return {
    group: parts[0],
    subcategory: parts.length > 1 ? parts.slice(1).join(' > ') : '',
    path: parts.join(' > '),
  };
}

function _folegoSyncEnsureCardPurchase_(spreadsheet, row) {
  const sheet = spreadsheet.getSheetByName(FOLEGO_SYNC_CONFIG.cardsSheet);
  if (!sheet) throw new Error('A aba Cartões não foi encontrada.');

  const launchId = String(row.id || '').trim();
  if (!launchId) return;

  const existing = sheet.getRange(13, 10, 249, 1).getDisplayValues().flat(); // J13:J261
  const existingOffset = existing.findIndex((value) => String(value || '').trim() === launchId);
  const installments = Math.max(1, Number(row.installments_count || 1));

  // Linha já criada pelo Web App: completa/atualiza o nº de parcelas.
  // Evita compras presas em "A confirmar" por F vazio.
  if (existingOffset >= 0) {
    const targetRow = 13 + existingOffset;
    sheet.getRange(targetRow, 6).setValue(installments); // F
    SpreadsheetApp.flush();
    return;
  }

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

  if (!cardId) {
    throw new Error('Cartão do lançamento ' + launchId + ' não foi encontrado no Cadastro Central de Cartões.');
  }

  const freeOffset = existing.findIndex((value) => !String(value || '').trim());
  if (freeOffset < 0) throw new Error('A área Compras No Cartão (linhas 13:261) está sem espaço livre.');
  const targetRow = 13 + freeOffset;

  if (targetRow !== 261) {
    sheet.getRange(261, 1, 1, 14).copyTo(
      sheet.getRange(targetRow, 1, 1, 14),
      SpreadsheetApp.CopyPasteType.PASTE_NORMAL,
      false,
    );
  }

  sheet.getRange(targetRow, 4).setValue(cardId); // D
  sheet.getRange(targetRow, 6).setValue(installments); // F
  sheet.getRange(targetRow, 10).setValue(launchId); // J
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
