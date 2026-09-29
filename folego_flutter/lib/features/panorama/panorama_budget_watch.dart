import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';

/// A deterministic watchlist, NOT a forecast or personal spending judgment.
/// Current totals are already aggregated on parent category rows by the
/// backend. Including children here would count the same spending twice.
class PanoramaBudgetWatchEntry {
  const PanoramaBudgetWatchEntry._({
    required this.item,
    required this.ratio,
  });

  final BudgetOverviewItem item;
  final double ratio;

  bool get overLimit => item.actualAmount > item.plannedAmount;
  double get exceeded => overLimit
      ? item.actualAmount - item.plannedAmount
      : 0;
  double get remaining => overLimit
      ? 0
      : item.plannedAmount - item.actualAmount;

  static List<PanoramaBudgetWatchEntry>? fromBudgets(
    List<BudgetOverviewItem>? budgets, {
    int maxItems = 3,
  }) {
    if (budgets == null) return null; // unavailable, not empty
    if (maxItems <= 0) return const [];
    final candidates = <PanoramaBudgetWatchEntry>[];

    for (final item in budgets) {
      if (!item.isParent ||
          !item.plannedAmount.isFinite ||
          !item.actualAmount.isFinite ||
          item.plannedAmount <= 0 ||
          item.actualAmount < 0) {
        continue;
      }

      // Respect an explicitly configured earlier warning threshold. A
      // malformed server threshold falls back to Fôlego's 70% baseline.
      final requested = item.warningThreshold;
      final warningAt = requested > 0 && requested <= 1
          ? requested
          : .70;
      final ratio = item.actualAmount / item.plannedAmount;
      if (ratio < warningAt) continue;
      candidates.add(PanoramaBudgetWatchEntry._(
        item: item,
        ratio: ratio,
      ));
    }

    candidates.sort((a, b) {
      if (a.overLimit != b.overLimit) {
        return a.overLimit ? -1 : 1;
      }
      if (a.overLimit) {
        final byOverage = b.exceeded.compareTo(a.exceeded);
        if (byOverage != 0) return byOverage;
      }
      final byRatio = b.ratio.compareTo(a.ratio);
      return byRatio != 0
          ? byRatio
          : a.item.categoryName.compareTo(b.item.categoryName);
    });
    return candidates.take(maxItems).toList(growable: false);
  }
}

/// Optional section WITHIN an already verified budget card.
/// When privacy is enabled, hide both values and proportional progress:
/// a precise percentage/progress bar could reconstruct masked amounts.
class PanoramaBudgetWatch extends StatelessWidget {
  const PanoramaBudgetWatch({super.key, required this.entries});

  final List<PanoramaBudgetWatchEntry> entries;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: FinancialPrivacy.hidden,
        builder: (context, hidden, _) => _buildContent(context, hidden),
      );

  Widget _buildContent(BuildContext context, bool hidden) {
    final brightness = Theme.of(context).brightness;
    final subdued = AppColors.secondaryText(brightness);
    return Column(
      key: const ValueKey('panorama-budget-watch'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Divider(color: AppColors.border(brightness)),
        const SizedBox(height: 5),
        Text(
          'categorias para acompanhar',
          style: AppTypography.section(context, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Limites e despesas registrados neste mês; não é previsão.',
          style: AppTypography.body(context, fontSize: 10, color: subdued),
        ),
        const SizedBox(height: 7),
        for (final entry in entries) ...[
          Semantics(
            container: true,
            label: hidden
                ? '${entry.item.categoryName}: valores ocultos'
                : '${entry.item.categoryName}: '
                    '${entry.overLimit ? 'acima do limite' : 'próximo do limite'}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.item.categoryName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hidden
                            ? 'valores ocultos'
                            : entry.overLimit
                                ? '${Formatters.money(entry.exceeded)} acima'
                                : '${Formatters.money(entry.remaining)} restante',
                        style: AppTypography.body(
                          context,
                          fontSize: 11,
                          color: subdued,
                        ),
                      ),
                    ],
                  ),
                  if (!hidden) ...[
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: entry.ratio.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: AppColors.border(brightness),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
