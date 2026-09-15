import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_reflection.dart';
import 'folego_repository.dart';

extension FolegoRepositoryDiary on FolegoRepository {
  Future<List<DiaryEntry>> getDiaryEntries({
    required String spaceId,
    required DateTime periodMonth,
  }) async {
    final client = Supabase.instance.client;
    final start = DateTime(periodMonth.year, periodMonth.month);
    final end = DateTime(periodMonth.year, periodMonth.month + 1);

    final eventsResponse = await client
        .from('financial_events')
        .select('''
          id,
          event_type,
          description,
          amount,
          occurred_at,
          category:categories(name,parent_id)
        ''')
        .eq('space_id', spaceId)
        .eq('status', 'confirmed')
        .inFilter('event_type', eligibleDiaryEventTypes.toList())
        .gte('occurred_at', start.toUtc().toIso8601String())
        .lt('occurred_at', end.toUtc().toIso8601String())
        .order('occurred_at', ascending: false);

    final events = List<Map<String, dynamic>>.from(eventsResponse);
    if (events.isEmpty) return const [];

    final eventIds = events.map((row) => row['id'] as String).toList(growable: false);
    final reflectionResponse = await client
        .from('transaction_reflections')
        .select('id,space_id,event_id,reflection_type,note,created_at,updated_at')
        .eq('space_id', spaceId)
        .inFilter('event_id', eventIds);

    final reflections = <String, TransactionReflection>{};
    for (final row in List<Map<String, dynamic>>.from(reflectionResponse)) {
      final reflection = TransactionReflection.fromJson(row);
      reflections[reflection.eventId] = reflection;
    }

    return events.map((row) {
      final categoryRaw = row['category'];
      final category = categoryRaw is Map
          ? Map<String, dynamic>.from(categoryRaw)
          : null;
      return DiaryEntry(
        eventId: row['id'] as String,
        eventType: row['event_type'] as String,
        description: row['description'] as String? ?? 'Gasto',
        amount: (row['amount'] as num).toDouble(),
        occurredAt: DateTime.parse(row['occurred_at'] as String),
        categoryName: category?['name'] as String?,
        reflection: reflections[row['id'] as String],
      );
    }).toList(growable: false);
  }

  Future<DiarySummary> getDiarySummary({
    required String spaceId,
    required DateTime periodMonth,
  }) async {
    final entries = await getDiaryEntries(
      spaceId: spaceId,
      periodMonth: periodMonth,
    );
    return DiarySummary.fromEntries(entries);
  }

  Future<List<DiaryEntry>> getUnreflectedExpenses({
    required String spaceId,
    int limit = 5,
  }) async {
    final client = Supabase.instance.client;
    final response = await client
        .from('financial_events')
        .select('''
          id,
          event_type,
          description,
          amount,
          occurred_at,
          category:categories(name,parent_id)
        ''')
        .eq('space_id', spaceId)
        .eq('status', 'confirmed')
        .inFilter('event_type', eligibleDiaryEventTypes.toList())
        .order('occurred_at', ascending: false)
        .limit(limit * 3);

    final events = List<Map<String, dynamic>>.from(response);
    if (events.isEmpty) return const [];
    final eventIds = events.map((row) => row['id'] as String).toList(growable: false);
    final reflectedResponse = await client
        .from('transaction_reflections')
        .select('event_id')
        .eq('space_id', spaceId)
        .inFilter('event_id', eventIds);
    final reflectedIds = List<Map<String, dynamic>>.from(reflectedResponse)
        .map((row) => row['event_id'] as String)
        .toSet();

    final result = <DiaryEntry>[];
    for (final row in events) {
      final eventId = row['id'] as String;
      if (reflectedIds.contains(eventId)) continue;
      final categoryRaw = row['category'];
      final category = categoryRaw is Map
          ? Map<String, dynamic>.from(categoryRaw)
          : null;
      result.add(
        DiaryEntry(
          eventId: eventId,
          eventType: row['event_type'] as String,
          description: row['description'] as String? ?? 'Gasto',
          amount: (row['amount'] as num).toDouble(),
          occurredAt: DateTime.parse(row['occurred_at'] as String),
          categoryName: category?['name'] as String?,
        ),
      );
      if (result.length >= limit) break;
    }
    return result;
  }

  Future<void> upsertReflection({
    required String spaceId,
    required String eventId,
    required ReflectionType type,
    String? note,
  }) async {
    final normalizedNote = note?.trim();
    if (normalizedNote != null && normalizedNote.length > 300) {
      throw ArgumentError('A nota pode ter no máximo 300 caracteres.');
    }

    await Supabase.instance.client.from('transaction_reflections').upsert(
      {
        'space_id': spaceId,
        'event_id': eventId,
        'reflection_type': type.persistedValue,
        'note': normalizedNote == null || normalizedNote.isEmpty
            ? null
            : normalizedNote,
      },
      onConflict: 'space_id,event_id',
    );
  }

  Future<void> deleteReflection({
    required String spaceId,
    required String eventId,
  }) async {
    await Supabase.instance.client
        .from('transaction_reflections')
        .delete()
        .eq('space_id', spaceId)
        .eq('event_id', eventId);
  }
}
