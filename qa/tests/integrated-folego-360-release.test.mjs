import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

function source(path) {
  return readFileSync(new URL('../../' + path, import.meta.url), 'utf8');
}

test('the consolidated Panorama contains every independently developed feature', () => {
  const src = source('folego_flutter/lib/features/panorama/panorama_360_screen.dart');
  const history = source('folego_flutter/lib/features/panorama/panorama_month_trend.dart');
  const watch = source('folego_flutter/lib/features/panorama/panorama_budget_watch.dart');
  assert.ok(src.includes('PanoramaMonthComparison(trend: data.closedMonthTrend)'));
  assert.ok(src.includes('PanoramaBudgetWatch(entries: watch)'));
  assert.ok(src.includes('onAction: _upcoming,'));
  assert.ok(src.includes('spaceId: widget.space.id,'));
  assert.ok(history.includes('expectedEarlier'));
  assert.ok(history.includes('expectedLater'));
  assert.ok(watch.includes('item.isParent'));
  assert.ok(watch.includes('FinancialPrivacy.hidden'));
});

test('CSV card purchase signs require explicit acknowledgement, not a guessed default', () => {
  const ui = source('folego_flutter/lib/features/transactions/statement_import_screen.dart');
  const parser = source('folego_flutter/lib/features/transactions/statement_import_parser.dart');
  assert.ok(ui.includes('if (signedCardCsv && _cardSignChoice == null)'));
  assert.ok(ui.includes('if (value != mapping.amountColumn) _cardSignChoice = null;'));
  assert.ok(ui.includes("'mapping': confirmedMapping.toJson()"));
  assert.ok(parser.includes('CsvCardSignConvention.purchasesPositive'));
  assert.ok(parser.includes('sourceKind == StatementImportSourceKind.card'));
  assert.ok(parser.includes('mapping.amountColumn != null'));
  assert.ok(parser.includes("'card_sign_convention': cardSignConvention.name"));
  assert.ok(parser.includes('valor ambíguo: selecione manualmente'));
});

test('the only approved marketing target is R$9.90, never an unstaged real charge', () => {
  const sub = source('folego_flutter/lib/core/subscriptions/subscription_service.dart');
  const paywall = source('folego_flutter/lib/features/premium/premium_screen.dart');
  const docs = source('docs/revenuecat-launch-checklist.md');
  assert.ok(sub.includes('9,90/mês'));
  assert.ok(paywall.includes('9.90/month. No web checkout yet.'));
  assert.ok(docs.includes('78 active paying subscribers'));
  assert.ok(docs.includes('Not configured or verified'));
  for (const [label, file] of [
    ['service', sub], ['paywall', paywall], ['guide', docs],
  ]) {
    assert.doesNotMatch(file, /(?:R\$|R\\\$)\s*14[.,]90/i, label);
  }
});

test('release workflow remains isolated from real-user databases and provider credentials', () => {
  const guard = source('qa/staging/staging-guard.mjs');
  const yaml = source('.github/workflows/isolated-two-account-staging.yml');
  const docs = source('docs/FOLEGO_360_INTEGRATED_RELEASE_REVIEW.md');
  assert.ok(guard.includes('STAGING_REAL_USER_DEV_PROJECT_FORBIDDEN'));
  assert.ok(guard.includes('STAGING_FAKE_USER_EMAIL_MARKER_REQUIRED'));
  assert.ok(guard.includes('STAGING_PROJECT_REF_MISMATCH'));
  assert.ok(yaml.includes("github.event_name == 'workflow_dispatch'"));
  assert.ok(yaml.includes('I_CONFIRM_ISOLATED_FAKE_PROJECT'));
  assert.ok(docs.includes('NOT DEPLOYED'));
  assert.ok(docs.includes('NOT APPROVED FOR CUSTOMERS'));
  assert.ok(docs.includes('NOT EXECUTED'));
  assert.ok(docs.includes('R$ 9.90/month'));
  assert.doesNotMatch(docs, /R\$\s*14[.,]90/);
});

test('financial push is scoped to a verified Auth session before delivery', () => {
  const migrations = source(
    'supabase/migrations/20260929100000_bind_web_push_to_verified_auth_session.sql',
  );
  const push = source('supabase/functions/folego-push-dispatch/index.ts');
  const digest = source('supabase/functions/folego-daily-summary/index.ts');
  assert.ok(migrations.includes('auth.sessions'));
  assert.ok(migrations.includes('session_id'));
  assert.ok(push.includes('get_active_web_push_subscriptions'));
  assert.ok(digest.includes('get_active_web_push_subscriptions'));
});
