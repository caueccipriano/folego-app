import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/entitlements/feature_entitlements.dart';
import 'core/layout/app_scroll_gutter.dart';
import 'core/subscriptions/subscription_access.dart';
import 'core/subscriptions/subscription_service.dart';
import 'core/preferences/app_preferences.dart';
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
    return ValueListenableBuilder<SubscriptionAccess>(
      valueListenable: SubscriptionService.accessNotifier,
      builder: (context, access, _) => FeatureEntitlementsScope(
        provider: SubscriptionEntitlementProvider(access),
        child: ValueListenableBuilder<ThemeMode>(
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
              scrollBehavior: const AppScrollBehavior(),
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              // EN/ES remain in the translation workspace, but are not exposed
              // until every user-facing surface is migrated out of hardcoded PT.
              supportedLocales: productionSupportedLocales,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              home: AuthGate(client: client, repository: repository),
            );
          },
        );
      },
        ),
      ),
    );
  }
}
