import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notifications/notification_models.dart';
import 'folego_repository.dart';

extension FolegoRepositoryNotifications on FolegoRepository {
  static const _preferenceColumns = '''
    reminder_style,commitment_enabled,weekly_review_enabled,
    space_id,financial_reminders_enabled,transaction_activity_enabled,invoices_enabled,debts_enabled,
    recurrences_enabled,subscriptions_enabled,expected_income_enabled,
    overdue_enabled,plan_thresholds_enabled,card_limit_thresholds_enabled,
    large_expenses_enabled,large_expense_threshold,
    daily_summary_enabled,daily_summary_time,
    quiet_hours_enabled,quiet_hours_start,quiet_hours_end,
    reminder_offset_days,preferred_time
  ''';

  Future<NotificationPreferences> getNotificationPreferences(
    String spaceId,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão necessária para carregar notificações.');
    }

    final data = await Supabase.instance.client
        .from('notification_preferences')
        .select(_preferenceColumns)
        .eq('user_id', userId)
        .eq('space_id', spaceId)
        .limit(1);
    final rows = List<Map<String, dynamic>>.from(data);
    if (rows.isEmpty) return NotificationPreferences(spaceId: spaceId);
    return NotificationPreferences.fromJson(
      rows.first,
      fallbackSpaceId: spaceId,
    );
  }

  Future<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão necessária para salvar notificações.');
    }

    final data = await Supabase.instance.client
        .from('notification_preferences')
        .upsert(
          preferences.toUpsertJson(userId),
          onConflict: 'user_id,space_id',
        )
        .select(_preferenceColumns)
        .single();
    return NotificationPreferences.fromJson(
      data,
      fallbackSpaceId: preferences.spaceId,
    );
  }

  Future<List<NotificationUpcomingEvent>> getNotificationUpcomingEvents(
    String spaceId, {
    required NotificationPreferences preferences,
    int horizonDays = 30,
    int limit = 200,
  }) async {
    if (horizonDays <= 0 || horizonDays > 30) {
      throw ArgumentError.value(
        horizonDays,
        'horizonDays',
        'Deve estar entre 1 e 30.',
      );
    }
    if (limit <= 0 || limit > 200) {
      throw ArgumentError.value(limit, 'limit', 'Deve estar entre 1 e 200.');
    }

    final data = await Supabase.instance.client.rpc(
      'get_notification_upcoming_events',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_offset_days': preferences.reminderOffsetDays,
        'p_preferred_time': preferences.preferredTimeDb,
        'p_horizon_days': horizonDays,
        'p_limit': limit,
      },
    );

    return List<Map<String, dynamic>>.from(data as List)
        .map(NotificationUpcomingEvent.fromJson)
        .toList(growable: false);
  }

  Future<List<NotificationHistoryItem>> getNotificationHistory(
    String spaceId, {
    int limit = 100,
  }) async {
    if (limit <= 0 || limit > 200) {
      throw ArgumentError.value(limit, 'limit', 'Deve estar entre 1 e 200.');
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão necessária para carregar o histórico.');
    }

    final data = await Supabase.instance.client
        .from('notification_history')
        .select('id,kind,title,body,route,delivered_at,stable_key,payload')
        .eq('user_id', userId)
        .eq('space_id', spaceId)
        .order('delivered_at', ascending: false)
        .limit(limit);

    final states = await Supabase.instance.client
        .from('financial_activity_read_state')
        .select('stable_key,seen_at')
        .eq('user_id', userId)
        .eq('space_id', spaceId);
    final seen = {for (final row in states) row['stable_key']: row['seen_at']};
    return List<Map<String, dynamic>>.from(data)
        .map((row) {
          final stableKey = row['stable_key']?.toString() ?? '';
          final key = stableKey.isEmpty ? 'legacy:${row['id']}' : stableKey;
          return NotificationHistoryItem.fromJson({
            ...row,
            'seen_at': seen[key],
          });
        })
        .toList(growable: false);
  }

  Future<int> getNotificationUnreadCount(String spaceId) async {
    final result = await Supabase.instance.client.rpc(
      'get_financial_activity_unread_count',
      params: {'p_space_id': spaceId},
    );
    return result is num
        ? result.toInt()
        : int.tryParse(result.toString()) ?? 0;
  }

  Future<void> markNotificationRead(String spaceId, String stableKey) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão necessária.');
    await Supabase.instance.client.from('financial_activity_read_state').upsert(
      {
        'user_id': userId,
        'space_id': spaceId,
        'stable_key': stableKey,
        'seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,stable_key',
    );
  }

  /// Mark only the supplied, user-owned notification keys as read.
  /// RLS checks each key against notification_history for this user and space.
  /// This never resolves receipts or modifies financial events.
  Future<int> markNotificationsReadBatch(String spaceId, List<String> keys) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão necessária.');
    final distinct = keys.where((key) => key.trim().isNotEmpty).toSet().toList();
    if (distinct.length > 100) {
      throw ArgumentError.value(distinct.length, 'keys', 'Máximo de 100 por lote.');
    }
    if (distinct.isEmpty) return 0;
    final now = DateTime.now().toUtc().toIso8601String();
    await Supabase.instance.client.from('financial_activity_read_state').upsert(
      [for (final key in distinct) {
        'user_id': userId,
        'space_id': spaceId,
        'stable_key': key,
        'seen_at': now,
      }],
      onConflict: 'user_id,stable_key',
    );
    return distinct.length;
  }

  Future<Map<String, dynamic>?> getCaptureForReview(
    String spaceId,
    String id,
  ) async {
    return await Supabase.instance.client
        .from('financial_capture_inbox')
        .select()
        .eq('space_id', spaceId)
        .eq('id', id)
        .maybeSingle();
  }
}
