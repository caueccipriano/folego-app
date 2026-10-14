import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile CSV/OFX review keeps manual confirmation outside the scroll list', () {
    final source = File('lib/features/transactions/statement_import_screen.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('statement-import-review-mobile-layout')"));
    expect(source, contains("ValueKey('statement-import-review-mobile')"));
    expect(source, contains("ValueKey('statement-import-confirm')"));
    expect(source, contains('Expanded(\n            child: ListView.separated('));
    expect(source, contains('SafeArea(\n            top: false,'));
    expect(source, contains('child: actions,'));
    expect(source, contains('validateStatementImportReconciliation('));
  });
}
