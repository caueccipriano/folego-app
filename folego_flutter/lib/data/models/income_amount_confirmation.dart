/// Valor explicitamente informado para um recebimento FUTURO.
/// Não é uma transação, não representa dinheiro recebido e não afeta saldo.
class IncomeAmountConfirmation {
  const IncomeAmountConfirmation({
    required this.recurringItemId,
    required this.dueDate,
    required this.amount,
    required this.confirmedAt,
  });

  final String recurringItemId;
  final DateTime dueDate;
  final double amount;
  final DateTime confirmedAt;

  String get occurrenceKey =>
      occurrenceId(recurringItemId, dueDate);

  static String occurrenceId(String itemId, DateTime date) =>
      '$itemId:${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  factory IncomeAmountConfirmation.fromJson(Map<String, dynamic> json) {
    final value = json['confirmed_amount'];
    final amount = value is num ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (amount == null || !amount.isFinite || amount <= 0) {
      throw const FormatException('Confirmação de receita inválida');
    }
    return IncomeAmountConfirmation(
      recurringItemId: json['recurring_item_id'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      amount: amount,
      confirmedAt: DateTime.parse(json['confirmed_at'] as String),
    );
  }
}
