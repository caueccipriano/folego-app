import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/monthly_money_summary.dart';

const monthlyCardSemanticsTooltip =
    'Compras no cartão aparecem aqui quando são feitas. '
    'As parcelas aparecem por competência em Faturas e parcelas. '
    'Pagar a fatura não conta como gasto novamente.';

class HomeMonthlyMoneyCard extends StatelessWidget {
  const HomeMonthlyMoneyCard({
    super.key,
    required this.summary,
    required this.unavailable,
  });

  final MonthlyMoneySummary? summary;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    if (unavailable || summary == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Text(
          'não consegui montar o resumo deste mês agora',
          style: AppTypography.body(
            context,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
      );
    }

    final value = summary!;
    final monthName = _monthName(value.periodMonth.month);

    return Container(
      key: const ValueKey('home-monthly-money-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'seu mês até agora',
                      style: AppTypography.section(context, fontSize: 20),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'gastos feitos em $monthName',
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: monthlyCardSemanticsTooltip,
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(AppIcons.info, size: 20, color: secondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'gastos do mês',
            style: AppTypography.label(context, color: secondary),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.money(value.spendingNet),
              key: const ValueKey('monthly-spending-net'),
              style: AppTypography.money(
                context,
                fontSize: 34,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _MetricGrid(
            items: [
              _MetricData(
                label: 'conta',
                amount: value.spendingAccount,
                icon: AppIcons.account,
              ),
              _MetricData(
                label: 'cartões',
                amount: value.spendingCards,
                icon: AppIcons.creditCard,
              ),
              _MetricData(
                label: 'benefícios',
                amount: value.spendingBenefits,
                icon: AppIcons.benefit,
              ),
              _MetricData(
                label: 'reembolsos',
                amount: value.refundsAmount,
                icon: AppIcons.refresh,
                subtract: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: border),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'receitas do mês',
            value: Formatters.money(value.incomeAmount),
            valueColor: AppColors.positiveText(brightness),
          ),
          const SizedBox(height: 11),
          _SummaryRow(
            label: 'saldo compras x renda',
            value: _signedMoney(value.incomeMinusSpending),
            valueColor: primary,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('monthly-money-composition'),
              onPressed: () => showMonthlyMoneyComposition(
                context,
                summary: value,
              ),
              icon: const Icon(AppIcons.chevronRight, size: 17),
              iconAlignment: IconAlignment.end,
              label: const Text('ver composição'),
              style: TextButton.styleFrom(foregroundColor: purple),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.amount,
    required this.icon,
    this.subtract = false,
  });

  final String label;
  final double amount;
  final IconData icon;
  final bool subtract;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_MetricData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        if (!compact) {
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: _MetricTile(data: items[i])),
                if (i != items.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _MetricTile(data: items[0])),
                const SizedBox(width: 10),
                Expanded(child: _MetricTile(data: items[1])),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MetricTile(data: items[2])),
                const SizedBox(width: 10),
                Expanded(child: _MetricTile(data: items[3])),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final muted = AppColors.background(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final amount = data.subtract && data.amount > 0
        ? '-${Formatters.money(data.amount)}'
        : Formatters.money(data.amount);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: muted,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, size: 18, color: secondary),
          const SizedBox(height: 9),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label(
              context,
              fontSize: 10,
              color: secondary,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: AppTypography.money(
                context,
                fontSize: 14,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.secondaryText(Theme.of(context).brightness);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: secondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: AppTypography.body(
            context,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

Future<void> showMonthlyMoneyComposition(
  BuildContext context, {
  required MonthlyMoneySummary summary,
}) async {
  final content = _MonthlyMoneyComposition(summary: summary);
  if (AppBreakpoints.of(context) == AppLayoutSize.compact) {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => content,
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: content,
      ),
    ),
  );
}

class _MonthlyMoneyComposition extends StatelessWidget {
  const _MonthlyMoneyComposition({required this.summary});

  final MonthlyMoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'composição do seu mês',
                    style: AppTypography.section(context, fontSize: 21),
                  ),
                ),
                IconButton(
                  tooltip: 'fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cada bloco responde uma pergunta diferente. Eles não são somados entre si.',
              style: AppTypography.body(
                context,
                fontSize: 12,
                color: secondary,
              ),
            ),
            const SizedBox(height: 20),
            _CompositionSection(
              title: 'gastos feitos no mês',
              subtitle: 'quanto você comprou ou gastou quando o movimento aconteceu',
              rows: [
                _CompositionRow('conta', summary.spendingAccount),
                _CompositionRow('cartões', summary.spendingCards),
                _CompositionRow('benefícios', summary.spendingBenefits),
                _CompositionRow(
                  'reembolsos',
                  summary.refundsAmount,
                  subtract: true,
                ),
              ],
              totalLabel: 'total líquido de gastos feitos',
              total: summary.spendingNet,
            ),
            const SizedBox(height: 14),
            _CompositionSection(
              title: 'faturas e parcelas',
              subtitle: 'o que pertence economicamente a ${_monthName(summary.periodMonth.month)}',
              rows: [
                for (final card in summary.competenceCards)
                  _CompositionRow(
                    'fatura ${card.name} / parcelas',
                    card.amount,
                  ),
                _CompositionRow(
                  'despesas diretas',
                  summary.competenceDirect,
                ),
                _CompositionRow(
                  'benefícios',
                  summary.competenceBenefits,
                ),
                if (summary.competenceRefunds > 0)
                  _CompositionRow(
                    'reembolsos que reduzem competência',
                    summary.competenceRefunds,
                    subtract: true,
                  ),
              ],
              totalLabel: 'despesa por competência',
              total: summary.competenceNet,
            ),
            const SizedBox(height: 14),
            _CompositionSection(
              title: 'movimentações que não são gasto',
              subtitle: 'dinheiro mudou de lugar ou o saldo foi conciliado, sem criar nova despesa',
              rows: [
                _CompositionRow(
                  'pagamentos de fatura',
                  summary.movementCardPayments,
                ),
                _CompositionRow(
                  'transferências entre suas contas',
                  summary.movementTransfers,
                ),
                _CompositionRow(
                  'investimentos / reserva',
                  summary.movementReserveInvestment,
                ),
                _CompositionRow(
                  'ajustes de conciliação',
                  summary.movementReconciliation,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'movimentação de caixa',
                    style: AppTypography.body(
                      context,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PlainRow(
                    label: 'entrou nas contas',
                    value: Formatters.money(summary.cashInflow),
                  ),
                  const SizedBox(height: 8),
                  _PlainRow(
                    label: 'saiu das contas',
                    value: Formatters.money(summary.cashOutflow),
                  ),
                  const SizedBox(height: 8),
                  _PlainRow(
                    label: 'variação líquida de caixa',
                    value: _signedMoney(summary.cashNet),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Caixa mostra entrada e saída de dinheiro. Não é sinônimo de receita ou despesa.',
                    style: AppTypography.label(
                      context,
                      fontSize: 10,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.info, size: 18, color: secondary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    monthlyCardSemanticsTooltip,
                    style: AppTypography.body(
                      context,
                      fontSize: 11,
                      color: secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompositionRow {
  const _CompositionRow(this.label, this.amount, {this.subtract = false});

  final String label;
  final double amount;
  final bool subtract;
}

class _CompositionSection extends StatelessWidget {
  const _CompositionSection({
    required this.title,
    required this.subtitle,
    required this.rows,
    this.totalLabel,
    this.total,
  });

  final String title;
  final String subtitle;
  final List<_CompositionRow> rows;
  final String? totalLabel;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.body(
              context,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.label(
              context,
              fontSize: 10,
              color: secondary,
            ),
          ),
          const SizedBox(height: 13),
          for (var i = 0; i < rows.length; i++) ...[
            _PlainRow(
              label: rows[i].label,
              value: rows[i].subtract && rows[i].amount > 0
                  ? '-${Formatters.money(rows[i].amount)}'
                  : Formatters.money(rows[i].amount),
            ),
            if (i != rows.length - 1) const SizedBox(height: 8),
          ],
          if (total != null && totalLabel != null) ...[
            const SizedBox(height: 12),
            Divider(color: border),
            const SizedBox(height: 10),
            _PlainRow(
              label: totalLabel!,
              value: Formatters.money(total!),
              emphasize: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(
              context,
              fontSize: emphasize ? 12 : 11,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? primary : secondary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          value,
          style: AppTypography.body(
            context,
            fontSize: emphasize ? 13 : 11,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
      ],
    );
  }
}

String _signedMoney(double value) {
  if (value > 0) return '+${Formatters.money(value)}';
  if (value < 0) return '-${Formatters.money(value.abs())}';
  return Formatters.money(0);
}

String _monthName(int month) {
  const names = <String>[
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  if (month < 1 || month > 12) return 'mês';
  return names[month - 1];
}
