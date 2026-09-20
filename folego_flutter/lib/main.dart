import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/preferences/app_preferences.dart';
import 'core/privacy/financial_privacy.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/folego_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppThemeController.setSystem();
  await AppPreferences.initialize();
  await FinancialPrivacy.initialize();
  await initializeDateFormatting('pt_BR');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final client = Supabase.instance.client;
  runApp(FolegoApp(client: client, repository: FolegoRepository(client)));
}
