import 'package:supabase_flutter/supabase_flutter.dart';

import 'folego_repository.dart';
import '../models/subscription_insights.dart';

extension FolegoRepositorySubscriptions on FolegoRepository {
  Future<List<SubscriptionCharge>> listSubscriptionCharges(String spaceId, List<String> ids) async {
    if (ids.isEmpty) { return const []; }
    final client = _subscriptionsClientOrNull;
    if (client == null) { throw StateError('Histórico indisponível.'); }
    final rows = await client.from('recurring_occurrences')
        .select('id,recurring_item_id,due_date,actual_amount,event:financial_events!inner(status)')
        .eq('space_id', spaceId)
        .inFilter('recurring_item_id', ids)
        .eq('status', 'realized')
        .eq('event.status', 'confirmed')
        .gt('actual_amount', 0)
        .order('due_date', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows)
        .map(SubscriptionCharge.fromJson).toList(growable: false);
  }

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
