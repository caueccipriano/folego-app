import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';

/// Read-only presentation of the amounts already returned by budget RPCs.
/// Subcategories only: parent aggregates must never be added a second time.
class BudgetSpendingStory extends StatelessWidget {
  const BudgetSpendingStory({
    super.key,
    required this.overview,
    required this.items,
    required this.onCategory,
    required this.onClassify,
    required this.onSpendingBehavior,
  });

  final FlexibleBudgetOverview overview;
  final List<BudgetOverviewItem> items;
  final ValueChanged<BudgetOverviewItem> onCategory;
  final VoidCallback? onClassify;
  final VoidCallback onSpendingBehavior;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: FinancialPrivacy.hidden,
    builder: (context, hidden, _) {
      final brightness = Theme.of(context).brightness;
      final secondary = AppColors.secondaryText(brightness);
      final rows =
          items
              .where((i) => i.isSubcategory && !i.essential && i.hasActivity)
              .toList()
            ..sort((a, b) {
              if (a.isOverBudget != b.isOverBudget) {
                return a.isOverBudget ? -1 : 1;
              }
              return b.actualAmount.compareTo(a.actualAmount);
            });
      final visible = rows.take(5).toList();
      final maximum = rows.fold<double>(
        0,
        (max, i) => i.actualAmount > max ? i.actualAmount : max,
      );
      return Material(
        key: const ValueKey('budget-spending-story'),
        color: AppColors.surface(brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.feature),
          side: BorderSide(color: AppColors.border(brightness)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'para onde foi meu dinheiro?',
                style: AppTypography.section(context, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                overview.configured
                    ? 'Você planejou ${Formatters.money(overview.limitAmount)} e usou '
                          '${Formatters.money(overview.usedAmount)} neste mês. '
                          '${overview.isExceeded ? "O gasto passou do teto em ${Formatters.money(overview.exceededAmount)}." : "Ainda restam ${Formatters.money(overview.remainingAmount)} dentro desse teto."}'
                    : 'Você já registrou ${Formatters.money(overview.usedAmount)} em gastos flexíveis. '
                          'Sem um teto definido, ainda não dá para dizer quanto passou do planejado.',
                style: AppTypography.body(context, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Esse é o uso do orçamento, não o saldo do banco. '
                'Uma parcela conta no mês em que entra no Plano; pagar a fatura não conta de novo.',
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  color: secondary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'o que mais pesou',
                style: AppTypography.body(context, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                'Até 5 subcategorias, com as que passaram do próprio limite primeiro. '
                'As barras comparam os gastos na mesma escala. Toque para conferir os lançamentos.',
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: secondary,
                ),
              ),
              if (rows.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Ainda não há gastos flexíveis detalhados em subcategorias neste mês. '
                  'Revise as categorias para acompanhar melhor.',
                  style: AppTypography.body(context, fontSize: 12),
                ),
              ],
              for (final item in visible) ...[
                const SizedBox(height: 12),
                InkWell(
                  key: ValueKey('budget-story-${item.categoryId}'),
                  onTap: () => onCategory(item),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              '${item.parentName == null ? "" : "${item.parentName} · "}${item.categoryName}',
                              style: AppTypography.body(
                                context,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              Formatters.money(item.actualAmount),
                              style: AppTypography.money(context, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        if (!hidden)
                          ExcludeSemantics(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                              child: LinearProgressIndicator(
                                value: maximum > 0
                                    ? (item.actualAmount / maximum).clamp(
                                        0.0,
                                        1.0,
                                      )
                                    : 0,
                                minHeight: 9,
                                backgroundColor: AppColors.border(brightness),
                                color: AppColors.primaryPurple(brightness),
                              ),
                            ),
                          )
                        else
                          Text(
                            'gráfico oculto junto com os valores',
                            style: AppTypography.body(
                              context,
                              fontSize: 11,
                              color: secondary,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          item.hasBudget
                              ? 'limite: ${Formatters.money(item.plannedAmount)} · '
                                    '${item.isOverBudget ? "passou ${Formatters.money(-item.remainingAmount)}" : "dentro do limite"}'
                              : 'sem limite próprio · esse gasto também conta no teto global',
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'O gráfico mostra apenas as subcategorias acima. Gastos sem categoria, '
                'diretos na categoria principal e demais subcategorias podem fazer parte do total do mês. '
                'Ultrapassar uma categoria não significa necessariamente ultrapassar o teto global.',
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: secondary,
                ),
              ),
              const Divider(height: 28),
              Text(
                'deixe a próxima revisão mais fácil',
                style: AppTypography.body(context, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                '1. Confira as sugestões de categoria: o app usa descrições e seu histórico. '
                'Veja o motivo e aceite só o que fizer sentido; sugestões ambíguas ficam para revisão.\n'
                '2. Nos gastos já registrados, escolha fixo (valor estável) ou variável (muda). '
                'Recorrente é frequência: uma conta pode ser recorrente e variável. '
                'Essa marcação não altera o valor nem o saldo.',
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  color: secondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('budget-story-classify'),
                    onPressed: onClassify,
                    child: const Text('revisar categorias inteligentes'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('budget-story-fixed-variable'),
                    onPressed: onSpendingBehavior,
                    child: const Text('separar gastos fixos e variáveis'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
