import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import '../../shared/widgets/section_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.client,
    required this.repository,
    required this.space,
  });

  final SupabaseClient client;
  final FolegoRepository repository;
  final FinancialSpace space;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Você';
  num _plannedTotal = 0;
  int _plannedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final name = await widget.repository.getProfileName();
      final now = DateTime.now();
      final items = await widget.repository.listBudgetItems(
        spaceId: widget.space.id,
        periodMonth: DateTime(now.year, now.month),
      );
      if (!mounted) return;
      setState(() {
        _name = name;
        _plannedCount = items.length;
        _plannedTotal = items.fold<num>(
          0,
          (total, item) => total + item.plannedAmount,
        );
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.client.auth.currentUser?.email ?? '';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            Text(
              'Perfil',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            SectionCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      _name.isEmpty ? '?' : _name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Planejamento mensal',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$_plannedCount categorias planejadas',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.money(_plannedTotal),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.notifications_none_rounded),
                    title: Text('Notificações'),
                    subtitle: Text('Entrará na próxima versão'),
                  ),
                  const Divider(),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.lock_outline_rounded),
                    title: Text('Privacidade e segurança'),
                    subtitle: Text('Dados protegidos por autenticação e RLS'),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Sair'),
                    onTap: () => widget.client.auth.signOut(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
