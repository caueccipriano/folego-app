#!/usr/bin/env node
/**
 * FÔLEGO Sync 2.0 — conservative Apps Script source-only reconciliation.
 * GitHub Actions workflow_dispatch is the ONLY caller with remote write access.
 *
 * Apps Script projects.updateContent replaces ALL files. Therefore this tool
 * always reads every installed file, preserves unrelated code + manifest, creates
 * an immutable PRE-WRITE Google version, checks concurrent changes, and verifies
 * every source after its write. It does NOT redeploy the Web App, create triggers,
 * change Script Properties, or turn on ACK.
 */
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { Script } from 'node:vm';

const SCRIPT_ID = '1UByBukssmkEy__94vG02_hsJ4m8la52Ek2FaWZrO96jLihYB891uyHU5';
const ENDPOINT = 'https://script.googleapis.com/v1/projects/' + encodeURIComponent(SCRIPT_ID);
const PROJECT_FILES = [
  { name: 'FolegoSync', path: 'integrations/apps-script/FolegoSync.gs' },
  { name: 'FolegoRowAck', path: 'integrations/apps-script/folego-row-ack-addon.gs' },
  { name: 'FolegoAckRetry', path: 'integrations/apps-script/FolegoAckRetry.gs' },
];
const mode = process.argv.find(arg => arg.startsWith('--mode='))?.slice(7) ?? 'validate';
const sha = s => createHash('sha256').update(s, 'utf8').digest('hex');
const stableFiles = files => JSON.stringify(files.map(f => ({
  name: f.name, type: f.type, source: f.source,
})).sort((a, b) => a.name.localeCompare(b.name)));
const die = message => { throw new Error(message); };
const sources = PROJECT_FILES.map(file => ({
  ...file,
  source: readFileSync(file.path, 'utf8'),
}));

for (const source of sources) {
  if (!source.source.trim()) die('empty_source_' + source.name);
  new Script(source.source, { filename: source.path });
  if (/\bfunction\s+do(?:Post|Get)\s*\(/i.test(source.source)) {
    die('web_app_handler_in_sync_module_' + source.name);
  }
}
if (!sources[0].source.includes('FOLEGO_SHEET_ACK_ENABLED') ||
    !sources[0].source.includes('_folegoSyncAckCandidate_') ||
    !sources[1].source.includes('folegoEnviarAckAposGravacao_') ||
    !sources[2].source.includes('folegoAckRetryStatus')) {
  die('incorrect_or_incomplete_sync2_sources');
}
console.log('Local source syntax/ACK hooks: valid (' + sources.length + ' modules).');
if (mode === 'validate') process.exit(0);
if (!['remote-audit', 'install'].includes(mode)) die('invalid_mode');

const raw = process.env.CLASPRC_JSON ?? '';
if (!raw) die('missing_GitHub_secret_CLASPRC_JSON');
let credentials;
try {
  const parsed = JSON.parse(raw);
  const token = parsed.tokens?.default ?? parsed;
  const legacyToken = parsed.token ?? {};
  credentials = {
    client_id: token.client_id ?? parsed.oauth2ClientSettings?.clientId,
    client_secret: token.client_secret ?? parsed.oauth2ClientSettings?.clientSecret,
    refresh_token: token.refresh_token ?? legacyToken.refresh_token,
  };
} catch { die('CLASPRC_JSON_invalid_json'); }
if (!Object.values(credentials).every(x => typeof x === 'string' && x.length > 0)) {
  die('CLASPRC_JSON_requires_clasp_3_OAuth_client_and_refresh_token');
}
const requestToken = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST',
  headers: { 'content-type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({ ...credentials, grant_type: 'refresh_token' }),
});
if (!requestToken.ok) die('Google_OAuth_refresh_failed_HTTP_' + requestToken.status);
const access_token = (await requestToken.json()).access_token;
if (typeof access_token !== 'string' || !access_token) die('Google_OAuth_token_absent');

async function google(method, path = '', body) {
  const response = await fetch(ENDPOINT + path, {
    method,
    headers: {
      Authorization: 'Bearer ' + access_token,
      'content-type': 'application/json',
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  if (!response.ok) die('Apps_Script_API_' + method + '_HTTP_' + response.status);
  return await response.json();
}
const original = await google('GET', '/content');
if (original.scriptId && original.scriptId !== SCRIPT_ID) die('wrong_remote_script_id');
const previous = original.files;
if (!Array.isArray(previous) || previous.length < 5) die('remote_project_files_missing');
const manifest = previous.find(f => f.name === 'appsscript' && f.type === 'JSON');
if (!manifest?.source) die('manifest_missing');
JSON.parse(manifest.source);
const originalNames = new Set();
for (const file of previous) {
  if (!file.name || !file.type || typeof file.source !== 'string') die('remote_source_missing');
  if (originalNames.has(file.name)) die('duplicate_remote_filenames');
  originalNames.add(file.name);
}
const replacedNames = new Set(['FolegoSync', 'FolegoRowAck',
  'folego-row-ack-addon', 'FolegoAckRetry']);
const protectedOriginals = previous.filter(f => !replacedNames.has(f.name));
if (protectedOriginals.length < 4) die('insufficient_original_files_to_preserve');
if (!protectedOriginals.some(f => /\bfunction\s+doPost\s*\(/.test(f.source))) {
  die('original_web_app_doPost_not_found_do_not_overwrite');
}
const installedAckNames = previous.filter(f =>
  ['FolegoRowAck', 'folego-row-ack-addon'].includes(f.name));
if (installedAckNames.length > 1) die('duplicate_ACK_addon_files_conflict');
const ackName = installedAckNames[0]?.name ?? 'FolegoRowAck';
const targets = new Map(sources.map(f => [f.name === 'FolegoRowAck' ? ackName : f.name,
  { name: f.name === 'FolegoRowAck' ? ackName : f.name, type: 'SERVER_JS', source: f.source }]));
const current = previous.map(f => ({
  name: f.name, type: f.type, source: f.source,
}));
const merged = current.map(f => targets.has(f.name) ? targets.get(f.name) : f);
for (const [name, file] of targets) {
  if (!originalNames.has(name)) merged.push(file);
}
const existing = new Map(current.map(f => [f.name, f]));
const changes = merged.filter(f => existing.get(f.name)?.source !== f.source)
  .map(f => f.name);
console.log('Remote scripts found: ' + current.length +
  '; target files different/new: ' + changes.join(', '));
console.log('All preserved files: ' + protectedOriginals.length + ', manifest unchanged.');
if (mode === 'remote-audit') {
  console.log('REMOTE READ-ONLY audit complete. No modifications made.');
  process.exit(0);
}
if (changes.length === 0) {
  console.log('Already installed: source matches; no write performed.');
  process.exit(0);
}
const preWriteFingerprint = sha(stableFiles(current));
// Guard against parallel edits BEFORE recording the backup version.
const reread = await google('GET', '/content');
if (sha(stableFiles(reread.files ?? [])) !== preWriteFingerprint) {
  die('concurrent_remote_change_before_backup');
}
const backup = await google('POST', '/versions', {
  description: 'PRE-Folego-Sync2-safe-install GH-' +
    (process.env.GITHUB_RUN_ID ?? 'manual'),
});
if (!Number.isInteger(backup.versionNumber) || backup.versionNumber < 1) {
  die('pre_install_immutable_backup_not_confirmed');
}
console.log('Immutable Google Apps Script pre-install version: ' + backup.versionNumber);
const preUpdate = await google('GET', '/content');
if (sha(stableFiles(preUpdate.files ?? [])) !== preWriteFingerprint) {
  die('concurrent_remote_change_after_backup');
}
// Google updates the full project content. We never send the repository alone.
await google('PUT', '/content', { files: merged });
const post = await google('GET', '/content');
const postMap = new Map((post.files ?? []).map(f => [f.name, f]));
for (const file of merged) {
  const fromGoogle = postMap.get(file.name);
  if (!fromGoogle || fromGoogle.type !== file.type ||
      fromGoogle.source !== file.source) {
    die('post_write_verification_failed_for_' + file.name +
      '_preinstall_version_' + backup.versionNumber);
  }
}
if (postMap.size !== merged.length) die('remote_file_count_mismatch_after_install');
console.log('Verified source-only install: ' + changes.join(', ') +
  '. Original files preserved. ACK flag NOT modified; no trigger, deployment or financial write.');
