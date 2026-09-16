import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/upcoming_financial_event.dart';
import 'folego_repository.dart';

extension FolegoRepositoryAgenda on FolegoRepository {
  Future<List<UpcomingFinancialEvent>> getFinancialAgenda(
    String spaceId, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 120,
  }) async {
    if (limit <= 0 || limit > 200) {
      throw ArgumentError.value(limit, 'limit', 'Deve estar entre 1 e 200.');
    }
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      throw ArgumentError('A data final não pode ser anterior à inicial.');
    }

    final response = await Supabase.instance.client.rpc(
      'get_upcoming_events',
      params: {
        'p_space_id': spaceId,
        'p_start_date': _agendaDate(startDate),
        'p_end_date': _agendaDate(endDate),
        'p_limit': limit,
      },
    );

    return List<Map<String, dynamic>>.from(response as List)
        .map(UpcomingFinancialEvent.fromJson)
        .toList(growable: false);
  }
}

String? _agendaDate(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
