import 'package:supabase_flutter/supabase_flutter.dart';

import 'folego_repository.dart';

extension FolegoRepositorySubscriptions on FolegoRepository {
  SupabaseClient? get _subscriptionsClientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> listSubscriptionRecurringIds(String spaceId) async {
    final client = _subscriptionsClientOrNull;
    if (client == null) return const <String>{};

    final response = await client
        .from('recurring_items')
        .select('id')
        .eq('space_id', spaceId)
        .eq('recurrence_kind', 'subscription');

    return List<Map<String, dynamic>>.from(response)
        .map((row) => row['id'] as String)
        .toSet();
  }

  Future<Map<String, String>> listRecurringCardNames(String spaceId) async {
    final client = _subscriptionsClientOrNull;
    if (client == null) return const <String, String>{};

    final response = await client
        .from('credit_cards')
        .select('id,name')
        .eq('space_id', spaceId);

    return {
      for (final row in List<Map<String, dynamic>>.from(response))
        if (row['id'] is String && row['name'] is String)
          row['id'] as String: row['name'] as String,
    };
  }

  Future<void> setRecurringSubscriptionKind({
    required String spaceId,
    required String itemId,
    required bool subscription,
  }) async {
    final client = _subscriptionsClientOrNull;
    if (client == null) {
      throw StateError('Supabase não está inicializado.');
    }

    await client
        .from('recurring_items')
        .update({
          'recurrence_kind': subscription ? 'subscription' : null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('space_id', spaceId)
        .eq('id', itemId);
  }
}
