import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/folego_repository.dart';
import '../bootstrap/bootstrap_screen.dart';
import 'auth_screen.dart';
import 'password_recovery_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.client, required this.repository});

  final SupabaseClient client;
  final FolegoRepository repository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _subscription;
  Session? _session;
  bool _passwordRecovery = false;

  @override
  void initState() {
    super.initState();
    _session = widget.client.auth.currentSession;
    _subscription = widget.client.auth.onAuthStateChange.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _session = event.session;
          if (event.event == AuthChangeEvent.passwordRecovery) {
            _passwordRecovery = true;
          } else if (event.event == AuthChangeEvent.signedOut) {
            _passwordRecovery = false;
          }
        });
      },
      onError: (Object error, StackTrace _) {
        if (kDebugMode) {
          debugPrint('Auth state listener failed (${error.runtimeType})');
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return AuthScreen(client: widget.client);
    }
    if (_passwordRecovery) {
      return PasswordRecoveryScreen(client: widget.client);
    }
    return BootstrapScreen(
      client: widget.client,
      repository: widget.repository,
    );
  }
}
