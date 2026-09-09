import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 44),
                const SizedBox(height: 12),
                const Text('Não conseguimos abrir suas finanças.'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
                TextButton(
                  onPressed: widget.client.auth.signOut,
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_space == null || _state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_state!.onboardingCompleted) {
      return OnboardingScreen(
        space: _space!,
        repository: widget.repository,
        initialState: _state!,
        onCompleted: _load,
      );
    }

    return HomeShell(space: _space!, repository: widget.repository);
  }
}
