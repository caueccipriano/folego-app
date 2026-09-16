import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction detail exposes a friendly statement import source label', () {
    final source = File(
      'lib/features/transactions/transaction_detail_sheet_v2.dart',
    ).readAsStringSync();
    expect(source, contains("case 'statement-import':"));
    expect(source, contains("return 'Importado de extrato';"));
  });
}
