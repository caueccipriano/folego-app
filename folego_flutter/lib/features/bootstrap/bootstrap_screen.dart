import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/preferences/app_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/onboarding_state.dart';
import '../../data/repositories/folego_repository.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/home_shell.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({
    super.key,
    required this.client,
    required this.repository,
  });

  final SupabaseClient client;
  final FolegoRepository repository;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  FinancialSpace? _space;
  OnboardingState? _state;
  Object? _error;
  late bool _introSeen;

  @override
  void initState() {
    super.initState();
    _introSeen = AppPreferences.firstRunIntroSeen.value;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final space = await widget.repository.getPrimarySpace();
      final state = await widget.repository.getOnboardingState(space.id);
      if (!mounted) return;
      setState(() {
        _space = space;
        _state = state;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _completeIntro() async {
    await AppPreferences.markFirstRunIntroSeen();
    if (!mounted) return;
    setState(() => _introSeen = true);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.warning,
                  size: 42,
                  color: AppColors.primaryPurple(brightness),
                ),
                const SizedBox(height: 14),
                Text(
                  'não deu pra abrir suas finanças agora',
                  textAlign: TextAlign.center,
                  style: AppTypography.section(context, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'confira sua conexão e tenta de novo em alguns segundos.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    context,
                    color: AppColors.secondaryText(brightness),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(AppIcons.refresh),
                  label: const Text('tentar de novo'),
                ),
                TextButton.icon(
                  onPressed: widget.client.auth.signOut,
                  icon: const Icon(AppIcons.logout),
                  label: const Text('sair'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_space == null || _state == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Fôlego',
                style: AppTypography.section(context, fontSize: 22),
              ),
              const SizedBox(height: 14),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
    }

    if (!_state!.onboardingCompleted && !_introSeen) {
      return OnboardingScreen(
        onCompleted: _completeIntro,
        onSignOut: widget.client.auth.signOut,
      );
    }

    return HomeShell(space: _space!, repository: widget.repository);
  }
}
