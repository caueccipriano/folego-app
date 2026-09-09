import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/folego_repository.dart';
import 'features/auth/auth_gate.dart';

class FolegoApp extends StatelessWidget {
  const FolegoApp({
    super.key,
    required this.client,
    required this.repository,
  });

  final SupabaseClient client;
  final FolegoRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fôlego',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AuthGate(client: client, repository: repository),
    );
  }
}
