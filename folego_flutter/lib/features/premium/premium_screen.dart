import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/subscriptions/subscription_access.dart';
import '../../core/subscriptions/subscription_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

Future<bool> openPremiumUpgrade(
  BuildContext context, {
  required String feature,
}) async {
  if (SubscriptionService.accessNotifier.value.hasPremium) return true;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => PremiumScreen(feature: feature)),
  );
  return SubscriptionService.accessNotifier.value.hasPremium;
}

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, this.feature});

  final String? feature;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late final SubscriptionService _subscriptions;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscriptions = SubscriptionService(Supabase.instance.client);
    SubscriptionService.accessNotifier.addListener(_changed);
    _refresh();
  }

  @override
  void dispose() {
    SubscriptionService.accessNotifier.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    try {
      await _subscriptions.refreshAccess();
    } catch (_) {}
  }

  Future<void> _run(Future<SubscriptionAccess> Function() action) async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = SubscriptionService.accessNotifier.value;
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final storeReady = SubscriptionService.isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('Fôlego Premium')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              access.hasPremium
                  ? 'seu Fôlego está completo'
                  : 'mais visão. menos trabalho manual.',
              style: AppTypography.display(context, fontSize: 30),
            ),
            const SizedBox(height: 8),
            Text(
              widget.feature == null
                  ? 'desbloqueie recursos avançados para planejar e automatizar.'
                  : '${widget.feature} faz parte do Fôlego Premium.',
              style: AppTypography.body(
                context,
                fontSize: 14,
                color: secondary,
              ),
            ),
            const SizedBox(height: 22),
            const _Feature(
              icon: Icons.auto_graph_rounded,
              title: 'projeções futuras',
              body: 'antecipe cenários e veja o impacto das próximas decisões.',
            ),
            const _Feature(
              icon: Icons.auto_awesome_rounded,
              title: 'automações',
              body: 'reduza classificações repetitivas e trabalho manual.',
            ),
            const _Feature(
              icon: Icons.upload_file_rounded,
              title: 'importação CSV e OFX',
              body: 'traga extratos para revisão sem digitar tudo de novo.',
            ),
            const _Feature(
              icon: Icons.download_rounded,
              title: 'exportação de dados',
              body: 'leve uma cópia em CSV sempre que quiser.',
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      access.label,
                      style: AppTypography.section(context, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      access.hasPremium
                          ? _activeCopy(access)
                          : '${SubscriptionService.trialLabel} · depois ${SubscriptionService.monthlyPriceLabel}',
                      style: AppTypography.body(
                        context,
                        fontSize: 13,
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!access.hasPremium)
                      FilledButton(
                        onPressed: storeReady && !_running
                            ? () => _run(_subscriptions.presentPremiumPaywall)
                            : null,
                        child: Text(
                          _running
                              ? 'aguarde…'
                              : storeReady
                                  ? 'começar 7 dias grátis'
                                  : 'assinatura disponível na versão da loja',
                        ),
                      )
                    else if (access.kind == SubscriptionAccessKind.premium ||
                        access.kind == SubscriptionAccessKind.trial)
                      FilledButton.tonal(
                        onPressed: storeReady && !_running
                            ? () => _run(_subscriptions.presentCustomerCenter)
                            : null,
                        child: const Text('gerenciar assinatura'),
                      ),
                    if (storeReady) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _running
                            ? null
                            : () => _run(_subscriptions.restorePurchases),
                        child: const Text('restaurar compras'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cancele quando quiser pela loja. O teste e a cobrança só começam após sua confirmação no checkout.',
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _activeCopy(SubscriptionAccess access) {
    final expiresAt = access.expiresAt;
    if (access.kind == SubscriptionAccessKind.lifetime) {
      return 'acesso vitalício ativo';
    }
    if (access.kind == SubscriptionAccessKind.complimentary) {
      return expiresAt == null
          ? 'cortesia ativa'
          : 'cortesia ativa até ${_date(expiresAt)}';
    }
    if (access.kind == SubscriptionAccessKind.trial) {
      return expiresAt == null
          ? 'seu teste grátis está ativo'
          : 'teste grátis ativo até ${_date(expiresAt)}';
    }
    return expiresAt == null
        ? 'assinatura ativa'
        : 'assinatura ativa até ${_date(expiresAt)}';
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primaryPurple(brightness).withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                icon,
                size: 20,
                color: AppColors.primaryPurple(brightness),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.section(context, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    color: AppColors.secondaryText(brightness),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
