import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/monthly_money_summary.dart';

const monthlyCardSemanticsTooltip =
    'Aqui você vê o que recebeu e o que gastou neste mês, não o saldo do banco. '
    'Transferir dinheiro entre suas contas não é receber uma nova receita. '
    'Uma compra no cartão entra nos gastos na data da compra; pagar a fatura '
    'não conta como outro gasto. O resultado do mês considera as parcelas '
    'que pertencem a ele.';

enum MonthlyMoneyTransactionKind { income, spending }

class HomeMonthlyMoneyCard extends StatelessWidget {
  const HomeMonthlyMoneyCard({
    super.key,
    required this.summary,
    required this.unavailable,
    this.onOpenEvolution,
    this.onOpenClosing,
    this.onOpenTransactions,
  });

  final MonthlyMoneySummary? summary;
  final bool unavailable;
  final VoidCallback? onOpenEvolution;
  final VoidCallback? onOpenClosing;
  final void Function(MonthlyMoneyTransactionKind, DateTime)?
  onOpenTransactions;

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
                      'movimentações de $monthName · não são saldos disponíveis',
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
                label: 'quanto entrou?',
                icon: AppIcons.income,
                value: Formatters.money(value.realIncome),
                valueColor: AppColors.positiveText(brightness),
                hint: 'receitas do mês · ver transações',
                tapKey: const ValueKey('monthly-income-open-transactions'),
                onTap: onOpenTransactions == null
                    ? null
                    : () => onOpenTransactions!(
                        MonthlyMoneyTransactionKind.income,
                        value.periodMonth,
                      ),
              ),
              _MonthlyHeadlineData(
                label: 'quanto gastei?',
                icon: AppIcons.expense,
                value: Formatters.money(value.spendingMade),
                valueColor: primary,
                valueKey: const ValueKey('monthly-spending-net'),
                hint: 'compras e gastos · ver transações',
                tapKey: const ValueKey('monthly-spending-open-transactions'),
                onTap: onOpenTransactions == null
                    ? null
                    : () => onOpenTransactions!(
                        MonthlyMoneyTransactionKind.spending,
                        value.periodMonth,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Receitas não incluem transferências internas. Os gastos incluem compras no cartão, mesmo quando a fatura será paga depois.',
            style: AppTypography.body(context, fontSize: 11, color: secondary),
          ),
          const SizedBox(height: 10),
          _EconomicResultTile(summary: value),
          const SizedBox(height: 15),
          Text(
            'onde os gastos aconteceram',
            style: AppTypography.label(context, color: secondary),
          ),
          const SizedBox(height: 5),
          Text(
            'valores gastos no período, não saldos de contas ou cartões',
            style: AppTypography.body(context, fontSize: 11, color: secondary),
          ),
          const SizedBox(height: 10),
          _SpendingSourceList(summary: value),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              TextButton.icon(
                key: const ValueKey('monthly-money-composition'),
                onPressed: () =>
                    showMonthlyMoneyComposition(context, summary: value),
                icon: const Icon(AppIcons.chevronRight, size: 17),
                iconAlignment: IconAlignment.end,
                label: const Text('entender os números'),
                style: TextButton.styleFrom(foregroundColor: purple),
              ),
              if (onOpenClosing != null)
                TextButton.icon(
                  key: const ValueKey('monthly-money-review'),
                  onPressed: onOpenClosing,
                  icon: const Icon(Icons.fact_check_outlined, size: 17),
                  label: const Text('revisar meu mês'),
                  style: TextButton.styleFrom(foregroundColor: purple),
                ),
              if (onOpenEvolution != null)
                TextButton.icon(
                  key: const ValueKey('monthly-money-evolution'),
                  onPressed: onOpenEvolution,
                  icon: const Icon(AppIcons.chartLine, size: 17),
                  label: const Text('ver evolução'),
                  style: TextButton.styleFrom(foregroundColor: purple),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyHeadlineData {
  const _MonthlyHeadlineData({
    required this.label,
    required this.icon,
    required this.value,
    required this.valueColor,
    this.valueKey,
    this.tapKey,
    this.onTap,
    this.hint,
  });

  final String label;
  final IconData icon;
  final String value;
  final Color valueColor;
  final Key? valueKey;
  final Key? tapKey;
  final VoidCallback? onTap;
  final String? hint;
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

        return Row(
          children: [
            Expanded(child: _MonthlyHeadlineTile(data: items[0])),
            const SizedBox(width: 10),
            Expanded(child: _MonthlyHeadlineTile(data: items[1])),
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
    final secondary = AppColors.secondaryText(brightness);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        key: data.tapKey,
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: muted,
            borderRadius: BorderRadius.circular(AppRadii.compactCard),
            border: null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(data.icon, size: 15, color: secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        context,
                        fontSize: 10,
                        color: secondary,
                      ),
                    ),
                  ),
                ],
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
              if (data.onTap != null) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.hint ?? 'ver transações',
                        maxLines: 2,
                        style: AppTypography.label(
                          context,
                          fontSize: 10,
                          color: secondary,
                        ),
                      ),
                    ),
                    Icon(AppIcons.chevronRight, size: 15, color: secondary),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EconomicResultTile extends StatelessWidget {
  const _EconomicResultTile({required this.summary});

  final MonthlyMoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final primary = AppColors.primaryText(brightness);
    final difference = summary.competenceExpenses - summary.spendingMade;

    return Container(
      key: const ValueKey('monthly-economic-result'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background(brightness),
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.chartLine, size: 17, color: secondary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'resultado econômico · não é saldo disponível',
                  style: AppTypography.label(
                    context,
                    fontSize: 11,
                    color: secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _signedMoney(summary.economicResult),
            style: AppTypography.money(
              context,
              fontSize: 22,
              color: summary.economicResult < 0
                  ? AppColors.expenseText(brightness)
                  : AppColors.positiveText(brightness),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'receitas ${Formatters.money(summary.realIncome)} '
            '− despesas por competência ${Formatters.money(summary.competenceExpenses)}',
            style: AppTypography.body(context, fontSize: 11, color: primary),
          ),
          if (difference.abs() >= 0.005) ...[
            const SizedBox(height: 5),
            Text(
              'as despesas por competência são '
              '${difference > 0 ? 'maiores' : 'menores'} que os gastos feitos '
              'em ${Formatters.money(difference.abs())}, pois seguem '
              'datas de reconhecimento diferentes (como parcelas).',
              key: const ValueKey('monthly-competence-difference'),
              style: AppTypography.body(
                context,
                fontSize: 10,
                color: secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpendSource {
  const _SpendSource(this.label, this.amount, this.icon);

  final String label;
  final double amount;
  final IconData icon;
}

class _SpendingSourceList extends StatelessWidget {
  const _SpendingSourceList({required this.summary});

  final MonthlyMoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final sources = <_SpendSource>[
      _SpendSource(
        'gastos pela conta / PIX',
        summary.accountSpending,
        AppIcons.account,
      ),
      _SpendSource(
        'compras no cartão',
        summary.cardPurchasesMade,
        AppIcons.creditCard,
      ),
      _SpendSource(
        'benefícios utilizados',
        summary.benefitSpending,
        AppIcons.benefit,
      ),
    ].where((item) => item.amount > 0).toList(growable: false);
    final gross = sources.fold<double>(0, (total, item) => total + item.amount);

    if (sources.isEmpty && summary.refunds <= 0) {
      return Text(
        'nenhum gasto registrado neste mês',
        style: AppTypography.body(context, fontSize: 12, color: secondary),
      );
    }

    return Column(
      key: const ValueKey('monthly-spending-origins'),
      children: [
        for (final item in sources) ...[
          Row(
            children: [
              Icon(item.icon, size: 18, color: secondary),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: gross <= 0
                            ? 0
                            : (item.amount / gross).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: AppColors.border(brightness),
                        color: purple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Formatters.money(item.amount),
                    style: AppTypography.money(
                      context,
                      fontSize: 13,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
        ],
        if (summary.refunds > 0)
          Row(
            children: [
              Icon(AppIcons.refresh, size: 17, color: secondary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'reembolsos abatidos dos gastos',
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: secondary,
                  ),
                ),
              ),
              Text(
                '-${Formatters.money(summary.refunds)}',
                style: AppTypography.money(
                  context,
                  fontSize: 12,
                  color: primary,
                ),
              ),
            ],
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
              'Cada bloco explica um jeito de olhar para o seu dinheiro. Não some os blocos: o mesmo pagamento pode aparecer em visões diferentes.',
              style: AppTypography.body(
                context,
                fontSize: 12,
                color: secondary,
              ),
            ),
            const SizedBox(height: 20),
            _CompositionSection(
              title: 'o que comprei ou gastei',
              subtitle: 'compras do mês, mesmo no cartão. A compra conta agora; o pagamento da fatura não conta de novo',
              rows: [
                _CompositionRow(
                  'conta / PIX / débito',
                  summary.accountSpending,
                ),
                _CompositionRow(
                  'cartões — compras feitas',
                  summary.cardPurchasesMade,
                ),
                _CompositionRow('benefícios gastos', summary.benefitSpending),
                _CompositionRow('reembolsos', summary.refunds, subtract: true),
              ],
              totalLabel: 'gastos feitos no mês',
              total: summary.spendingMade,
            ),
            const SizedBox(height: 14),
            _CompositionSection(
              title: 'despesas atribuídas a este mês',
              subtitle:
                  'para calcular o resultado do mês, uma compra parcelada entra conforme as parcelas que pertencem a ${_monthName(summary.periodMonth.month)}',
              rows: [
                _CompositionRow('despesas diretas', summary.competenceDirect),
                _CompositionRow(
                  'cartões na competência',
                  summary.cardCompetence,
                ),
                _CompositionRow('outras despesas', summary.competenceBenefits),
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
            Container(
              key: const ValueKey('monthly-economic-calculation'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface(brightness),
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'como chegamos ao resultado econômico',
                    style: AppTypography.body(
                      context,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PlainRow(
                    label: 'receitas do mês',
                    value: Formatters.money(summary.realIncome),
                  ),
                  const SizedBox(height: 8),
                  _PlainRow(
                    label: 'despesas por competência',
                    value: '-${Formatters.money(summary.competenceExpenses)}',
                  ),
                  const SizedBox(height: 10),
                  Divider(color: border),
                  _PlainRow(
                    label: 'resultado econômico (não é saldo)',
                    value: _signedMoney(summary.economicResult),
                    emphasize: true,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'gastos feitos e despesas por competência podem ter valores '
                    'diferentes porque compras e parcelas pertencem a datas distintas.',
                    style: AppTypography.label(
                      context,
                      fontSize: 10,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _CompositionSection(
              title: 'movimentações que não são novos gastos',
              subtitle: 'podem reduzir ou mover caixa, mas não aumentam seus gastos feitos',
              rows: [
                _CompositionRow('pagamentos de fatura', summary.cardPayments),
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
                    'Este bloco acompanha o dinheiro nas contas. Transferências e pagamentos de fatura movem dinheiro, mas não são receitas nem novos gastos.',
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
            style: AppTypography.label(context, fontSize: 10, color: secondary),
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
