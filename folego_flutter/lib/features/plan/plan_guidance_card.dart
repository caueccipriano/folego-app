import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../../core/privacy/financial_privacy.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';
import 'plan_guidance.dart';

/// Offers one next planning action and evidence-based places to review.
class PlanGuidanceCard extends StatelessWidget {
  const PlanGuidanceCard({
    super.key,
    required this.items,
    required this.canEdit,
    required this.onEdit,
    required this.onReviewSpending,
    this.onClassify,
    this.onEditReviewCategory,
    this.onCompareMonths,
    this.insights,
  });

  final List<BudgetOverviewItem> items;
  final Future<PlanInsights>? insights;
  final bool canEdit;
  final void Function(BudgetOverviewItem category, double? suggestedAmount) onEdit;
  final ValueChanged<BudgetOverviewItem> onReviewSpending;
  final VoidCallback? onClassify;
  final ValueChanged<BudgetOverviewItem>? onEditReviewCategory;
  /// Navigates to a calendar-day-matched comparison; no network call until tapped.
  final VoidCallback? onCompareMonths;

  @override
  Widget build(BuildContext context) {
    final next = nextPlanCategory(items);
    final targets = spendingReviewTargets(items);
    final parents = items.where((item) => item.isParent && item.hasActivity).toList()
      ..sort((a, b) => b.actualAmount.compareTo(a.actualAmount));
    final largest = parents.isEmpty ? null : parents.first;
    final total = parents.fold<double>(0, (sum, item) => sum + item.actualAmount);
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: FinancialPrivacy.hidden,
      builder: (context, hidden, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (next != null || !canEdit) Container(
            key: const ValueKey('plan-guided-start'),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Color.alphaBlend(scheme.primary.withValues(alpha: .055), scheme.surface),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.primary.withValues(alpha: .18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.tune_rounded, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('seu próximo passo',
                    style: AppTypography.cardTitle(context, fontSize: 17,
                      color: scheme.onSurface))),
                ]),
                const SizedBox(height: 5),
                Text(
                  canEdit
                    ? 'uma sugestão para organizar seu mês.'
                    : 'este mês está disponível apenas para consulta.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
                if (next != null && canEdit) ...[
                  const SizedBox(height: 13),
                  FutureBuilder<PlanInsights>(
                    future: insights,
                    builder: (context, snapshot) {
                      PlanSuggestion? suggested;
                      if (snapshot.hasData) {
                        for (final idea in snapshot.data!.suggestions) {
                          if (idea.categoryId == next.categoryId &&
                              idea.suggestedLimit > 0) {
                            suggested = idea;
                            break;
                          }
                        }
                      }
                      final proposed = suggested;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(next.hasBudget
                            ? 'rever: ${next.categoryName}'
                            : 'comece por: ${next.categoryName}',
                            style: TextStyle(color: scheme.onSurface,
                              fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            proposed != null
                              ? 'média de ${proposed.sampleMonths} meses: '
                                '${hidden ? "R\$ ••••" : Formatters.money(proposed.historicalAverage)}. '
                                'limite sugerido: '
                                '${hidden ? "R\$ ••••" : Formatters.money(proposed.suggestedLimit)}.'
                              : next.hasActivity
                                ? 'gastos no mês: '
                                  '${hidden ? "R\$ ••••" : Formatters.money(next.actualAmount)}. '
                                  'escolha seu limite.'
                                : 'defina um valor que faça sentido para você.',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey('plan-guided-edit'),
                            onPressed: () => onEdit(next, proposed?.suggestedLimit),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(next.hasBudget ? 'ajustar limite' : 'definir limite'),
                          ),
                        ],
                      );
                    },
                  ),
                ] else if (next == null) ...[
                  const SizedBox(height: 9),
                  Text(
                    items.any((item) => item.isSubcategory && item.hasBudget)
                        ? 'seus limites estão configurados. acompanhe os gastos abaixo.'
                        : 'nenhuma subcategoria disponível para ajustar agora.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('plan-review-focus'),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.lightbulb_outline_rounded, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('gastos em foco',
                    style: AppTypography.cardTitle(context, fontSize: 17,
                      color: scheme.onSurface))),
                ]),
                const SizedBox(height: 4),
                Text('comece pelo primeiro ponto; os demais são opcionais.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                if (largest != null && total > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    'maior grupo: ${largest.categoryName} · '
                    '${hidden ? "R\$ ••••" : Formatters.money(largest.actualAmount)} '
                    '${hidden ? "" : "(${(largest.actualAmount / total * 100).round()}% do total acompanhado)"}',
                    key: const ValueKey('plan-largest-category'),
                    style: TextStyle(color: scheme.onSurface, fontSize: 12,
                      fontWeight: FontWeight.w600)),
                ],
                if (targets.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    total == 0
                      ? 'quando houver gastos, mostro onde vale conferir primeiro.'
                      : 'nenhum gasto acima do limite ou sem orçamento identificado.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ] else ...[
                  const SizedBox(height: 9),
                  _focusItem(context, targets.first, hidden, prominent: true),
                  if (targets.length > 1) ...[
                    const SizedBox(height: 5),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ExpansionTile(
                          key: const ValueKey('plan-focus-more'),
                        initiallyExpanded: false,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          'ver outros ${targets.length - 1} pontos',
                          style: AppTypography.label(context,
                            fontSize: 13, color: scheme.primary,
                            fontWeight: FontWeight.w700),
                        ),
                        children: [
                          for (final target in targets.skip(1)) ...[
                            const Divider(height: 12),
                            _focusItem(context, target, hidden),
                          ],
                        ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('valores dos registros; revisar não altera seus gastos.',
                    style: AppTypography.label(context,
                      fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
                if (onCompareMonths != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    key: const ValueKey('plan-compare-months'),
                    onPressed: onCompareMonths,
                    icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                    label: const Text('comparar meses'),
                  ),

                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _focusItem(
    BuildContext context,
    PlanReviewTarget target,
    bool hidden, {
    bool prominent = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final action = _reviewAction(target);
    return Container(
        decoration: prominent
            ? BoxDecoration(
                color: Color.alphaBlend(
                  scheme.primary.withValues(alpha: .045), scheme.surface),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              )
            : null,
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
          key: ValueKey('plan-focus-${target.category.categoryId}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          dense: true,
          title: Text(target.category.categoryName,
            style: AppTypography.cardTitle(context,
              fontSize: 14, color: scheme.onSurface)),
          subtitle: Text(_reason(target, hidden),
            style: AppTypography.body(context,
              fontSize: 12, color: scheme.onSurfaceVariant)),
          trailing: action == null
              ? const Icon(Icons.chevron_right_rounded)
              : TextButton(
                  key: ValueKey('plan-focus-action-${target.category.categoryId}'),
                  onPressed: action,
                  child: Text(_reviewActionLabel(target)),
                ),
          onTap: () => onReviewSpending(target.category),
          ),
        ),
    );
  }

  VoidCallback? _reviewAction(PlanReviewTarget target) {
    if (!canEdit) return null;
    if (target.reason == PlanReviewReason.uncategorized) return onClassify;
    if (target.reason == PlanReviewReason.noLimit &&
        onEditReviewCategory != null) {
      final child = editableChildForReview(target.category, items);
      if (child != null) return () => onEditReviewCategory!(child);
    }
    return null;
  }

  String _reviewActionLabel(PlanReviewTarget target) {
    if (target.reason == PlanReviewReason.uncategorized) {
      return 'classificar';
    }
    return 'definir limite';
  }

  String _reason(PlanReviewTarget target, bool hidden) {
    final item = target.category;
    String money(double value) => hidden ? 'R\$ ••••' : Formatters.money(value);
    return switch (target.reason) {
      PlanReviewReason.uncategorized =>
        '${money(item.actualAmount)} ainda sem categoria; classificar melhora a análise.',
      PlanReviewReason.overLimit =>
        '${money(-item.remainingAmount)} acima do limite; confira o que pesou.',
      PlanReviewReason.noLimit =>
        '${money(item.actualAmount)} registrados sem limite definido.',
      PlanReviewReason.approachingLimit =>
        '${money(item.actualAmount)} de ${money(item.plannedAmount)} do limite usado.',
    };
  }
}
