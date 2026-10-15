import 'package:flutter/material.dart';
import 'package:folego/core/theme/app_colors.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';

/// Plan intelligence: read-only checks, three distinct money concepts and
/// optional proposed limits. No action applies a limit without the edit modal.
class PlanInsightsSection extends StatelessWidget {
  const PlanInsightsSection({
    super.key,
    required this.insights,
    this.onReviewSuggestion,
    this.allowEditing = true,
  });

  final Future<PlanInsights> insights;
  final ValueChanged<PlanSuggestion>? onReviewSuggestion;
  final bool allowEditing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<PlanInsights>(
      future: insights,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'conferência automática indisponível agora. '
              'seus lançamentos e limites continuam preservados.',
              key: const ValueKey('plan-insights-unavailable'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          );
        }
        final data = snapshot.data!;
        return Container(
          key: const ValueKey('plan-intelligence'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('entenda seu dinheiro',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
              const SizedBox(height: 5),
              Text('três contas diferentes — sem misturar orçamento e banco',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              Wrap(
                runSpacing: 9,
                spacing: 9,
                children: [
                  _MoneyView(
                    label: 'despesas do mês',
                    amount: data.economicSpending,
                    detail: 'compras, parcelas e benefícios atribuídos ao mês',
                  ),
                  _MoneyView(
                    label: 'dinheiro que saiu das contas',
                    amount: data.cashOutflows,
                    detail: 'inclui PIX, faturas, parcelas e transferências',
                  ),
                  _MoneyView(
                    label: 'disponível estimado agora',
                    amount: data.estimatedAvailableNow,
                    detail: 'calculado pelos registros; não é extrato bancário',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'no controle do orçamento, também entram '
                '${Formatters.money(data.debtPayments)} em pagamentos de dívidas '
                'confirmados. total acompanhado: '
                '${Formatters.money(data.budgetTracked)}.',
                key: const ValueKey('plan-insights-budget-total'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 9),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: AppColors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('plan-insights-audit'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text('conferir meu plano',
                    style: TextStyle(color: scheme.onSurface,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    data.issues.isEmpty
                        ? 'nenhuma das verificações encontrou pendências'
                        : '${data.issues.length} tipo(s) de pendência para revisar',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  ),
                  children: [
                    Text('checagem de lançamentos sem categoria, sem subcategoria, '
                      'pagamentos de cartão sem vínculo e importações semelhantes. '
                      'um alerta não é prova de erro.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                    const SizedBox(height: 8),
                    if (data.issues.isEmpty)
                      const Text('nenhuma pendência encontrada nesta verificação.',
                        style: TextStyle(fontSize: 12))
                    else
                      ...data.issues.map((issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${issue.title} · ${issue.count} ocorrência(s)',
                              style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600, color: scheme.onSurface)),
                            Text('${Formatters.money(issue.amount)} · '
                              '${issue.description}',
                              style: TextStyle(fontSize: 11,
                                color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: AppColors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('plan-insights-suggestions'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text('sugestões de limite',
                    style: TextStyle(color: scheme.onSurface,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('histórico de até três meses · você decide',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                  children: [
                    Text(
                      'estimativas: média dos meses com movimento, mais 10% '
                      'de margem, arredondada para R\$ 10. apenas categorias '
                      'com movimentações em pelo menos dois meses anteriores. '
                      'não considera sua capacidade de pagamento. '
                      'nenhum limite muda sem você confirmar.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    if (data.suggestions.isEmpty)
                      const Text('ainda não há histórico suficiente para sugerir limites.',
                        style: TextStyle(fontSize: 12))
                    else
                      ...data.suggestions.take(6).map((suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(suggestion.categoryName,
                                    style: TextStyle(fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface)),
                                  Text(
                                    'média: ${Formatters.money(suggestion.historicalAverage)} '
                                    'em ${suggestion.sampleMonths} meses · '
                                    'sugestão: ${Formatters.money(suggestion.suggestedLimit)}',
                                    style: TextStyle(fontSize: 11,
                                      color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            if (allowEditing && onReviewSuggestion != null)
                              TextButton(
                                key: ValueKey('plan-review-suggestion-${suggestion.categoryId}'),
                                onPressed: () => onReviewSuggestion!(suggestion),
                                child: const Text('revisar'),
                              ),
                          ],
                        ),
                      )),
                    if (data.suggestions.length > 6)
                      Text('mostrando as seis categorias com maior histórico.',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}

class _MoneyView extends StatelessWidget {
  const _MoneyView({
    required this.label,
    required this.amount,
    required this.detail,
  });

  final String label;
  final double amount;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 198,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: scheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(Formatters.money(amount), style: TextStyle(fontSize: 17,
            fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(fontSize: 10,
            color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
