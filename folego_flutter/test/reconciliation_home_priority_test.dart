import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/transactions/statement_import_reconciliation.dart';

void main() {
  test('financial risks require human review in existing safety contract', () {
    const ambiguous = StatementImportRiskSummary(
      transfers: 1,
      cardPayments: 0,
      possibleRefunds: 0,
      duplicateOverrides: 1,
    );
    const clear = StatementImportRiskSummary(
      transfers: 0,
      cardPayments: 0,
      possibleRefunds: 0,
      duplicateOverrides: 0,
    );
    expect(ambiguous.requiresConfirmation, isTrue);
    expect(clear.requiresConfirmation, isFalse);
  });

  test('import review shows risk preview and filters duplicates deliberately', () {
    final importer = File('lib/features/transactions/statement_import_screen.dart')
        .readAsStringSync();
    expect(importer, contains('statement-import-autopilot-risk-preview'));
    expect(importer, contains('statement-import-review-duplicates'));
    expect(importer, contains('summarizeSensitiveStatementImport('));
    expect(importer, contains('statement-import-sensitive-review-dialog'));
    expect(importer, contains('statement-import-confirm'));
  });

  test('home presents action before shortcuts on compact and desktop', () {
    final home = File('lib/features/home/home_screen_base.dart').readAsStringSync();
    final compact = home.split('if (layout == AppLayoutSize.compact) ...[').last
        .split('] else if (layout == AppLayoutSize.medium)')[0];
    expect(compact.indexOf('pulse,'), lessThan(compact.indexOf('quickActions,')));
    expect(compact.indexOf('smartCheckin,'), lessThan(compact.indexOf('quickActions,')));
    final pulse = File('lib/features/home/home_pulse_card.dart').readAsStringSync();
    expect(pulse, contains('insight.requiresAttention'));
    expect(pulse, contains('próxima ação útil'));
  });
}
