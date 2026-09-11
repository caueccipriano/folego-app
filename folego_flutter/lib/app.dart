import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/folego_repository.dart';
import 'features/auth/auth_gate.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';

class FolegoApp extends StatelessWidget {
  const FolegoApp({super.key, required this.client, required this.repository});

  final SupabaseClient client;
  final FolegoRepository repository;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: LocaleController.locale,
          builder: (context, locale, _) {
            return MaterialApp(
              onGenerateTitle: (context) {
                return AppLocalizations.of(context)!.appName;
              },

              debugShowCheckedModeBanner: false,

              locale: locale,

              localizationsDelegates: AppLocalizations.localizationsDelegates,

              supportedLocales: AppLocalizations.supportedLocales,

              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,

              home: AuthGate(client: client, repository: repository),
            );
          },
        );
      },
    );
  }
}
