import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/home_expense_summary.dart';
import 'package:folego/data/models/transaction_item.dart';

void main() {
  TransactionItem transaction({
    required String id,
    required String type,
    required double amount,
    String? category,
    String description = 'teste',
  }) {
    return TransactionItem(
      id: id,
      eventType: type,
      description: description,
      amount: amount,
      occurredAt: DateTime(2026, 9, 15),
      status: 'confirmed',
      source: 'app',
      categoryName: category,
    );
  }

  HomeExpenseBreakdown breakdownOf(List<TransactionItem> transactions) {
    return buildHomeExpenseBreakdown(
      transactions,
      categoryFor: (item) => item.categoryName ?? 'A classificar',
    );
  }

  test('agrega gastos e calcula percentuais', () {
    final breakdown = breakdownOf([
      transaction(id: '1', type: 'expense', amount: 50, category: 'Alimentação'),
      transaction(id: '2', type: 'card_purchase', amount: 30, category: 'Compras'),
      transaction(id: '3', type: 'benefit_expense', amount: 20, category: 'Transporte'),
    ]);

    expect(breakdown.total, 100);
    expect(breakdown.categories.map((item) => item.category), [
      'Alimentação',
      'Compras',
      'Transporte',
    ]);
    expect(breakdown.categories.map((item) => item.percentage), [50, 30, 20]);
  });

  test('não conta income, transfer, card_payment nem opening_balance', () {
    final breakdown = breakdownOf([
      transaction(id: '1', type: 'expense', amount: 40, category: 'Alimentação'),
      transaction(id: '2', type: 'income', amount: 1000, category: 'Salário'),
      transaction(id: '3', type: 'transfer', amount: 300, category: 'Transferência'),
      transaction(id: '4', type: 'card_payment', amount: 250, category: 'Cartão'),
      transaction(id: '5', type: 'opening_balance', amount: 500, category: 'Saldo'),
    ]);

    expect(breakdown.total, 40);
    expect(breakdown.categories.single.category, 'Alimentação');
  });

  test('inclui debt_payment conforme semântica de gasto existente', () {
    final breakdown = breakdownOf([
      transaction(id: '1', type: 'debt_payment', amount: 180, category: 'Dívidas'),
    ]);

    expect(breakdown.total, 180);
    expect(breakdown.categories.single.category, 'Dívidas');
  });

  test('agrupa categorias excedentes em Outros', () {
    final breakdown = breakdownOf([
      transaction(id: '1', type: 'expense', amount: 50, category: 'A'),
      transaction(id: '2', type: 'expense', amount: 40, category: 'B'),
      transaction(id: '3', type: 'expense', amount: 30, category: 'C'),
      transaction(id: '4', type: 'expense', amount: 20, category: 'D'),
      transaction(id: '5', type: 'expense', amount: 10, category: 'E'),
    ]);

    expect(breakdown.categories.length, 4);
    expect(breakdown.categories.map((item) => item.category), [
      'A',
      'B',
      'C',
      'Outros',
    ]);
    expect(breakdown.categories.last.amount, 30);
  });

  test('mantém categorias ordenadas por valor', () {
    final breakdown = breakdownOf([
      transaction(id: '1', type: 'expense', amount: 10, category: 'C'),
      transaction(id: '2', type: 'expense', amount: 90, category: 'A'),
      transaction(id: '3', type: 'expense', amount: 50, category: 'B'),
    ]);

    expect(breakdown.categories.map((item) => item.category), ['A', 'B', 'C']);
  });

  test('total zero gera estado sem gastos', () {
    final breakdown = breakdownOf([
      transaction(id: '1', type: 'income', amount: 500, category: 'Salário'),
    ]);

    expect(breakdown.total, 0);
    expect(breakdown.isEmpty, isTrue);
    expect(breakdown.categories, isEmpty);
  });

  test('remove sufixo importado [extrato N] apenas na apresentação', () {
    expect(
      homeDisplayDescription('NUV*MAISONVIEGA [extrato 12]'),
      'NUV*MAISONVIEGA',
    );
    expect(
      homeDisplayDescription('Mercado [EXTRATO 3]'),
      'Mercado',
    );
    expect(homeDisplayDescription('Mercado normal'), 'Mercado normal');
  });
}
