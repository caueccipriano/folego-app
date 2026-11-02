import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';

/// Four existing financial totals, with their distinct meanings.
/// Read-only: no arithmetic, extra queries, or writes.
class FinancialNumbersGuide extends StatelessWidget {
  const FinancialNumbersGuide({
    super.key,
    required this.accountBalance,
    required this.untilIncome,
    this.spendingByPurchaseDate,
    this.expensesByCompetence,
  });

  final double accountBalance;
  final double untilIncome;
  final double? spendingByPurchaseDate;
  final double? expensesByCompetence;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: FinancialPrivacy.hidden,
      builder: (context, hidden, _) => Container(
        key: const ValueKey('financial-numbers-guide'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.feature),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('por que os números são diferentes?',
              style: AppTypography.cardTitle(context, fontSize: 17)),
            const SizedBox(height: 5),
            Text('Cada valor responde a uma pergunta diferente.',
              style: AppTypography.body(context, fontSize: 12,
                color: colors.onSurfaceVariant)),
            const SizedBox(height: 14),
            _MetricLine(
              label: 'dinheiro nas contas para uso',
              amount: hidden ? FinancialPrivacy.maskMoney()
                  : Formatters.money(accountBalance),
              meaning: 'Saldo registrado como utilizável. Não é a margem '
                  'para assumir novas despesas.',
            ),
            const Divider(height: 24),
            _MetricLine(
              label: 'disponível até receber',
              amount: hidden ? FinancialPrivacy.maskMoney()
                  : Formatters.money(untilIncome),
              meaning: 'Margem depois dos compromissos previstos; '
                  'o orçamento flexível também pode limitar.',
            ),
            if (spendingByPurchaseDate != null &&
                expensesByCompetence != null) ...[
              const Divider(height: 28),
              Text('duas formas de olhar os gastos',
                style: AppTypography.cardTitle(context, fontSize: 14)),
              const SizedBox(height: 12),
              _MetricLine(
                label: 'gastos feitos no mês',
                amount: hidden ? FinancialPrivacy.maskMoney()
                    : Formatters.money(spendingByPurchaseDate!),
                meaning: 'Compras e gastos pela data em que aconteceram, '
                    'inclusive compras no cartão.',
              ),
              const Divider(height: 24),
              _MetricLine(
                label: 'despesas por competência',
                amount: hidden ? FinancialPrivacy.maskMoney()
                    : Formatters.money(expensesByCompetence!),
                meaning: 'Despesas atribuídas a este mês, incluindo '
                    'parcelas de compras feitas antes.',
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Esses valores não devem ser somados entre si. '
              'São leituras de momentos e critérios diferentes, '
              'baseadas nos registros do Fôlego.',
              style: AppTypography.label(context, fontSize: 12,
                color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.amount,
    required this.meaning,
  });

  final String label;
  final String amount;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(label, style: AppTypography.label(context,
              fontSize: 13, color: colors.onSurface)),
          ),
          const SizedBox(width: 9),
          Flexible(child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(amount, style: AppTypography.money(context,
              fontSize: 18, color: colors.onSurface)),
          )),
        ]),
        const SizedBox(height: 4),
        Text(meaning, style: AppTypography.body(context,
          fontSize: 12, color: colors.onSurfaceVariant)),
      ],
    );
  }
}
