import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/income_amount_confirmation.dart';
import 'folego_repository.dart';

/// Apenas anota valores declarados pelo usuário para ocorrências de receita.
/// Nunca cria financial_events, impactos de caixa ou projeções de saldo.
extension FolegoRepositoryIncomeConfirmations on FolegoRepository {
  Future<List<IncomeAmountConfirmation>> listIncomeAmountConfirmations({
    required String spaceId,
    required DateTime from,
    required DateTime until,
  }) async {
    if (until.isBefore(from)) {
      throw ArgumentError('Período de recebimentos inválido');
    }
    final response = await Supabase.instance.client
        .from('income_amount_confirmations')
        .select('recurring_item_id,due_date,confirmed_amount,confirmed_at')
        .eq('space_id', spaceId)
        .gte('due_date', _receiptDate(from))
        .lte('due_date', _receiptDate(until))
        .order('due_date', ascending: true);
    return List<Map<String, dynamic>>.from(response)
        .map(IncomeAmountConfirmation.fromJson)
        .toList(growable: false);
  }

  Future<void> confirmIncomeAmount({
    required String spaceId,
    required String recurringItemId,
    required DateTime dueDate,
    required double amount,
  }) async {
    if (amount <= 0 || !amount.isFinite || amount > 999999999999.99) {
      throw ArgumentError.value(amount, 'amount', 'Valor inválido');
    }
    await Supabase.instance.client
        .from('income_amount_confirmations')
        .upsert({
          'space_id': spaceId,
          'recurring_item_id': recurringItemId,
          'due_date': _receiptDate(dueDate),
          'confirmed_amount': amount,
          'confirmed_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'space_id,recurring_item_id,due_date');
  }

  Future<void> clearIncomeAmount({
    required String spaceId,
    required String recurringItemId,
    required DateTime dueDate,
  }) async {
    await Supabase.instance.client
        .from('income_amount_confirmations')
        .delete()
        .eq('space_id', spaceId)
        .eq('recurring_item_id', recurringItemId)
        .eq('due_date', _receiptDate(dueDate));
  }
}

String _receiptDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
