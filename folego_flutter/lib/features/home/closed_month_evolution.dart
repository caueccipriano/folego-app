import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/monthly_money_summary.dart';
import '../../data/repositories/folego_repository.dart';

/// Only compare CLOSED calendar months. Comparing the current partial month
/// with an entire previous month would suggest a misleading trend.
class ClosedMonthEvolution {
  const ClosedMonthEvolution({
    required this.latest,
    required this.previous,
  });

  final MonthlyMoneySummary latest;
  final MonthlyMoneySummary previous;

  double get spendingChange => latest.spendingMade - previous.spendingMade;
  double get incomeChange => latest.realIncome - previous.realIncome;
  double get resultChange => latest.economicResult - previous.economicResult;
  double? get spendingPercent => previous.spendingMade.abs() < .005
      ? null
      : spendingChange / previous.spendingMade.abs() * 100;
}

String _monthName(DateTime date) {
  const months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  return '${months[date.month - 1]}/${date.year}';
}

Future<void> showClosedMonthEvolution(
  BuildContext context, {
  required FolegoRepository repository,
  required String spaceId,
}) async {
  final today = DateTime.now();
  final latestClosed = DateTime(today.year, today.month - 1, 1);
  final previousClosed = DateTime(today.year, today.month - 2, 1);
  final result = Future.wait<MonthlyMoneySummary>([
    repository.getMonthlyMoneySummary(
      spaceId: spaceId, periodMonth: latestClosed,
    ),
    repository.getMonthlyMoneySummary(
      spaceId: spaceId, periodMonth: previousClosed,
    ),
  ]);
  final brightness = Theme.of(context).brightness;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background(brightness),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadii.sheet),
      ),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: .76,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'sua evolução',
                      style: AppTypography.section(context, fontSize: 20),
                    ),
                  ),
                  IconButton(
                    tooltip: 'fechar evolução',
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'comparação entre meses já encerrados, sem misturar o mês atual',
                style: AppTypography.body(
                  context, fontSize: 12,
                  color: AppColors.secondaryText(brightness),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: FutureBuilder<List<MonthlyMoneySummary>>(
                  future: result,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData && !snapshot.hasError) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'não consegui buscar os meses fechados. tente novamente mais tarde.',
                          style: AppTypography.body(context),
                        ),
                      );
                    }
                    final rows = snapshot.data!;
                    return _EvolutionSummary(
                      evolution: ClosedMonthEvolution(
                        latest: rows[0], previous: rows[1],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EvolutionSummary extends StatelessWidget {
  const _EvolutionSummary({required this.evolution});
  final ClosedMonthEvolution evolution;

  @override
  Widget build(BuildContext context) {
    final latest = evolution.latest;
    final previous = evolution.previous;
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_monthName(latest.periodMonth)} × ${_monthName(previous.periodMonth)}',
            style: AppTypography.label(
              context, fontSize: 12, fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _TrendRow(
                  title: 'gastos feitos',
                  recent: latest.spendingMade,
                  previous: previous.spendingMade,
                  change: evolution.spendingChange,
                  percent: evolution.spendingPercent,
                  isExpense: true,
                ),
                Divider(height: 1, color: border),
                _TrendRow(
                  title: 'receitas reais',
                  recent: latest.realIncome,
                  previous: previous.realIncome,
                  change: evolution.incomeChange,
                ),
                Divider(height: 1, color: border),
                _TrendRow(
                  title: 'resultado econômico',
                  recent: latest.economicResult,
                  previous: previous.economicResult,
                  change: evolution.resultChange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Gastos são contados pela data da compra. Resultado econômico usa o mês de competência. '
            'Transferências e pagamentos de fatura não são somados como novas despesas.',
            style: AppTypography.body(
              context, fontSize: 11, color: secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.title,
    required this.recent,
    required this.previous,
    required this.change,
    this.percent,
    this.isExpense = false,
  });

  final String title;
  final double recent;
  final double previous;
  final double change;
  final double? percent;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final improving = isExpense ? change < 0 : change > 0;
    final trendColor = change.abs() < .005
        ? secondary
        : (improving
            ? AppColors.positiveText(brightness)
            : AppColors.expenseText(brightness));
    final changeLabel = change.abs() < .005
        ? 'sem variação'
        : '${change > 0 ? "+" : "−"}${Formatters.money(change.abs())}';
    final percentLabel = percent == null
        ? ''
        : ' (${percent! > 0 ? "+" : ""}${percent!.toStringAsFixed(1)}%)';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.body(
            context, fontSize: 13, fontWeight: FontWeight.w700, color: primary,
          )),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  'mais recente: ${Formatters.money(recent)}',
                  style: AppTypography.body(context, fontSize: 11, color: secondary),
                ),
              ),
              Expanded(
                child: Text(
                  'anterior: ${Formatters.money(previous)}',
                  style: AppTypography.body(context, fontSize: 11, color: secondary),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'variação: $changeLabel$percentLabel',
            style: AppTypography.body(
              context, fontSize: 12, fontWeight: FontWeight.w700,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}
