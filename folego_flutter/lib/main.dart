import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  // Typography ships with the app; never swap to a network-loaded font later.
  GoogleFonts.config.allowRuntimeFetching = false;
  await GoogleFonts.pendingFonts([
    for (final weight in [
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ])
      GoogleFonts.manrope(fontWeight: weight),
    GoogleFonts.unbounded(fontWeight: FontWeight.w700),
  ]);
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Manrope', 'Unbounded']) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
    }
  });
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
