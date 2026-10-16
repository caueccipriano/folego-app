import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/monthly_money_summary.dart';

/// A manual, read-only month review. Never marks transactions as paid,
/// writes a backend "closed" flag, or mutates a financial space.
class MonthlyClosingReview extends StatefulWidget {
  const MonthlyClosingReview({super.key, required this.summary,
    this.onReviewAccounts, this.onReviewCategories, this.onReviewBehavior});

  final Future<void> Function()? onReviewAccounts;
  final Future<void> Function()? onReviewCategories;
  final Future<void> Function()? onReviewBehavior;

  final MonthlyMoneySummary summary;

  @override
  State<MonthlyClosingReview> createState() => _MonthlyClosingReviewState();
}

class _MonthlyClosingReviewState extends State<MonthlyClosingReview> {
  final List<bool> _checked = [false, false, false];
  bool _opening = false;

  Future<void> _open(Future<void> Function() action) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await action();
    } catch (_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('não consegui abrir a conferência. tente novamente.')));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  static const _steps = [
    (
      'conferi meus lançamentos',
      'revise o extrato e confira se compras e entradas estão registradas',
    ),
    (
      'conferi cartões e faturas',
      'compare parcelas, vencimentos e pagamentos com seus comprovantes',
    ),
    (
      'conferi minhas categorias',
      'revise o planejamento e classifique eventuais pendências',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final summary = widget.summary;
    final complete = _checked.every((value) => value);

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            Expanded(child: Text('fechamento guiado', style: AppTypography.section(context, fontSize: 16))),
            IconButton(key: const ValueKey('monthly-close-dismiss'), tooltip: 'fechar revisão', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
          ])),
          Expanded(
            child: ListView(
              key: const ValueKey('monthly-close-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Text('seu mês, revisado.',
                    style: AppTypography.display(
                        context, fontSize: 28, color: ink)),
                const SizedBox(height: 6),
                Text(
                  'revisão de ${Formatters.monthYear.format(summary.periodMonth)}',
                  style: AppTypography.body(context, fontSize: 13, color: secondary),
                ),
                const SizedBox(height: 12),
                Text(
                  'estes valores vêm dos seus registros. o mês pode mudar '
                  'com lançamentos ou ajustes posteriores.',
                  style: AppTypography.body(context, fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<bool>(
                  valueListenable: FinancialPrivacy.hidden,
                  builder: (context, hidden, child) => Column(
                    children: [
                      _ReviewMetric(
                        label: 'receitas reais',
                        value: Formatters.money(summary.realIncome),
                      ),
                      _ReviewMetric(
                        label: 'compras e gastos realizados',
                        value: Formatters.money(summary.spendingMade),
                      ),
                      _ReviewMetric(
                        label: 'despesas por competência',
                        value: Formatters.money(summary.competenceExpenses),
                      ),
                      _ReviewMetric(
                        label: 'resultado econômico',
                        value: Formatters.money(summary.economicResult),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (widget.onReviewAccounts != null) OutlinedButton.icon(
                  onPressed: _opening ? null : () => _open(widget.onReviewAccounts!),
                  icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('1 · conferir contas e faturas')),
                if (widget.onReviewCategories != null) OutlinedButton.icon(
                  onPressed: _opening ? null : () => _open(widget.onReviewCategories!),
                  icon: const Icon(Icons.category_outlined), label: const Text('2 · resolver categorias pendentes')),
                if (widget.onReviewBehavior != null) OutlinedButton.icon(
                  onPressed: _opening ? null : () => _open(widget.onReviewBehavior!),
                  icon: const Icon(Icons.tune), label: const Text('3 · revisar fixos e variáveis')),
                if (widget.onReviewBehavior != null) const Text('confira também os gastos sem classificação. esses atalhos não marcam a revisão como concluída; confirme abaixo depois de verificar. categorias pendentes podem incluir outros meses.'),
                Text('antes de encerrar sua revisão',
                    style: AppTypography.section(context, fontSize: 17)),
                const SizedBox(height: 5),
                Text(
                  'marque apenas o que você realmente conferiu. '
                  'essas confirmações valem somente nesta tela.',
                  style: AppTypography.body(context, fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < _steps.length; index++)
                  CheckboxListTile(
                    key: ValueKey('monthly-close-check-$index'),
                    value: _checked[index],
                    onChanged: (value) => setState(() {
                      _checked[index] = value ?? false;
                    }),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _steps[index].$1,
                      style: AppTypography.body(context, fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _steps[index].$2,
                      style: AppTypography.body(context, fontSize: 11,
                          color: secondary),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'não altera faturas, saldos, categorias, contas ou '
                  'o status de fechamento no servidor.',
                  style: AppTypography.body(context, fontSize: 11, color: secondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('monthly-close-done'),
                onPressed: complete
                    ? () {
                        final messenger = ScaffoldMessenger.maybeOf(context);
                        Navigator.of(context).pop();
                        messenger?.showSnackBar(
                          const SnackBar(
                            content: Text('revisão conferida nesta sessão. '
                                'nenhum dado financeiro foi alterado.'),
                          ),
                        );
                      }
                    : null,
                child: const Text('terminei minha conferência'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label,
                style: AppTypography.body(context, fontSize: 12))),
            const SizedBox(width: 12),
            Text(value, style: AppTypography.money(context, fontSize: 15)),
          ],
        ),
      );
}

Future<void> showMonthlyClosingReview(
  BuildContext context, {
  required MonthlyMoneySummary summary,
  Future<void> Function()? onReviewAccounts,
  Future<void> Function()? onReviewCategories,
  Future<void> Function()? onReviewBehavior,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .86,
      child: MonthlyClosingReview(summary: summary, onReviewAccounts: onReviewAccounts, onReviewCategories: onReviewCategories, onReviewBehavior: onReviewBehavior),
    ),
  );
}
