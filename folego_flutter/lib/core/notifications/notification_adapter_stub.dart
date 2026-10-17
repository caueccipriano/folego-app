import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

NotificationSchedulerAdapter createNotificationSchedulerAdapter(
  SupabaseClient client,
) => const WebSafeNoopNotificationAdapter();
