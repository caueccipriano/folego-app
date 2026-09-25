import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/preferences/app_preferences.dart';
import 'core/privacy/financial_privacy.dart';
import 'core/security/secure_session_storage.dart';
import 'core/subscriptions/subscription_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/folego_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppThemeController.setSystem();
  await AppPreferences.initialize();
  await FinancialPrivacy.initialize();
  await initializeDateFormatting('pt_BR');
  // Preserve existing web session storage so PWA users are not signed out
  // by a store-only security migration. Native sessions use secure storage.
  if (kIsWeb) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } else {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(),
      ),
    );
  }

  final client = Supabase.instance.client;
  await SubscriptionService.initialize(client);
  await SubscriptionService(client).refreshAccess();
  runApp(FolegoApp(client: client, repository: FolegoRepository(client)));
}
