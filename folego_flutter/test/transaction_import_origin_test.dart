import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction detail exposes a friendly statement import source label', () {
    final source = File('lib/features/transactions/transaction_detail_sheet.dart').readAsStringSync();
    expect(source, contains("'statement-import' => 'importado de extrato'"));
  });
}
