/// Calendário de receitas: uma data fixa por mês, sem quantia associada.
class IncomeDateSchedule {
  const IncomeDateSchedule({
    required this.id,
    required this.label,
    required this.dayOfMonth,
    required this.lastDayOfMonth,
    required this.startsOn,
    required this.active,
  });

  final String id;
  final String label;
  final int? dayOfMonth;
  final bool lastDayOfMonth;
  final DateTime startsOn;
  final bool active;

  String get whenLabel =>
      lastDayOfMonth ? 'Último dia do mês' : 'Dia $dayOfMonth de cada mês';

  /// Dias inválidos (ex. 30 de fevereiro) são ajustados para o último
  /// dia real; não são datas ou valores financeiros previstos pelo sistema.
  List<DateTime> datesBetween(DateTime from, DateTime until) {
    if (!active || until.isBefore(from)) return const [];
    final result = <DateTime>[];
    final startMonth = DateTime(from.year, from.month);
    final endMonth = DateTime(until.year, until.month);
    for (var month = startMonth;
        !month.isAfter(endMonth);
        month = DateTime(month.year, month.month + 1)) {
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      final day = lastDayOfMonth
          ? lastDay
          : (dayOfMonth ?? lastDay).clamp(1, lastDay).toInt();
      final date = DateTime(month.year, month.month, day);
      if (!date.isBefore(from) &&
          !date.isAfter(until) &&
          !date.isBefore(startsOn)) {
        result.add(date);
      }
    }
    return result;
  }

  factory IncomeDateSchedule.fromJson(Map<String, dynamic> json) =>
      IncomeDateSchedule(
        id: json['id'] as String,
        label: json['label'] as String,
        dayOfMonth: (json['day_of_month'] as num?)?.toInt(),
        lastDayOfMonth: json['last_day_of_month'] as bool? ?? false,
        startsOn: DateTime.parse(json['starts_on'] as String),
        active: json['active'] as bool? ?? true,
      );
}

/// Valor futuro confirmado manualmente; não representa saldo ou entrada.
class IncomeDateAmount {
  const IncomeDateAmount({
    required this.scheduleId,
    required this.dueDate,
    required this.amount,
  });
  final String scheduleId;
  final DateTime dueDate;
  final double amount;

  String get key => amountKey(scheduleId, dueDate);
  static String amountKey(String scheduleId, DateTime date) =>
      '$scheduleId:${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  factory IncomeDateAmount.fromJson(Map<String, dynamic> json) {
    final raw = json['confirmed_amount'];
    final amount = raw is num ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '');
    if (amount == null || !amount.isFinite || amount <= 0) {
      throw const FormatException('Valor de recebimento inválido');
    }
    return IncomeDateAmount(
      scheduleId: json['schedule_id'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      amount: amount,
    );
  }
}
