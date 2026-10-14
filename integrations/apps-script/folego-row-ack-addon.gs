/**
 * ACK seguro por linha para adicionar ao Apps Script existente, após revisão.
 *
 * NÃO registra lançamentos e NÃO escreve nas abas. Nunca envie ACK antes de
 * persistir as células com sucesso e conferir o ID aplicado. A integração
 * existente continua funcionando mesmo sem este complemento.
 *
 * Uso futuro pelo script original, após aplicar as linhas do pull:
 * folegoEnviarAckAposGravacao_({
 *   sheet: abaLancamentos, endpoint: urlDaFuncaoAck, spreadsheetId,
 *   token: tokenPrivadoExistente,
 *   applied: [{ rowNumber: 12, id: "event:<uuid>", updated_at: "2026-..." }],
 * });
 */
function folegoEnviarAckAposGravacao_(opts) {
  if (!opts || !opts.sheet || !opts.endpoint ||
      !opts.spreadsheetId || !opts.token || !Array.isArray(opts.applied)) {
    throw new Error('ack_config_incompleta');
  }
  // rowNumber is the actual sheet row successfully written; not the source index.
  const header = opts.sheet.getRange(4, 1, 1, 36).getDisplayValues()[0];
  const idColumn = header.indexOf('ID');
  const nameColumn = header.indexOf('Descrição');
  const valueColumn = header.indexOf('Valor');
  const typeColumn = header.indexOf('Tipo');
  const categoryColumn = header.indexOf('Categoria');
  const accountColumn = header.indexOf('Conta / cartão');
  const statusColumn = header.indexOf('Status');
  if ([idColumn, nameColumn, valueColumn, typeColumn, categoryColumn,
      accountColumn, statusColumn].some(function (x) { return x < 0; })) {
    throw new Error('ack_headers_inesperados');
  }

  // Flush first; if any write fails before here, caller must not invoke ACK.
  SpreadsheetApp.flush();
  const records = [];
  const seen = {};
  opts.applied.forEach(function (applied) {
    if (!applied || !Number.isInteger(applied.rowNumber) ||
        applied.rowNumber < 5 || typeof applied.id !== 'string' ||
        typeof applied.updated_at !== 'string') return;
    const row = opts.sheet.getRange(applied.rowNumber, 1, 1, header.length)
      .getDisplayValues()[0];
    if (String(row[idColumn]).trim() !== applied.id) return;
    if (seen[applied.id]) return;
    seen[applied.id] = true;
    // Fingerprint only cells actually re-read after the successful write.
    const observed = [idColumn, nameColumn, valueColumn, typeColumn,
      categoryColumn, accountColumn, statusColumn]
      .map(function (i) { return String(row[i] || ''); }).join('\u001f');
    const digest = Utilities.computeDigest(
      Utilities.DigestAlgorithm.SHA_256,
      observed,
      Utilities.Charset.UTF_8
    );
    const hash = digest.map(function (b) {
      return ('0' + ((b + 256) % 256).toString(16)).slice(-2);
    }).join('');
    records.push({
      id: applied.id,
      updated_at: applied.updated_at,
      sha256: hash,
    });
  });
  const outcomes = [];
  for (let start = 0; start < records.length; start += 100) {
    const response = UrlFetchApp.fetch(opts.endpoint, {
      method: 'post',
      muteHttpExceptions: true,
      contentType: 'application/json',
      headers: {
        'x-spreadsheet-id': opts.spreadsheetId,
        'x-folego-sync-token': opts.token,
      },
      payload: JSON.stringify({
        action: 'pull_ack',
        rows: records.slice(start, start + 100),
      }),
    });
    if (response.getResponseCode() !== 200) {
      throw new Error('ack_servidor_indisponivel_' + response.getResponseCode());
    }
    const body = JSON.parse(response.getContentText());
    if (!body.ok || !Array.isArray(body.results)) {
      throw new Error('ack_resposta_invalida');
    }
    body.results.forEach(function (r) { outcomes.push(r); });
  }
  // The caller must inspect *per-row* statuses. A 200 alone means nothing.
  // Do not alter "Sync Fôlego", categories or notes as a side effect.
  return outcomes;
}
