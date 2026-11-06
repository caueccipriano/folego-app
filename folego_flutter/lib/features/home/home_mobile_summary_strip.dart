import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/models/monthly_money_summary.dart';
import '../../data/models/upcoming_events.dart';

/// Read-only first-glance context from data already loaded by Home.
/// Never computes the available balance or queries the database.
class HomeMobileSummaryStrip extends StatelessWidget {
  const HomeMobileSummaryStrip({
    super.key,
    required this.snapshot,
    required this.monthly,
    required this.upcoming,
    required this.upcomingAvailable,
    required this.hidden,
    required this.showTiles,
    this.compactHome = false,
    required this.onBudget,
    required this.onMonthly,
    required this.onUpcoming,
  });

  final FolegoSnapshot snapshot;
  final MonthlyMoneySummary? monthly;
  final List<UpcomingEvent> upcoming;
  final bool upcomingAvailable;
  final bool hidden;
  final bool showTiles;
  /// First-glance Home: a single budget signal, never a second report.
  /// Full used/planned amounts belong in Planejar and the details sheet.
  final bool compactHome;
  final VoidCallback onBudget;
  final VoidCallback onMonthly;
  final VoidCallback onUpcoming;

  static double? progress(FolegoSnapshot snapshot) {
    final limit = snapshot.monthlyBudgetPlanned.toDouble();
    final used = snapshot.monthlyBudgetUsed.toDouble();
    if (!snapshot.budgetConfigured || !limit.isFinite || limit <= 0 ||
        !used.isFinite || used < 0) {
      return null;
    }
    return (used / limit).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    final surface = tokens.superficie;
    final primary = tokens.textoPrincipal;
    final secondary = tokens.textoSecundario;
    final border = tokens.borda;
    final highContrast = MediaQuery.highContrastOf(context);
    final flow = AppColorSelection.selected.value == 'ink';
    final ratio = progress(snapshot);

    final pending = upcoming
        .where((item) => item.isExpense && item.isPending)
        .toList(growable: false)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final next = pending.isEmpty ? null : pending.first;
    final budgetExceeded = snapshot.budgetConfigured &&
        snapshot.monthlyBudgetPlanned > 0 &&
        snapshot.monthlyBudgetUsed > snapshot.monthlyBudgetPlanned;
    final budgetLabel = ratio == null
        ? 'definir orçamento no plano'
        : hidden
            ? 'valores ocultos'
            : '${(snapshot.monthlyBudgetUsed / snapshot.monthlyBudgetPlanned * 100).round()}% utilizado';
    final nextDate = next == null
        ? null
        : '${next.dueDate.day.toString().padLeft(2, '0')}/${next.dueDate.month.toString().padLeft(2, '0')}';

    Widget mini({
      required String keyName,
      required String label,
      required String amount,
      required String description,
      required VoidCallback onTap,
      required IconData icon,
    }) => Expanded(
      child: Material(
        color: surface,
        elevation: highContrast || flow ? 0 : 1.4,
        shadowColor: tokens.marca.withValues(alpha: .10),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          key: ValueKey(keyName),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 12, 11),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.marca.withValues(alpha: .085),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 17, color: tokens.marca),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(context, fontSize: 12,
                        fontWeight: FontWeight.w600, color: secondary))),
                ]),
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amount, maxLines: 1,
                      key: ValueKey('$keyName-amount'),
                      style: AppTypography.money(context, fontSize: 19,
                        color: primary),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(description, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(context, fontSize: 11,
                    color: secondary)),
              ],
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      key: const ValueKey('home-mobile-financial-context'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: surface,
          elevation: highContrast || flow || compactHome ? 0 : 1.2,
          shadowColor: tokens.marca.withValues(alpha: .09),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            key: const ValueKey('home-mobile-budget'),
            onTap: onBudget,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: compactHome
                  ? const EdgeInsets.fromLTRB(15, 14, 15, 14)
                  : const EdgeInsets.fromLTRB(13, 11, 13, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tokens.marca.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.donut_small_outlined, size: 17,
                          color: tokens.marca),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text('orçamento do mês',
                      style: AppTypography.cardTitle(context, fontSize: 13,
                        color: primary))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: budgetExceeded
                            ? Theme.of(context).colorScheme.error
                                .withValues(alpha: .085)
                            : tokens.marca.withValues(alpha: .065),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        budgetLabel,
                        key: const ValueKey('home-mobile-budget-value'),
                        style: AppTypography.label(context, fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: budgetExceeded
                              ? Theme.of(context).colorScheme.error
                              : secondary),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.chevron_right_rounded, size: 16, color: secondary),
                  ]),
                  if (ratio == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Defina seus limites no Planejar para acompanhar seu mês.',
                      key: const ValueKey('home-budget-setup-hint'),
                      style: AppTypography.body(context,
                          fontSize: 11, color: secondary),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    if (!compactHome) Row(
                      children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('utilizado',
                                style: AppTypography.label(context,
                                    fontSize: 11, color: secondary)),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                hidden
                                    ? FinancialPrivacy.maskMoney()
                                    : Formatters.money(snapshot.monthlyBudgetUsed),
                                key: const ValueKey('home-flow-used-budget'),
                                style: AppTypography.money(context,
                                    fontSize: 16, color: primary),
                              ),
                            ),
                          ],
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('planejado',
                                style: AppTypography.label(context,
                                    fontSize: 11, color: secondary)),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                hidden
                                    ? FinancialPrivacy.maskMoney()
                                    : Formatters.money(snapshot.monthlyBudgetPlanned),
                                key: const ValueKey('home-flow-planned-budget'),
                                style: AppTypography.money(context,
                                    fontSize: 16, color: primary),
                              ),
                            ),
                          ],
                        )),
                      ],
                    ),
                  ],
                  if (ratio != null && !hidden) ...[
                    SizedBox(height: compactHome ? 12 : 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        key: const ValueKey('home-mobile-budget-progress'),
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: tokens.marca.withValues(alpha: .10),
                        color: budgetExceeded
                            ? Theme.of(context).colorScheme.error
                            : tokens.marca,
                      ),
                    ),
                    if (!budgetExceeded && showTiles) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                            size: 15, color: tokens.marca),
                          const SizedBox(width: 5),
                          Expanded(child: Text(
                            'resta no orçamento',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label(context,
                              fontSize: 11, color: secondary),
                          )),
                          const SizedBox(width: 8),
                          Flexible(child: Text(
                            Formatters.money(snapshot.monthlyBudgetPlanned -
                                snapshot.monthlyBudgetUsed),
                            key: const ValueKey('home-budget-remaining'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.money(context,
                              fontSize: 12, color: primary),
                          )),
                        ],
                      ),
                    ],
                    // Only roomy iPhones show the additional amount; the
                    // compact Home must never overflow or reveal hidden data.
                    if (budgetExceeded && showTiles) ...[
                      const SizedBox(height: 6),
                      Text(
                        'limite excedido em ${Formatters.money(snapshot.monthlyBudgetUsed - snapshot.monthlyBudgetPlanned)}',
                        key: const ValueKey('home-budget-excess-amount'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(
                          context,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                  if (compactHome && ratio != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      budgetExceeded
                          ? 'limite ultrapassado · toque para ver seu plano'
                          : 'veja os detalhes no Planejar',
                      style: AppTypography.label(context,
                        fontSize: 11, color: secondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showTiles) ...[
          const SizedBox(height: 8),
          Row(children: [
            mini(
              keyName: 'home-mobile-monthly-spending',
              label: 'gastos do mês',
              icon: Icons.bar_chart_rounded,
              amount: monthly == null
                  ? 'indisponível'
                  : hidden
                      ? FinancialPrivacy.maskMoney()
                      : Formatters.money(monthly!.spendingNet),
              description: monthly == null
                  ? 'ver meu mês'
                  : 'pela data da compra',
              onTap: onMonthly,
            ),
            const SizedBox(width: 8),
            mini(
              keyName: 'home-mobile-next-bill',
              label: 'próxima conta',
              icon: Icons.event_outlined,
              amount: !upcomingAvailable
                  ? 'indisponível'
                  : next == null
                      ? 'sem pendências'
                      : hidden
                          ? FinancialPrivacy.maskMoney()
                          : Formatters.money(next.amount),
              description: !upcomingAvailable
                  ? 'tente novamente'
                  : next == null
                      ? 'ver agenda'
                      : hidden
                          ? 'ver agenda'
                          : '${next.name} · ${nextDate ?? ''}',
              onTap: onUpcoming,
            ),
          ]),
        ],
      ],
    );
  }
}
