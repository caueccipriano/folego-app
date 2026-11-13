import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/income_date_schedule.dart';
import 'folego_repository.dart';

/// Calendário pessoal, separado de recorrências contábeis, projeções e caixa.
/// Nunca escreve em financial_events nem em account balances.
extension FolegoRepositoryIncomeDates on FolegoRepository {
  Future<List<IncomeDateSchedule>> listIncomeDateSchedules(String spaceId) async {
    final response = await Supabase.instance.client
        .from('income_date_schedules')
        .select('id,label,day_of_month,last_day_of_month,starts_on,active')
        .eq('space_id', spaceId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response)
        .map(IncomeDateSchedule.fromJson)
        .toList(growable: false);
  }

  Future<List<IncomeDateAmount>> listIncomeDateAmounts({
    required String spaceId,
    required DateTime from,
    required DateTime until,
  }) async {
    final response = await Supabase.instance.client
        .from('income_date_amounts')
        .select('schedule_id,due_date,confirmed_amount')
        .eq('space_id', spaceId)
        .gte('due_date', _incomeDate(from))
        .lte('due_date', _incomeDate(until));
    return List<Map<String, dynamic>>.from(response)
        .map(IncomeDateAmount.fromJson)
        .toList(growable: false);
  }

  Future<void> addIncomeDateSchedule({
    required String spaceId,
    required String label,
    required int? dayOfMonth,
    required bool lastDayOfMonth,
    required DateTime startsOn,
  }) async {
    if (label.trim().isEmpty || label.trim().length > 120 ||
        (!lastDayOfMonth && (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31))) {
      throw ArgumentError('Informe uma descrição e uma data válida');
    }
    await Supabase.instance.client.from('income_date_schedules').insert({
      'space_id': spaceId,
      'label': label.trim(),
      'day_of_month': lastDayOfMonth ? null : dayOfMonth,
      'last_day_of_month': lastDayOfMonth,
      'starts_on': _incomeDate(startsOn),
      'active': true,
    });
  }

  Future<void> removeIncomeDateSchedule({
    required String spaceId,
    required String scheduleId,
  }) async {
    await Supabase.instance.client
        .from('income_date_schedules')
        .delete().eq('space_id', spaceId).eq('id', scheduleId);
  }

  Future<void> confirmScheduledIncomeAmount({
    required String spaceId,
    required String scheduleId,
    required DateTime dueDate,
    required double amount,
  }) async {
    if (!amount.isFinite || amount <= 0 || amount > 999999999999.99) {
      throw ArgumentError.value(amount, 'amount', 'Valor inválido');
    }
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('É necessário estar conectado');
    await client.from('income_date_amounts').upsert({
      'space_id': spaceId,
      'schedule_id': scheduleId,
      'due_date': _incomeDate(dueDate),
      'confirmed_amount': amount,
      'confirmed_by': user.id,
      'confirmed_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'space_id,schedule_id,due_date');
  }

  Future<void> clearScheduledIncomeAmount({
    required String spaceId,
    required String scheduleId,
    required DateTime dueDate,
  }) async {
    await Supabase.instance.client
        .from('income_date_amounts')
        .delete()
        .eq('space_id', spaceId)
        .eq('schedule_id', scheduleId)
        .eq('due_date', _incomeDate(dueDate));
  }
}

String _incomeDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
