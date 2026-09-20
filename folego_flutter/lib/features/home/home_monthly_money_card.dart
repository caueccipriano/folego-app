import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/monthly_money_summary.dart';

const monthlyCardSemanticsTooltip =
    'Gastos feitos no mês mostram o que você comprou ou gastou neste mês. '
    'Compras no cartão entram pelo valor total no dia da compra. '
    'Despesa por competência mostra o que pertence financeiramente ao mês, '
    'e compras parceladas entram parcela a parcela. '
    'Pagar a fatura reduz seu saldo, mas não conta como uma nova despesa.';

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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadii.feature),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.feature),
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
                      style: AppTypography.section(context, fontSize: 18),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'um retrato simples de $monthName',
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
          const SizedBox(height: 10),
          _MonthlyHeadlineGrid(
            items: [
              _MonthlyHeadlineData(
                label: 'receitas reais',
                value: Formatters.money(value.realIncome),
                valueColor: AppColors.positiveText(brightness),
              ),
              _MonthlyHeadlineData(
                label: 'gastos feitos no mês',
                value: Formatters.money(value.spendingNet),
                valueColor: primary,
                valueKey: const ValueKey('monthly-spending-net'),
              ),
              _MonthlyHeadlineData(
                label: 'resultado econômico',
                value: _signedMoney(value.economicResult),
                valueColor: value.economicResult < 0
                    ? AppColors.expenseText(brightness)
                    : primary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'de onde vieram os gastos',
            style: AppTypography.label(context, color: secondary),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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

class _MonthlyHeadlineData {
  const _MonthlyHeadlineData({
    required this.label,
    required this.value,
    required this.valueColor,
    this.valueKey,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Key? valueKey;
}

class _MonthlyHeadlineGrid extends StatelessWidget {
  const _MonthlyHeadlineGrid({required this.items});

  final List<_MonthlyHeadlineData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        if (!compact) {
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: _MonthlyHeadlineTile(data: items[i])),
                if (i != items.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _MonthlyHeadlineTile(data: items[0])),
                const SizedBox(width: 10),
                Expanded(child: _MonthlyHeadlineTile(data: items[1])),
              ],
            ),
            const SizedBox(height: 10),
            _MonthlyHeadlineTile(data: items[2]),
          ],
        );
      },
    );
  }
}

class _MonthlyHeadlineTile extends StatelessWidget {
  const _MonthlyHeadlineTile({required this.data});

  final _MonthlyHeadlineData data;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final muted = AppColors.background(brightness);
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: muted,
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        border: Border.all(color: border.withValues(alpha: .72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label(
              context,
              fontSize: 10,
              color: secondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              key: data.valueKey,
              style: AppTypography.money(
                context,
                fontSize: 17,
                color: data.valueColor,
              ),
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

        const gap = 8.0;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _CompactMetricTile(data: item),
              ),
          ],
        );
      },
    );
  }
}

class _CompactMetricTile extends StatelessWidget {
  const _CompactMetricTile({required this.data});

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
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: muted,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: border.withValues(alpha: .68)),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 16, color: secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(
                    context,
                    fontSize: 9,
                    color: secondary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    style: AppTypography.money(
                      context,
                      fontSize: 12,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
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
              title: 'gastos feitos',
              subtitle:
                  'mostra o que você comprou ou gastou neste mês; cartão entra pelo valor total no dia da compra',
              rows: [
                _CompositionRow(
                  'conta / PIX / débito',
                  summary.accountSpending,
                ),
                _CompositionRow(
                  'cartões — compras feitas',
                  summary.cardPurchasesMade,
                ),
                _CompositionRow(
                  'benefícios gastos',
                  summary.benefitSpending,
                ),
                _CompositionRow(
                  'reembolsos',
                  summary.refunds,
                  subtract: true,
                ),
              ],
              totalLabel: 'gastos feitos no mês',
              total: summary.spendingMade,
            ),
            const SizedBox(height: 14),
            _CompositionSection(
              title: 'competência do mês',
              subtitle:
                  'mostra o que pertence financeiramente a ${_monthName(summary.periodMonth.month)}; parceladas entram parcela a parcela',
              rows: [
                _CompositionRow(
                  'despesas diretas',
                  summary.competenceDirect,
                ),
                _CompositionRow(
                  'cartões na competência',
                  summary.cardCompetence,
                ),
                _CompositionRow(
                  'outras despesas',
                  summary.competenceBenefits,
                ),
                if (summary.competenceRefunds > 0)
                  _CompositionRow(
                    'reembolsos / ajustes econômicos',
                    summary.competenceRefunds,
                    subtract: true,
                  ),
              ],
              totalLabel: 'despesa por competência',
              total: summary.competenceExpenses,
            ),
            const SizedBox(height: 14),
            _CompositionSection(
              title: 'movimentações que não são novos gastos',
              subtitle:
                  'podem reduzir ou mover caixa, mas não aumentam seus gastos feitos',
              rows: [
                _CompositionRow(
                  'pagamentos de fatura',
                  summary.cardPayments,
                ),
                _CompositionRow(
                  'transferências / investimentos',
                  summary.transfersAndInvestments,
                ),
                _CompositionRow(
                  'ajustes de conciliação',
                  summary.reconciliationAdjustments,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(AppRadii.compactCard),
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
        borderRadius: BorderRadius.circular(AppRadii.card),
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
