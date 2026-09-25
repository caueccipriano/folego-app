import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/subscriptions/subscription_access.dart';
import '../../core/subscriptions/subscription_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';

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
        _error = AppLocalizations.of(context)!.premiumStoreError;
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = SubscriptionService.accessNotifier.value;
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final storeReady = SubscriptionService.isConfigured;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premiumTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              access.hasPremium
                  ? l10n.premiumCompleteTitle
                  : l10n.premiumPitchTitle,
              style: AppTypography.display(context, fontSize: 30),
            ),
            const SizedBox(height: 8),
            Text(
              widget.feature == null
                  ? l10n.premiumDefaultSubtitle
                  : l10n.premiumFeatureSubtitle(widget.feature!),
              style: AppTypography.body(
                context,
                fontSize: 14,
                color: secondary,
              ),
            ),
            const SizedBox(height: 22),
            _Feature(
              icon: Icons.auto_graph_rounded,
              title: l10n.premiumProjectionTitle,
              body: l10n.premiumProjectionBody,
            ),
            _Feature(
              icon: Icons.auto_awesome_rounded,
              title: l10n.premiumAutomationTitle,
              body: l10n.premiumAutomationBody,
            ),
            _Feature(
              icon: Icons.upload_file_rounded,
              title: l10n.premiumImportTitle,
              body: l10n.premiumImportBody,
            ),
            _Feature(
              icon: Icons.download_rounded,
              title: l10n.premiumExportTitle,
              body: l10n.premiumExportBody,
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _accessLabel(access, l10n),
                      style: AppTypography.section(context, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      access.hasPremium
                          ? _activeCopy(access, l10n)
                          : SubscriptionService.isTestStoreBuild
                              ? 'Ambiente de teste · sem cobrança real ou teste grátis de 7 dias'
                              : 'Confira o preço e a disponibilidade do teste grátis no checkout da loja.',
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
                              ? l10n.premiumWait
                              : storeReady
                                  ? l10n.premiumViewOffer
                                  : l10n.premiumStoreOnly,
                        ),
                      )
                    else if (access.kind == SubscriptionAccessKind.premium ||
                        access.kind == SubscriptionAccessKind.trial)
                      FilledButton.tonal(
                        onPressed: storeReady && !_running
                            ? () => _run(_subscriptions.presentCustomerCenter)
                            : null,
                        child: Text(l10n.premiumManage),
                      ),
                    if (storeReady) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _running
                            ? null
                            : () => _run(_subscriptions.restorePurchases),
                        child: Text(l10n.premiumRestore),
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
              l10n.premiumDisclaimer,
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

  String _activeCopy(SubscriptionAccess access, AppLocalizations l10n) {
    final expiresAt = access.expiresAt;
    if (access.kind == SubscriptionAccessKind.lifetime) {
      return l10n.premiumLifetimeActive;
    }
    if (access.kind == SubscriptionAccessKind.complimentary) {
      return expiresAt == null
          ? l10n.premiumComplimentaryActive
          : l10n.premiumComplimentaryUntil(_date(context, expiresAt));
    }
    if (access.kind == SubscriptionAccessKind.trial) {
      return expiresAt == null
          ? l10n.premiumTrialActive
          : l10n.premiumTrialUntil(_date(context, expiresAt));
    }
    return expiresAt == null
        ? l10n.premiumSubscriptionActive
        : l10n.premiumSubscriptionUntil(_date(context, expiresAt));
  }

  String _date(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatShortDate(value);

  String _accessLabel(SubscriptionAccess access, AppLocalizations l10n) =>
      switch (access.kind) {
        SubscriptionAccessKind.free => l10n.premiumFreeLabel,
        SubscriptionAccessKind.trial => l10n.premiumTrialLabel,
        SubscriptionAccessKind.premium => l10n.premiumPaidLabel,
        SubscriptionAccessKind.complimentary => l10n.premiumComplimentaryLabel,
        SubscriptionAccessKind.lifetime => l10n.premiumLifetimeLabel,
      };
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
