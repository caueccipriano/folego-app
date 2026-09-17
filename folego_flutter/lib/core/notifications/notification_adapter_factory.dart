import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_adapter_stub.dart'
    if (dart.library.html) 'notification_adapter_web.dart' as platform;
import 'notification_service.dart';

NotificationSchedulerAdapter createNotificationSchedulerAdapter(
  SupabaseClient client,
) => platform.createNotificationSchedulerAdapter(client);
