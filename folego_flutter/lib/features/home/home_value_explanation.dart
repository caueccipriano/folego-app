import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/monthly_money_summary.dart';

enum HomeValueKind { income, spending, economic }

class HomeValueLine {
  const HomeValueLine(this.label, this.amount, {this.subtract = false});
  final String label;
  final double amount;
  final bool subtract;
}

/// Uses only the monthly RPC response. The totals are never recalculated.
class HomeValueExplanation {
  const HomeValueExplanation({
    required this.title,
    required this.amount,
    required this.meaning,
    required this.excluded,
    required this.lines,
  });
  final String title;
  final double amount;
  final String meaning;
  final String excluded;
  final List<HomeValueLine> lines;

  factory HomeValueExplanation.fromSummary(
      MonthlyMoneySummary s, HomeValueKind kind) {
    switch (kind) {
      case HomeValueKind.income:
        return HomeValueExplanation(
          title: 'quanto entrou?',
          amount: s.realIncome,
          meaning: 'São as receitas registradas neste mês. '
            'Não é necessariamente o saldo disponível na conta.',
          excluded: 'Transferências entre suas contas e limites '
            'do cartão não são receitas novas.',
          lines: [
            HomeValueLine('receitas reconhecidas no mês', s.realIncome),
          ],
        );
      case HomeValueKind.spending:
        return HomeValueExplanation(
          title: 'quanto gastei?',
          amount: s.spendingMade,
          meaning: 'É o que você comprou ou gastou neste mês, '
            'inclusive no cartão, mesmo que a fatura vença depois.',
          excluded: 'Pagar a fatura não é comprar de novo. '
            'Transferências entre suas contas não são despesas novas.',
          lines: [
            HomeValueLine('conta, débito e PIX', s.accountSpending),
            HomeValueLine('compras no cartão', s.cardPurchasesMade),
            HomeValueLine('benefícios utilizados', s.benefitSpending),
            HomeValueLine('estornos e reembolsos', s.refunds, subtract: true),
          ],
        );
      case HomeValueKind.economic:
        return HomeValueExplanation(
          title: 'resultado do mês',
          amount: s.economicResult,
          meaning: 'É a diferença entre as receitas e as despesas '
            'atribuídas a este mês. Não é o dinheiro no banco.',
          excluded: 'Uma compra parcelada entra conforme as parcelas '
            'deste mês. O pagamento da fatura não é uma segunda compra.',
          lines: [
            HomeValueLine('receitas do mês', s.realIncome),
            HomeValueLine('despesas atribuídas ao mês',
              s.competenceExpenses, subtract: true),
          ],
        );
    }
  }
}

String homeValueAmount(double amount, {bool subtract = false}) {
  if (amount < 0) return '−${Formatters.money(amount.abs())}';
  return '${subtract ? "−" : ""}${Formatters.money(amount)}';
}

Future<void> showHomeValueExplanation(
  BuildContext context, {
  required MonthlyMoneySummary summary,
  required HomeValueKind kind,
  VoidCallback? onOpenTransactions,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _HomeValueSheet(
      data: HomeValueExplanation.fromSummary(summary, kind),
      onOpenTransactions: onOpenTransactions,
    ),
  );
}

class _HomeValueSheet extends StatelessWidget {
  const _HomeValueSheet({
    required this.data,
    this.onOpenTransactions,
  });
  final HomeValueExplanation data;
  final VoidCallback? onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(b);
    return ValueListenableBuilder<bool>(
      valueListenable: FinancialPrivacy.hidden,
      builder: (context, hidden, _) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .80,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text('me explica esse valor',
                    style: AppTypography.section(context, fontSize: 20))),
                  IconButton(
                    tooltip: 'fechar explicação',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close)),
                ]),
                Expanded(child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.title,
                        style: AppTypography.label(context, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text(hidden ? FinancialPrivacy.maskMoney()
                          : homeValueAmount(data.amount),
                        key: const ValueKey('home-explained-value'),
                        style: AppTypography.money(context, fontSize: 29)),
                      const SizedBox(height: 12),
                      Text(data.meaning,
                        style: AppTypography.body(context, fontSize: 13)),
                      const SizedBox(height: 17),
                      Text('de onde veio esse número?',
                        style: AppTypography.label(context,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface(b),
                          borderRadius:
                            BorderRadius.circular(AppRadii.compactCard)),
                        child: Column(children: [
                          for (final line in data.lines)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                              child: Row(children: [
                                Expanded(child: Text(line.label,
                                  style: AppTypography.body(context, fontSize: 12))),
                                const SizedBox(width: 8),
                                Text(hidden ? FinancialPrivacy.maskMoney() :
                                  homeValueAmount(line.amount,
                                    subtract: line.subtract),
                                  style: AppTypography.label(context,
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                              ])),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                            child: Row(children: [
                              Expanded(child: Text('total',
                                style: AppTypography.label(context,
                                  fontSize: 13, fontWeight: FontWeight.w700))),
                              Text(hidden ? FinancialPrivacy.maskMoney() :
                                  homeValueAmount(data.amount),
                                style: AppTypography.money(context, fontSize: 15)),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Text('o que fica de fora?',
                        style: AppTypography.label(context,
                          fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text(data.excluded,
                        style: AppTypography.body(context,
                          fontSize: 12, color: secondary)),
                      const SizedBox(height: 11),
                      Text('Os valores vêm do FÔLEGO. A lista de '
                        'transações é para conferência e pode usar '
                        'datas ou critérios diferentes dos totais.',
                        style: AppTypography.body(context,
                          fontSize: 11, color: secondary)),
                    ]),
                )),
                if (onOpenTransactions != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const ValueKey('home-explain-open-transactions'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenTransactions!();
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('ver as transações'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
