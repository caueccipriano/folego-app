import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notifications/notification_models.dart';
import 'folego_repository.dart';

extension FolegoRepositoryNotifications on FolegoRepository {
  Future<NotificationPreferences> getNotificationPreferences(
    String spaceId,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão necessária para carregar notificações.');
    }

    final data = await Supabase.instance.client
        .from('notification_preferences')
        .select('''
          space_id,financial_reminders_enabled,invoices_enabled,debts_enabled,
          recurrences_enabled,subscriptions_enabled,expected_income_enabled,
          overdue_enabled,reminder_offset_days,preferred_time
        ''')
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
        .select('''
          space_id,financial_reminders_enabled,invoices_enabled,debts_enabled,
          recurrences_enabled,subscriptions_enabled,expected_income_enabled,
          overdue_enabled,reminder_offset_days,preferred_time
        ''')
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
}
