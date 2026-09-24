import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/subscriptions/subscription_access.dart';
import '../../core/subscriptions/subscription_service.dart';
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
  SubscriptionAccess _access =
      const SubscriptionAccess(kind: SubscriptionAccessKind.free);
  late final SubscriptionService _subscriptions;

  @override
  void initState() {
    super.initState();
    _subscriptions = SubscriptionService(widget.client);
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final values = await Future.wait([
        widget.repository.getProfileName(),
        widget.repository.listBudgetItems(
          spaceId: widget.space.id,
          periodMonth: DateTime(now.year, now.month),
        ),
        _subscriptions.getAccess(),
      ]);

      if (!mounted) return;

      final items = values[1] as List;
      setState(() {
        _name = values[0] as String;
        _plannedCount = items.length;
        _plannedTotal = items.fold<num>(
          0,
          (total, item) => total + (item.plannedAmount as num),
        );
        _access = values[2] as SubscriptionAccess;
      });
    } catch (_) {}
  }

  Future<void> _openPremium() async {
    try {
      await _subscriptions.presentPremiumPaywall();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _restorePurchases() async {
    try {
      final access = await _subscriptions.restorePurchases();
      if (!mounted) return;
      setState(() => _access = access);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compras restauradas.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _manageSubscription() async {
    try {
      await _subscriptions.presentCustomerCenter();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.client.auth.currentUser?.email ?? '';
    final paidStoreAccess =
        _access.kind == SubscriptionAccessKind.premium ||
        _access.kind == SubscriptionAccessKind.trial;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _access.hasPremium
                              ? Icons.workspace_premium_rounded
                              : Icons.auto_awesome_rounded,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _access.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _premiumSubtitle(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_access.hasPremium) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openPremium,
                        icon: const Icon(Icons.workspace_premium_rounded),
                        label: const Text('Começar 7 dias grátis'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Depois, R\$ 9,90/mês. Cancele quando quiser pela Google Play.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else if (paidStoreAccess) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _manageSubscription,
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text('Gerenciar assinatura'),
                      ),
                    ),
                  ],
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
                    leading: const Icon(Icons.restore_rounded),
                    title: const Text('Restaurar compras'),
                    onTap: _restorePurchases,
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

  String _premiumSubtitle() {
    switch (_access.kind) {
      case SubscriptionAccessKind.free:
        return 'Desbloqueie projeções, insights e recursos avançados.';
      case SubscriptionAccessKind.trial:
        return _access.expiresAt == null
            ? 'Seu teste Premium está ativo.'
            : 'Teste ativo até ${Formatters.shortDate.format(_access.expiresAt!)}.';
      case SubscriptionAccessKind.premium:
        return _access.expiresAt == null
            ? 'Sua assinatura Premium está ativa.'
            : 'Acesso ativo até ${Formatters.shortDate.format(_access.expiresAt!)}.';
      case SubscriptionAccessKind.complimentary:
        return _access.expiresAt == null
            ? 'Acesso Premium liberado por cortesia.'
            : 'Cortesia ativa até ${Formatters.shortDate.format(_access.expiresAt!)}.';
      case SubscriptionAccessKind.lifetime:
        return 'Acesso Premium vitalício.';
    }
  }
}
