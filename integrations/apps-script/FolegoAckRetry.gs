/**
 * Durable, opt-in ACK outbox for the existing FÔLEGO Apps Script.
 * Stores ONLY event ID, event version, row number and a checksum of the
 * B:U values already re-read after a successful write. No descriptions,
 * amounts, comments, tokens or balances are persisted in this outbox.
 *
 * PropertiesService quota: cap outstanding entries at 440. Stop new pull
 * before the limit is reached; NEVER move its cursor past an unqueued ACK.
 *
 * The existing time trigger/lock drives retries; no new trigger is created.
 */
const FOLEGO_ACK_RETRY_PREFIX = 'FOLEGO_ACK_RETRY_V1_';
const FOLEGO_ACK_RETRY_MAX = 440;
const FOLEGO_ACK_RETRY_PAUSE_AT = 240;
const FOLEGO_ACK_RETRY_BATCH = 75;

function _folegoAckRetryKey_(id, version) {
  const bytes = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    String(id) + '\u001f' + String(version),
    Utilities.Charset.UTF_8,
  );
  const hash = bytes.map(function (b) {
    return ((b + 256) % 256).toString(16).padStart(2, '0');
  }).join('');
  return FOLEGO_ACK_RETRY_PREFIX + hash.slice(0, 32);
}

function _folegoAckRetryEntries_(props) {
  const all = props.getProperties();
  const items = [];
  Object.keys(all).forEach(function (key) {
    if (!key.startsWith(FOLEGO_ACK_RETRY_PREFIX)) return;
    let entry;
    try { entry = JSON.parse(all[key]); } catch (_) {
      throw new Error('ack_retry_corrupted_state');
    }
    if (!entry || !/^event:[0-9a-f-]{36}$/i.test(entry.id || '')
        || !entry.updated_at || !Number.isFinite(Date.parse(entry.updated_at))
        || !Number.isInteger(entry.rowNumber) || entry.rowNumber < 5
        || !/^[0-9a-f]{64}$/.test(entry.fingerprint || '')
        || _folegoAckRetryKey_(entry.id, entry.updated_at) !== key
        || !['pending', 'review'].includes(entry.status)) {
      throw new Error('ack_retry_corrupted_state');
    }
    items.push({ key: key, entry: entry });
  });
  return items.sort(function (a, b) {
    return (a.entry.nextAttemptAt || 0) - (b.entry.nextAttemptAt || 0);
  });
}

function _folegoAckRetryCount_(props) {
  return _folegoAckRetryEntries_(props).length;
}

function _folegoAckRetryStore_(props, item) {
  props.setProperty(item.key, JSON.stringify(item.entry));
}

function _folegoAckRetryCapture_(sheet, props, candidates) {
  let size = _folegoAckRetryCount_(props);
  for (const candidate of candidates) {
    const id = String(candidate.id || '').trim();
    const version = String(candidate.updated_at || '').trim();
    if (!/^event:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)
        || !Number.isFinite(Date.parse(version))
        || !Number.isInteger(candidate.rowNumber) || candidate.rowNumber < 5) {
      throw new Error('ack_retry_invalid_candidate');
    }
    const key = _folegoAckRetryKey_(id, version);
    const previous = props.getProperty(key);
    // Do not revive a terminal conflict or rewrite its initial proof.
    if (previous) continue;
    if (size >= FOLEGO_ACK_RETRY_MAX) {
      // Caller must NOT advance the pull cursor when durable storage fails.
      throw new Error('ack_retry_backlog_capacity');
    }
    const values = sheet.getRange(candidate.rowNumber, 2, 1, 20).getValues()[0];
    if (String(values[0] || '').trim() !== id
        || _folegoSyncNormalize_(values[9]) !== 'folego app'
        || _folegoSyncNormalize_(values[8]) !== 'confirmado'
        || _folegoSyncNormalize_(values[19]) !== 'pulled') {
      throw new Error('ack_retry_failed_row_readback');
    }
    _folegoAckRetryStore_(props, {key:key,entry:{
      id: id,
      updated_at: version,
      rowNumber: candidate.rowNumber,
      fingerprint: _folegoSyncHash_(values),
      status: 'pending',
      failures: 0,
      nextAttemptAt: 0,
    }});
    size += 1;
  }
}

function _folegoAckRetryBackoff_(props, item) {
  item.entry.failures = Math.min(20, (item.entry.failures || 0) + 1);
  const minutes = Math.min(360, 5 * Math.pow(2, Math.min(7, item.entry.failures - 1)));
  item.entry.nextAttemptAt = Date.now() + minutes * 60000;
  _folegoAckRetryStore_(props, item);
}

function _folegoAckRetryReview_(props, item, reason) {
  item.entry.status = 'review';
  item.entry.reason = reason; // constant machine code, not financial details
  item.entry.nextAttemptAt = 0;
  _folegoAckRetryStore_(props, item);
}

/**
 * Flush, re-read and verify the originally acknowledged cell snapshot before
 * replay. The server independently validates space, source ID and version.
 */
function _folegoAckRetryDrain_(spreadsheet, props) {
  const saved = _folegoAckRetryEntries_(props);
  const now = Date.now();
  const due = saved.filter(function (x) {
    return x.entry.status === 'pending' &&
      (x.entry.nextAttemptAt || 0) <= now;
  }).slice(0, FOLEGO_ACK_RETRY_BATCH);
  if (!due.length) return {sent:0, accepted:0, review:0};
  if (typeof folegoEnviarAckAposGravacao_ !== 'function') {
    throw new Error('ack_retry_addon_missing');
  }
  const sheet = spreadsheet.getSheetByName(FOLEGO_SYNC_CONFIG.launchesSheet);
  if (!sheet) throw new Error('ack_retry_sheet_missing');
  SpreadsheetApp.flush();
  const first = FOLEGO_SYNC_CONFIG.firstDataRow;
  const max = Math.max(1, sheet.getMaxRows() - first + 1);
  const ids = sheet.getRange(first, 2, max, 1).getDisplayValues().flat();
  const byId = new Map();
  ids.forEach(function (raw, index) {
    const id = String(raw || '').trim();
    if (!id) return;
    if (!byId.has(id)) byId.set(id, []);
    byId.get(id).push(first + index);
  });
  const valid = [];
  let review = 0;
  for (const item of due) {
    const places = byId.get(item.entry.id) || [];
    if (places.length !== 1) {
      _folegoAckRetryReview_(props, item, places.length ? 'duplicate_id' : 'row_missing');
      review++;
      continue;
    }
    const rowNumber = places[0];
    const values = sheet.getRange(rowNumber, 2, 1, 20).getValues()[0];
    if (String(values[0] || '').trim() !== item.entry.id
        || _folegoSyncNormalize_(values[9]) !== 'folego app'
        || _folegoSyncNormalize_(values[8]) !== 'confirmado'
        || _folegoSyncNormalize_(values[19]) !== 'pulled'
        || _folegoSyncHash_(values) !== item.entry.fingerprint) {
      _folegoAckRetryReview_(props, item, 'locally_changed');
      review++;
      continue;
    }
    item.entry.rowNumber = rowNumber; // supports inserted rows above
    _folegoAckRetryStore_(props, item);
    valid.push(item);
  }
  if (!valid.length) return {sent:0,accepted:0,review:review};
  const items = valid.map(function (item) {
    return {
      id: item.entry.id,
      updated_at: item.entry.updated_at,
      rowNumber: item.entry.rowNumber,
    };
  });
  let outcomes;
  try {
    const endpoint = FOLEGO_SYNC_CONFIG.endpoint.replace(/\/sheet-sync$/, '/sheet-row-ack');
    outcomes = folegoEnviarAckAposGravacao_({
      sheet: sheet,
      endpoint: endpoint,
      spreadsheetId: FOLEGO_SYNC_CONFIG.spreadsheetId,
      token: props.getProperty('FOLEGO_SYNC_TOKEN'),
      applied: items,
    });
  } catch (_) {
    valid.forEach(function (item) { _folegoAckRetryBackoff_(props, item); });
    console.log(JSON.stringify({event:'folego_ack_retry',sent:valid.length,accepted:0,review:review,transport:'unavailable'}));
    return {sent:valid.length,accepted:0,review:review};
  }
  const outcomeById = new Map();
  (Array.isArray(outcomes) ? outcomes : []).forEach(function (result) {
    if (result && typeof result.id === 'string'
        && !outcomeById.has(result.id)) outcomeById.set(result.id, result);
  });
  const terminal = [
    'stale_version', 'receipt_conflict', 'row_identity_conflict',
    'event_not_found', 'invalid_request', 'integration_disabled',
  ];
  let accepted = 0;
  for (const item of valid) {
    const reply = outcomeById.get(item.entry.id);
    if (reply && (reply.status === 'applied' ||
                  reply.status === 'already_acknowledged')) {
      props.deleteProperty(item.key);
      accepted++;
    } else if (reply && terminal.includes(reply.status)) {
      _folegoAckRetryReview_(props, item, reply.status);
      review++;
    } else {
      _folegoAckRetryBackoff_(props, item);
    }
  }
  console.log(JSON.stringify({event:'folego_ack_retry',sent:valid.length,accepted:accepted,review:review}));
  return {sent:valid.length,accepted:accepted,review:review};
}

/** Operational counters only; never reveals IDs, financial values or tokens. */
function folegoAckRetryStatus() {
  const rows = _folegoAckRetryEntries_(PropertiesService.getScriptProperties());
  return {
    enabled: PropertiesService.getScriptProperties().getProperty('FOLEGO_SHEET_ACK_ENABLED') === 'true',
    waiting: rows.filter(function (r) { return r.entry.status === 'pending'; }).length,
    review: rows.filter(function (r) { return r.entry.status === 'review'; }).length,
    capacity: FOLEGO_ACK_RETRY_MAX,
  };
}
