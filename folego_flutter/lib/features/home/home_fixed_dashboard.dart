import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/folego_snapshot.dart';
import 'home_financial_hero.dart';
import 'home_pulse_insight.dart';

/// Mobile Home: one viewport, with details in an independent sheet.
class HomeFixedDashboard extends StatelessWidget {
  const HomeFixedDashboard({
    super.key, required this.name, required this.snapshot,
    required this.insight, required this.notificationBell,
    required this.hidden, required this.onPrivacy,
    required this.onAgenda, required this.onExpense,
    required this.onIncome, required this.onSearch,
    required this.onResolve, required this.onAttention,
    required this.onDetails,
  });
  final String name;
  final FolegoSnapshot snapshot;
  final HomePulseInsight insight;
  final Widget notificationBell;
  final bool hidden;
  final VoidCallback onPrivacy;
  final VoidCallback onAgenda;
  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback onSearch;
  final VoidCallback onResolve;
  final VoidCallback onAttention;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final colors = FolegoColorTokens.of(context);
    return ColoredBox(
      color: AppColors.background(brightness),
      child: SafeArea(
        child: LayoutBuilder(builder: (context, limits) {
          final short = limits.maxHeight < 515;
          final tiny = limits.maxHeight < 425;
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final timing = homeIncomeTimingLabel(snapshot);
          return Padding(
            padding: EdgeInsets.fromLTRB(16, tiny ? 4 : 10, 16, 10),
            child: Column(
              key: const ValueKey('home-fixed-viewport'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 46, child: Row(children: [
                  Expanded(child: Text('e aí, ${name.toLowerCase()}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(context,
                      fontSize: 21, color: scheme.onSurface))),
                  notificationBell,
                  IconButton(key: const ValueKey('home-agenda-shortcut'),
                    onPressed: onAgenda, tooltip: 'agenda',
                    icon: const Icon(AppIcons.calendar, size: 19)),
                  IconButton(key: const ValueKey('home-privacy-toggle'),
                    onPressed: onPrivacy,
                    tooltip: hidden ? 'mostrar valores' : 'ocultar valores',
                    icon: Icon(hidden ? AppIcons.eyeOff : AppIcons.eye, size: 19)),
                ])),
                SizedBox(height: tiny ? 6 : 12),
                Semantics(
                  label: hidden ? 'valor disponível oculto' :
                    'quanto posso gastar até receber',
                  button: true,
                  child: Material(
                    color: colors.marcaHero,
                    borderRadius: BorderRadius.circular(AppRadii.feature),
                    child: InkWell(
                      key: const ValueKey('home-fixed-spendable-tap'),
                      onTap: onDetails,
                      borderRadius: BorderRadius.circular(AppRadii.feature),
                      child: Padding(
                        key: const ValueKey('home-spendable-pool'),
                        padding: EdgeInsets.fromLTRB(17, tiny ? 10 : 16,
                          17, tiny ? 10 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              Expanded(child: Text('quanto posso gastar?',
                                style: AppTypography.body(context,
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: colors.marcaHeroSobre))),
                              Icon(Icons.arrow_outward_rounded, size: 17,
                                color: colors.marcaHeroSobre),
                            ]),
                            const SizedBox(height: 5),
                            FittedBox(fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(hidden ? FinancialPrivacy.maskMoney() :
                                Formatters.money(snapshot.spendablePool),
                                key: const ValueKey('home-fixed-spendable'),
                                style: AppTypography.money(context,
                                  fontSize: tiny ? 36 : 42,
                                  color: colors.acaoHero))),
                            const SizedBox(height: 4),
                            Text(hidden ? 'toque para entender' :
                                (timing ?? 'até o próximo recebimento'),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(context,
                                fontSize: 12, color: colors.marcaHeroSobre)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tiny ? 8 : 12),
                Row(children: [
                  Expanded(child: _CaptureButton(label: 'gasto',
                    icon: AppIcons.expense, onTap: onExpense, primary: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _CaptureButton(label: 'receita',
                    icon: AppIcons.income, onTap: onIncome, primary: false)),
                ]),
                if (insight.showCard && !tiny && !largeText) ...[
                  const SizedBox(height: 10),
                  Material(
                    key: const ValueKey('home-fixed-one-insight'),
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      leading: Icon(insight.requiresAttention ?
                        Icons.error_outline_rounded : Icons.lightbulb_outline_rounded,
                        size: 19, color: scheme.primary),
                      title: Text(insight.title, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(context,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        homePulseShortDetail(insight, hidden: hidden),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: insight.action == HomePulseAction.none
                          ? null
                          : const Icon(Icons.chevron_right_rounded, size: 17),
                      onTap: insight.action == HomePulseAction.none
                          ? null
                          : onAttention,
                    ),
                  ),
                ],
                const Spacer(),
                if (!short && !largeText) ...[
                  Row(children: [
                    Expanded(child: TextButton.icon(
                      key: const ValueKey('home-global-search'),
                      onPressed: onSearch,
                      icon: const Icon(AppIcons.search, size: 18),
                      label: const Text('buscar'))),
                    Expanded(child: TextButton.icon(
                      key: const ValueKey('home-pending-center'),
                      onPressed: onResolve,
                      icon: const Icon(AppIcons.transactions, size: 18),
                      label: const Text('resolver'))),
                  ]),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  key: const ValueKey('home-open-full-details'),
                  onPressed: onDetails,
                  icon: const Icon(Icons.dashboard_outlined, size: 18),
                  label: const Text('ver meu mês e análises'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: scheme.onSurface,
                    side: BorderSide(color: scheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.label, required this.icon,
    required this.onTap, required this.primary});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fg = primary ? AppColors.onAction(brightness) :
      AppColors.positiveText(brightness);
    return Material(
      color: primary ? AppColors.action(brightness) : AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(AppRadii.compactCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: primary ? AppColors.transparent :
              AppColors.border(brightness)),
            borderRadius: BorderRadius.circular(AppRadii.compactCard)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(label, style: AppTypography.body(context, fontSize: 14,
                fontWeight: FontWeight.w700, color: fg)),
            ]),
        ),
      ),
    );
  }
}
