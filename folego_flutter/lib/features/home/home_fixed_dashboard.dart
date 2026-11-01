import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/folego_glass_surface.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/folego_snapshot.dart';
import 'home_financial_hero.dart';
import 'home_pulse_insight.dart';

/// A home cabe no viewport principal. Indicadores completos ficam no painel
/// de detalhes, sem transformar o início em um feed de cards.
class HomeFixedDashboard extends StatelessWidget {
  const HomeFixedDashboard({
    super.key,
    required this.name,
    required this.snapshot,
    required this.insight,
    required this.notificationBell,
    required this.hidden,
    required this.onPrivacy,
    required this.onAgenda,
    required this.onExpense,
    required this.onIncome,
    required this.onSearch,
    required this.onResolve,
    required this.onAttention,
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
    final colors = FolegoColorTokens.of(context);
    final timing = homeIncomeTimingLabel(snapshot);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final budgetRatio = snapshot.monthlyBudgetPlanned > 0
        ? (snapshot.monthlyBudgetUsed / snapshot.monthlyBudgetPlanned)
            .clamp(0.0, 1.0).toDouble()
        : 0.0;

    return ColoredBox(
      color: AppColors.background(brightness),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, limits) {
            final short = limits.maxHeight < 640;
            final tiny = limits.maxHeight < 530;
            final largeText = textScale > 1.3;
            final tight = short || largeText;
            final space = tiny ? 7.0 : 10.0;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, tiny ? 4 : 10, 16, 10),
              child: Column(
                key: const ValueKey('home-fixed-viewport'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 49,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'fôlego.',
                                maxLines: 1,
                                style: AppTypography.display(
                                  context,
                                  fontSize: 21,
                                  color: colors.textoPrincipal,
                                ),
                              ),
                              Text(
                                'olá, ' + name.toLowerCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label(
                                  context,
                                  fontSize: 11,
                                  color: colors.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                        notificationBell,
                        IconButton(
                          key: const ValueKey('home-agenda-shortcut'),
                          onPressed: onAgenda,
                          tooltip: 'agenda',
                          icon: const Icon(AppIcons.calendar, size: 20),
                        ),
                        IconButton(
                          key: const ValueKey('home-privacy-toggle'),
                          onPressed: onPrivacy,
                          tooltip: hidden ? 'mostrar valores' : 'ocultar valores',
                          icon: Icon(
                            hidden ? AppIcons.eyeOff : AppIcons.eye,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: space),
                  Semantics(
                    label: hidden
                        ? 'valores financeiros ocultos'
                        : 'fôlego por dia e saldo até o próximo recebimento',
                    button: true,
                    child: Material(
                      color: colors.marcaHero,
                      borderRadius: BorderRadius.circular(AppRadii.feature),
                      child: InkWell(
                        key: const ValueKey('home-fixed-spendable-tap'),
                        onTap: onDetails,
                        borderRadius: BorderRadius.circular(AppRadii.feature),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.feature),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -36,
                                top: -65,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 176,
                                    height: 176,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colors.marcaHeroSobre
                                            .withValues(alpha: .13),
                                        width: 28,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: tiny ? 12 : (tight ? 14 : 17),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'seu fôlego por dia',
                                            style: AppTypography.body(
                                              context,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: colors.marcaHeroSobre,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_outward_rounded,
                                          color: colors.marcaHeroSobre,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              hidden
                                                  ? FinancialPrivacy.maskMoney()
                                                  : snapshot.dailyFolego == null
                                                      ? '—'
                                                      : Formatters.money(
                                                          snapshot.dailyFolego,
                                                        ),
                                              key: const ValueKey(
                                                'home-fixed-daily-folego',
                                              ),
                                              style: AppTypography.money(
                                                context,
                                                fontSize: tiny ? 32 : 39,
                                                color: colors.acaoHero,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            '/ dia',
                                            style: AppTypography.label(
                                              context,
                                              fontSize: 12,
                                              color: colors.marcaHeroSobre,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: tiny ? 8 : 12),
                                    Container(
                                      height: 1,
                                      color: colors.marcaHeroSobre
                                          .withValues(alpha: .18),
                                    ),
                                    SizedBox(height: tiny ? 8 : 11),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'disponível até receber',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.label(
                                              context,
                                              fontSize: 12,
                                              color: colors.marcaHeroSobre,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              hidden
                                                  ? FinancialPrivacy.maskMoney()
                                                  : Formatters.money(snapshot.spendablePool),
                                              key: const ValueKey('home-fixed-spendable'),
                                              style: AppTypography.money(
                                                context,
                                                fontSize: 18,
                                                color: colors.acaoHero,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      hidden
                                          ? 'toque para entender os valores'
                                          : timing ?? 'configure seu recebimento',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.label(
                                        context,
                                        fontSize: 11,
                                        color: colors.marcaHeroSobre,
                                      ),
                                    ),
                                    if (!tiny && !largeText) ...[
                                      const SizedBox(height: 11),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                          value: budgetRatio,
                                          minHeight: 4,
                                          backgroundColor: colors
                                              .marcaHeroSobre.withValues(
                                            alpha: .18,
                                          ),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            colors.acaoHero,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        snapshot.budgetConfigured
                                            ? 'orçamento do mês: ' +
                                                (budgetRatio * 100).round()
                                                    .toString() +
                                                '% utilizado'
                                            : 'seu planejamento cresce com você',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.label(
                                          context,
                                          fontSize: 10,
                                          color: colors.marcaHeroSobre,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: space),
                  Row(
                    children: [
                      Expanded(
                        child: _CaptureButton(
                          label: 'registrar gasto',
                          icon: AppIcons.expense,
                          onTap: onExpense,
                          primary: true,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _CaptureButton(
                          label: 'receita',
                          icon: AppIcons.income,
                          onTap: onIncome,
                          primary: false,
                        ),
                      ),
                    ],
                  ),
                  if (!tiny && !largeText) ...[
                    SizedBox(height: space),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'em contas',
                            value: hidden
                                ? FinancialPrivacy.maskMoney()
                                : Formatters.money(snapshot.liquidBalance),
                            icon: AppIcons.wallet,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _MetricTile(
                            label: 'comprometido',
                            value: hidden
                                ? FinancialPrivacy.maskMoney()
                                : Formatters.money(
                                    snapshot.mandatoryOutflowsUntilIncome,
                                  ),
                            icon: AppIcons.calendar,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (insight.showCard && !short && !largeText) ...[
                    const SizedBox(height: 10),
                    FolegoGlassSurface(
                      radius: 18,
                      prominent: false,
                      elevated: false,
                      child: ListTile(
                        key: const ValueKey('home-fixed-one-insight'),
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -3),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        leading: Icon(
                          insight.requiresAttention
                              ? Icons.error_outline_rounded
                              : Icons.auto_awesome_outlined,
                          size: 19,
                          color: colors.marca,
                        ),
                        title: Text(
                          insight.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle(
                            context,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          homePulseShortDetail(insight, hidden: hidden),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(
                            context,
                            fontSize: 11,
                            color: colors.textoSecundario,
                          ),
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
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            key: const ValueKey('home-global-search'),
                            onPressed: onSearch,
                            icon: const Icon(AppIcons.search, size: 18),
                            label: const Text('buscar'),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            key: const ValueKey('home-pending-center'),
                            onPressed: onResolve,
                            icon: const Icon(
                              AppIcons.transactions,
                              size: 18,
                            ),
                            label: const Text('resolver'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  OutlinedButton.icon(
                    key: const ValueKey('home-open-full-details'),
                    onPressed: onDetails,
                    icon: const Icon(Icons.space_dashboard_outlined, size: 18),
                    label: const Text('ver meu mês e análises'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      foregroundColor: colors.textoPrincipal,
                      side: BorderSide(color: colors.borda),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = FolegoColorTokens.of(context);
    return FolegoGlassSurface(
      radius: 18,
      prominent: false,
      elevated: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: colors.marca),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(
                    context,
                    fontSize: 11,
                    color: colors.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.money(
                context,
                fontSize: 17,
                color: colors.textoPrincipal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final foreground = primary
        ? AppColors.onAction(brightness)
        : AppColors.positiveText(brightness);
    final action = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.compactCard),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTypography.body(
                    context,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return primary
        ? Material(
            color: AppColors.action(brightness),
            borderRadius: BorderRadius.circular(AppRadii.compactCard),
            child: action,
          )
        : FolegoGlassSurface(
            radius: AppRadii.compactCard,
            prominent: true,
            elevated: false,
            child: action,
          );
  }
}
