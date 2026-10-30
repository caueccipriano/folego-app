import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_budget.dart';

/// Compare equal calendar-day windows, including in February and short months.
int comparableMonthDays(DateTime today) =>
    math.min(today.day, DateTime(today.year, today.month, 0).day);

double budgetThroughDay(
  Iterable<BudgetImpactDetail> rows,
  DateTime month,
  int day,
) {
  final seen = <String>{};
  var total = 0.0;
  for (final row in rows) {
    final date = row.effectiveDate;
    if (date.year == month.year &&
        date.month == month.month &&
        date.day <= day &&
        row.budgetAmount.isFinite &&
        seen.add(row.impactId)) {
      total += row.budgetAmount;
    }
  }
  return total;
}

class CategoryPeriodComparison extends StatefulWidget {
  const CategoryPeriodComparison({
    super.key,
    required this.repository,
    required this.spaceId,
  });
  final FolegoRepository repository;
  final String spaceId;
  @override
  State<CategoryPeriodComparison> createState() =>
      _CategoryPeriodComparisonState();
}

class _CategoryPeriodComparisonState extends State<CategoryPeriodComparison> {
  late Future<List<(String, double, double)>> _future;
  late DateTime _today;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _today = DateTime.now();
    _future = _load();
  }

  Future<List<(String, double, double)>> _load() async {
    final current = DateTime(_today.year, _today.month);
    final previous = DateTime(_today.year, _today.month - 1);
    final days = comparableMonthDays(_today);
    final months = await Future.wait([
      widget.repository.getBudgetOverview(
        spaceId: widget.spaceId,
        periodMonth: current,
      ),
      widget.repository.getBudgetOverview(
        spaceId: widget.spaceId,
        periodMonth: previous,
      ),
    ]);
    final parents = <String, BudgetOverviewItem>{};
    for (final month in months) {
      for (final item in month.where(
        (item) => item.isParent && !item.isPending,
      )) {
        parents[item.categoryId] = item;
      }
    }
    final result = <(String, double, double)>[];
    // Three parent categories at a time: at most six independent RPCs.
    final categories = parents.values.toList();
    for (var offset = 0; offset < categories.length; offset += 3) {
      if (!mounted) return [];
      final batch = categories.skip(offset).take(3);
      final values = await Future.wait(
        batch.map((parent) async {
          final rows = await Future.wait([
            widget.repository.getBudgetImpactDetails(
              spaceId: widget.spaceId,
              periodMonth: current,
              categoryId: parent.categoryId,
            ),
            widget.repository.getBudgetImpactDetails(
              spaceId: widget.spaceId,
              periodMonth: previous,
              categoryId: parent.categoryId,
            ),
          ]);
          return (
            parent.categoryName,
            budgetThroughDay(rows[0], current, days),
            budgetThroughDay(rows[1], previous, days),
          );
        }),
      );
      result.addAll(values.where((row) => row.$2 != 0 || row.$3 != 0));
    }
    result.sort((a, b) => (b.$2 - b.$3).abs().compareTo((a.$2 - a.$3).abs()));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final days = comparableMonthDays(_today);
    final before = DateTime(_today.year, _today.month - 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'seu ritmo por categoria',
          style: AppTypography.section(context, fontSize: 16),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: FutureBuilder<List<(String, double, double)>>(
            future: _future,
            builder: (context, state) {
              if (state.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(_reload),
                    child: const Text(
                      'não consegui comparar. tentar novamente',
                    ),
                  ),
                );
              }
              if (!state.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = state.data!;
              final increases = rows.where((row) => row.$2 > row.$3).toList()
                ..sort((a, b) => (b.$2 - b.$3).compareTo(a.$2 - a.$3));
              final largestIncrease = increases.isEmpty ? null : increases.first;
              final maximum = rows.fold<double>(
                0,
                (value, row) => math.max(value, math.max(row.$2, row.$3)),
              );
              return ValueListenableBuilder<bool>(
                valueListenable: FinancialPrivacy.hidden,
                builder: (context, hidden, _) => ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'dias 1 a $days · ${Formatters.monthYear.format(_today)} × ${Formatters.monthYear.format(before)}',
                      style: AppTypography.body(
                        context,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mesmo período, meses diferentes. Comparação dos gastos registrados, não previsão.',
                      style: AppTypography.body(context, fontSize: 12),
                    ),
                    if (largestIncrease != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        key: const ValueKey('category-biggest-increase'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface(Theme.of(context).brightness),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border(Theme.of(context).brightness),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('maior alta registrada',
                              style: AppTypography.label(context, fontSize: 12)),
                            const SizedBox(height: 5),
                            Text(largestIncrease.$1,
                              style: AppTypography.section(context, fontSize: 17)),
                            const SizedBox(height: 4),
                            Text(
                              hidden
                                ? 'R\$ •••• a mais'
                                : '${Formatters.money(largestIncrease.$2 - largestIncrease.$3)} a mais',
                              style: AppTypography.body(
                                context, fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('até o dia $days, conforme os registros.',
                              style: AppTypography.body(context, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: AppColors.transparent,
                      ),
                      child: ExpansionTile(
                        key: const ValueKey('category-compare-explainer'),
                        tilePadding: EdgeInsets.zero,
                        title: const Text('como comparamos'),
                        children: const [
                          Text('Mesmo número de dias nos dois meses, pela data de impacto no orçamento. Parcelas entram no mês da parcela; estornos reduzem gastos e pagamentos de fatura não são somados duas vezes.'),
                          SizedBox(height: 8),
                          Text('O dia de hoje pode estar incompleto. Meses curtos limitam a janela. Sem registros não significa gasto zero; lançamentos sem categoria ficam fora do detalhamento.'),
                          SizedBox(height: 8),
                          Text('Primeira barra: mês atual. Segunda: mês anterior. Créditos líquidos negativos aparecem no valor, sem barra.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      const Text(
                        'ainda não há categorias com atividade para comparar.',
                      ),
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.$1,
                              style: AppTypography.body(
                                context,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              hidden
                                  ? '••••'
                                  : 'agora ${Formatters.money(row.$2)} · antes ${Formatters.money(row.$3)}',
                            ),
                            Text(
                              hidden
                                  ? 'variação oculta'
                                  : '${row.$2 >= row.$3 ? 'a mais' : 'a menos'}: ${Formatters.money((row.$2 - row.$3).abs())}${row.$3 > 0 ? ' (${((row.$2 - row.$3) / row.$3 * 100).toStringAsFixed(1)}%)' : ' · sem base positiva para percentual'}',
                            ),
                            if (!hidden &&
                                row.$2 >= 0 &&
                                row.$3 >= 0 &&
                                math.max(row.$2, row.$3) > 0) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: row.$2 / maximum,
                                color: AppColors.primaryPurple(
                                  Theme.of(context).brightness,
                                ),
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: row.$3 / maximum,
                                color: AppColors.secondaryText(
                                  Theme.of(context).brightness,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
