import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/folego_repository.dart';
import '../bootstrap/bootstrap_screen.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.client,
    required this.repository,
  });

  final SupabaseClient client;
  final FolegoRepository repository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _subscription;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _session = widget.client.auth.currentSession;
    _subscription = widget.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      setState(() => _session = event.session);
    });
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
    return BootstrapScreen(
      client: widget.client,
      repository: widget.repository,
    );
  }
}
