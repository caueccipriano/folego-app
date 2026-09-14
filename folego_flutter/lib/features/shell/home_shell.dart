import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import '../../shared/widgets/liquid_glass_navigation_bar.dart';
import '../home/home_screen.dart';
import '../plan/plan_screen.dart';
import '../profile/profile_screen.dart';
import '../transactions/transactions_screen.dart';
import '../wallet/wallet_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.space, required this.repository});

  final FinancialSpace space;
  final FolegoRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(space: widget.space, repository: widget.repository),
      TransactionsScreen(repository: widget.repository),
      PlanScreen(repository: widget.repository, spaceId: widget.space.id),
      WalletScreen(repository: widget.repository, spaceId: widget.space.id),
      ProfileScreen(
        client: Supabase.instance.client,
        repository: widget.repository,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: LiquidGlassNavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
      ),
    );
  }
}
