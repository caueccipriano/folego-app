import 'package:flutter_test/flutter_test.dart';
import 'package:folego_flutter/core/utils/financial_display_text.dart';

void main() {
  test('import suffix is removed only for display', () {
    expect(financialDisplayDescription('PIX enviado [extrato 5]'), 'PIX enviado');
    expect(financialDisplayDescription('PIX enviado [EXTRATO 12]  '), 'PIX enviado');
    expect(financialDisplayDescription('Compra normal'), 'Compra normal');
  });
}
