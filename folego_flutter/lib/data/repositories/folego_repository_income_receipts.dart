import 'package:supabase_flutter/supabase_flutter.dart';

import 'folego_repository.dart';
import '../models/upcoming_financial_event.dart';

/// Valor conhecido de uma ocorrência futura. Não representa dinheiro recebido.
class IncomeReceiptConfirmation {
  const IncomeReceiptConfirmation({
    required this.recurringItemId,
    required this.dueDate,
    required this.amount,
  });

  final String recurringItemId;
  final DateTime dueDate;
  final double amount;

  String get key => incomeReceiptKey(recurringItemId, dueDate);

  factory IncomeReceiptConfirmation.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    return IncomeReceiptConfirmation(
      recurringItemId: json['recurring_item_id'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      amount: rawAmount is num
          ? rawAmount.toDouble()
          : double.parse(rawAmount.toString()),
    );
  }
}

String incomeReceiptDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String incomeReceiptKey(String recurringItemId, DateTime date) =>
    '$recurringItemId|${incomeReceiptDate(date)}';

/// Nunca soma o amount projetado de uma recorrência.
class IncomeReceiptTotals {
  const IncomeReceiptTotals({
    required this.confirmedTotal,
    required this.confirmedCount,
    required this.unknownCount,
  });

  final double confirmedTotal;
  final int confirmedCount;
  final int unknownCount;

  factory IncomeReceiptTotals.fromEvents(
    Iterable<UpcomingFinancialEvent> events,
    Map<String, double> enteredAmounts,
  ) {
    var confirmedTotal = 0.0;
    var confirmedCount = 0;
    var unknownCount = 0;
    for (final event in events) {
      if (!event.isIncome || !event.isRecurring || event.realized) continue;
      final amount = enteredAmounts[incomeReceiptKey(
        event.sourceId,
        event.dueDate,
      )];
      if (amount == null || !amount.isFinite || amount <= 0) {
        unknownCount++;
      } else {
        confirmedCount++;
        confirmedTotal += amount;
      }
    }
    return IncomeReceiptTotals(
      confirmedTotal: confirmedTotal,
      confirmedCount: confirmedCount,
      unknownCount: unknownCount,
    );
  }
}

extension FolegoRepositoryIncomeReceipts on FolegoRepository {
  Future<List<IncomeReceiptConfirmation>> listIncomeReceiptConfirmations({
    required String spaceId,
    required DateTime from,
    required DateTime until,
  }) async {
    final rows = await Supabase.instance.client
        .from('income_receipt_confirmations')
        .select('recurring_item_id,due_date,amount')
        .eq('space_id', spaceId)
        .gte('due_date', incomeReceiptDate(from))
        .lte('due_date', incomeReceiptDate(until))
        .order('due_date');
    return List<Map<String, dynamic>>.from(rows)
        .map(IncomeReceiptConfirmation.fromJson)
        .toList(growable: false);
  }

  /// Atualiza apenas metadados de valor conhecido, SEM criar financial_event,
  /// financial_impact ou alterar qualquer saldo.
  Future<void> saveIncomeReceiptConfirmation({
    required String spaceId,
    required String recurringItemId,
    required DateTime dueDate,
    required num amount,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Informe um valor positivo.');
    }
    await Supabase.instance.client.from('income_receipt_confirmations').upsert({
      'space_id': spaceId,
      'recurring_item_id': recurringItemId,
      'due_date': incomeReceiptDate(dueDate),
      'amount': amount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'space_id,recurring_item_id,due_date');
  }

  Future<void> removeIncomeReceiptConfirmation({
    required String spaceId,
    required String recurringItemId,
    required DateTime dueDate,
  }) async {
    await Supabase.instance.client
        .from('income_receipt_confirmations')
        .delete()
        .eq('space_id', spaceId)
        .eq('recurring_item_id', recurringItemId)
        .eq('due_date', incomeReceiptDate(dueDate));
  }
}
