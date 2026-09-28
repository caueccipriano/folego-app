import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/financial_intelligence.dart';

void main() {
  test('compra parcelada afeta os meses corretos', () {
    final result = FinancialIntelligence.simulatePurchase(
      openingBalance: 500,
      startMonth: DateTime(2026, 10),
      projectedEntries: [
        FinanceEntry(date: DateTime(2026, 11, 5), amount: 100, category: 'Salário'),
      ],
      purchaseAmount: 600,
      installments: 3,
      months: 4,
    );
    expect(result.monthlyBalances, [300, 200, 0, 0]);
    expect(result.firstNegativeMonth, isNull);
  });

  test('sinaliza primeiro mês com saldo negativo', () {
    final result = FinancialIntelligence.simulatePurchase(
      openingBalance: 100,
      startMonth: DateTime(2026, 10),
      projectedEntries: [],
      purchaseAmount: 300,
      installments: 2,
      months: 2,
    );
    expect(result.firstNegativeMonth, 0);
    expect(result.lowestBalance, -200);
  });

  test('compara categorias sem misturar receitas', () {
    final patterns = FinancialIntelligence.compareExpenses(
      entries: [
        FinanceEntry(date: DateTime(2026, 8, 3), amount: -100, category: 'Mercado'),
        FinanceEntry(date: DateTime(2026, 9, 3), amount: -125, category: 'Mercado'),
        FinanceEntry(date: DateTime(2026, 9, 3), amount: 1000, category: 'Salário'),
      ],
      previousStart: DateTime(2026, 8),
      currentStart: DateTime(2026, 9),
      currentEnd: DateTime(2026, 10),
    );
    expect(patterns.single.variationPercent, 25);
  });
}
