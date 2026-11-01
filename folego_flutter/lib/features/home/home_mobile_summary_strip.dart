import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
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
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final ratio = progress(snapshot);

    final pending = upcoming
        .where((item) => item.isExpense && item.isPending)
        .toList(growable: false)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final next = pending.isEmpty ? null : pending.first;
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey(keyName),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 17, color: secondary),
                  const SizedBox(width: 5),
                  Expanded(child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(context, fontSize: 12,
                        fontWeight: FontWeight.w600, color: secondary))),
                ]),
                const SizedBox(height: 7),
                Text(amount, maxLines: 1, overflow: TextOverflow.ellipsis,
                  key: ValueKey('$keyName-amount'),
                  style: AppTypography.money(context, fontSize: 17,
                    color: primary)),
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
    );

    return Column(
      key: const ValueKey('home-mobile-financial-context'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const ValueKey('home-mobile-budget'),
            onTap: onBudget,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.donut_small_outlined, size: 17, color: secondary),
                    const SizedBox(width: 7),
                    Expanded(child: Text('orçamento flexível',
                      style: AppTypography.cardTitle(context, fontSize: 13,
                        color: primary))),
                    Text(budgetLabel, key: const ValueKey('home-mobile-budget-value'),
                      style: AppTypography.label(context, fontSize: 12,
                        color: secondary)),
                    const SizedBox(width: 3),
                    Icon(Icons.chevron_right_rounded, size: 16, color: secondary),
                  ]),
                  if (ratio != null && !hidden) ...[
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        key: const ValueKey('home-mobile-budget-progress'),
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: border,
                        color: ratio >= 1
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
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
                  : 'ver movimentações',
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
