import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';
import '../../data/models/monthly_money_summary.dart';
import '../../data/repositories/folego_repository.dart';
import '../plan/plan_screen_web2.dart' show showBudgetCategorySpending;
import 'financial_analytics_models.dart';

typedef AnalyticsMonthLoader = Future<MonthlyMoneySummary> Function(DateTime month);
typedef AnalyticsCategoryLoader = Future<List<BudgetOverviewItem>> Function(DateTime month);

/// Six complete calendar months; drilldowns keep the backend semantics
/// of purchase-date spending vs competence-based category budgets.
class FinancialAnalyticsScreen extends StatefulWidget {
  const FinancialAnalyticsScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.onOpenTransactions,
    this.monthLoader,
    this.categoryLoader,
    this.referenceDate,
  });

  final FolegoRepository repository;
  final String spaceId;
  final void Function(DateTime month, Set<String> eventTypes)? onOpenTransactions;

  @visibleForTesting
  final AnalyticsMonthLoader? monthLoader;
  @visibleForTesting
  final AnalyticsCategoryLoader? categoryLoader;
  @visibleForTesting
  final DateTime? referenceDate;

  @override
  State<FinancialAnalyticsScreen> createState() => _FinancialAnalyticsScreenState();
}

class _FinancialAnalyticsScreenState extends State<FinancialAnalyticsScreen> {
  late List<DateTime> _months;
  late Future<List<MonthlyMoneySummary>> _history;
  late Future<List<BudgetOverviewItem>> _categories;
  int _selectedIndex = 5;
  int _visibleMonths = 6;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant FinancialAnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.repository != widget.repository ||
        oldWidget.referenceDate != widget.referenceDate) {
      _initialize();
    }
  }

  void _initialize() {
    _months = recentClosedMonths(widget.referenceDate ?? DateTime.now());
    _selectedIndex = _months.length - 1;
    _history = Future.wait(_months.map(_fetchMonth));
    _categories = _fetchCategories(_months[_selectedIndex]);
  }

  Future<MonthlyMoneySummary> _fetchMonth(DateTime month) =>
      widget.monthLoader?.call(month) ??
      widget.repository.getMonthlyMoneySummary(
        spaceId: widget.spaceId, periodMonth: month,
      );

  Future<List<BudgetOverviewItem>> _fetchCategories(DateTime month) =>
      widget.categoryLoader?.call(month) ??
      widget.repository.getBudgetOverview(
        spaceId: widget.spaceId, periodMonth: month,
      );

  void _retry() => setState(_initialize);

  void _select(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _categories = _fetchCategories(_months[index]);
    });
  }

  void _changeRange(int months) {
    setState(() {
      _visibleMonths = months;
      if (_selectedIndex < _months.length - months) {
        _selectedIndex = _months.length - 1;
        _categories = _fetchCategories(_months[_selectedIndex]);
      }
    });
  }

  void _openTransactions(DateTime month, bool income) {
    final handler = widget.onOpenTransactions;
    if (handler == null) return;
    Navigator.of(context).pop();
    handler(month, income
        ? const <String>{'income'}
        : const <String>{
            'expense', 'card_purchase', 'benefit_expense',
            'refund', 'reimbursement',
          });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.fundo,
      appBar: AppBar(
        title: const Text('análises'),
        backgroundColor: tokens.fundo,
        surfaceTintColor: tokens.fundo,
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: FinancialPrivacy.hidden,
          builder: (context, hidden, _) => FutureBuilder<List<MonthlyMoneySummary>>(
            future: _history,
            builder: (context, result) {
              if (result.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (result.hasError || result.data == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Não consegui carregar a evolução agora.',
                          style: AppTypography.body(context, fontSize: 14)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final history = result.data!;
              final series = FinancialAnalyticsSeries(history);
              final selected = history[_selectedIndex];
              return ListView(
                key: const ValueKey('analytics-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                children: [
                  Text('entenda seu dinheiro',
                    style: AppTypography.section(context, fontSize: 23)),
                  const SizedBox(height: 4),
                  Text('Receitas e gastos realizados. Comparação só entre meses encerrados.',
                    style: AppTypography.body(context, fontSize: 12,
                      color: tokens.textoSecundario)),
                  const SizedBox(height: 17),
                  if (hidden)
                    _PrivacyMessage(tokens: tokens)
                  else ...[
                    _surface(tokens, Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('evolução dos últimos meses',
                          style: AppTypography.section(context, fontSize: 16)),
                        const SizedBox(height: 9),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SegmentedButton<int>(
                            key: const ValueKey('analytics-range'),
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                            segments: const [
                              ButtonSegment(value: 3, label: Text('3m')),
                              ButtonSegment(value: 6, label: Text('6m')),
                            ],
                            selected: {_visibleMonths},
                            onSelectionChanged: (values) =>
                                _changeRange(values.first),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _legend(tokens.marca, 'receitas'),
                            _legend(tokens.acao, 'gastos feitos'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _MonthlyComparisonChart(
                          months: history,
                          count: _visibleMonths,
                          selectedIndex: _selectedIndex,
                          maximum: series.maximumActivity,
                          incomeColor: tokens.marca,
                          spendingColor: tokens.acao,
                          onSelect: _select,
                        ),
                      ],
                    )),
                    const SizedBox(height: 16),
                    Text('mês selecionado · ${analyticsMonthLabel(selected.periodMonth)}',
                      key: const ValueKey('analytics-selected-month'),
                      style: AppTypography.section(context, fontSize: 18)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _metric(
                        tokens: tokens,
                        label: 'receitas reais',
                        amount: selected.realIncome,
                        keyName: 'analytics-income',
                        onTap: widget.onOpenTransactions == null ? null :
                            () => _openTransactions(selected.periodMonth, true),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _metric(
                        tokens: tokens,
                        label: 'gastos feitos',
                        amount: selected.spendingMade,
                        keyName: 'analytics-spending',
                        onTap: widget.onOpenTransactions == null ? null :
                            () => _openTransactions(selected.periodMonth, false),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    _surface(tokens, Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('resultado econômico',
                            style: AppTypography.label(context, fontSize: 12,
                                color: tokens.textoSecundario)),
                          const SizedBox(height: 5),
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(Formatters.money(selected.economicResult),
                              key: const ValueKey('analytics-economic-result'),
                              style: AppTypography.money(context, fontSize: 23,
                                color: selected.economicResult < 0
                                    ? tokens.estourado : tokens.textoPrincipal)),
                          ),
                        ],
                      )),
                      Tooltip(
                        message: 'Receitas reais menos despesas por competência. '
                            'Diferente dos gastos feitos pela data de compra.',
                        child: Icon(AppIcons.info, size: 21,
                            color: tokens.textoSecundario),
                      ),
                    ])),
                    const SizedBox(height: 8),
                    Text(
                      'Gastos feitos seguem a data da compra; o resultado econômico '
                      'considera as despesas por competência, incluindo parcelas. '
                      'Por isso, os valores não precisam coincidir.',
                      style: AppTypography.body(context, fontSize: 11,
                        color: tokens.textoSecundario),
                    ),
                    const SizedBox(height: 18),
                    Text('categorias · competência',
                      style: AppTypography.section(context, fontSize: 18)),
                    const SizedBox(height: 5),
                    Text(
                      'Participação das categorias nos gastos de competência '
                      'do mês selecionado. Sem contar subcategorias duas vezes.',
                      style: AppTypography.body(context, fontSize: 11,
                        color: tokens.textoSecundario),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<BudgetOverviewItem>>(
                      future: _categories,
                      builder: (context, categoryResult) {
                        if (categoryResult.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(18),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (categoryResult.hasError || categoryResult.data == null) {
                          return OutlinedButton.icon(
                            key: const ValueKey('analytics-retry-categories'),
                            onPressed: () => setState(
                              () => _categories = _fetchCategories(_months[_selectedIndex]),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('recarregar categorias'),
                          );
                        }
                        final categories = FinancialAnalyticsSeries.parentCategories(
                          categoryResult.data!,
                        );
                        if (categories.isEmpty) {
                          return _surface(tokens, Text(
                            'Sem gastos por categoria neste mês.',
                            style: AppTypography.body(context, fontSize: 12),
                          ));
                        }
                        final total = categories.fold<double>(
                          0, (sum, category) => sum + category.actualAmount,
                        );
                        return _surface(tokens, Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final category in categories.take(8)) ...[
                              _categoryRow(
                                tokens: tokens,
                                category: category,
                                total: total,
                                periodMonth: selected.periodMonth,
                              ),
                              const SizedBox(height: 9),
                            ],
                            if (categories.length > 8)
                              Text(
                                'Mostrando 8 de ${categories.length} categorias.',
                                style: AppTypography.label(context, fontSize: 11,
                                  color: tokens.textoSecundario),
                              ),
                          ],
                        ));
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _surface(FolegoColorTokens tokens, Widget child) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: tokens.superficie,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: tokens.borda),
    ),
    child: child,
  );

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 9, height: 9,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label, style: AppTypography.label(context, fontSize: 11)),
    ],
  );

  Widget _metric({
    required FolegoColorTokens tokens,
    required String label,
    required double amount,
    required String keyName,
    VoidCallback? onTap,
  }) => Material(
    color: tokens.superficie,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        key: ValueKey(keyName),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: tokens.borda),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.label(context,
                fontSize: 11, color: tokens.textoSecundario)),
            const SizedBox(height: 5),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(Formatters.money(amount),
                style: AppTypography.money(context, fontSize: 19)),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 7),
              Text('ver lançamentos',
                style: AppTypography.label(context, fontSize: 10,
                  color: tokens.marca)),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _categoryRow({
    required FolegoColorTokens tokens,
    required BudgetOverviewItem category,
    required double total,
    required DateTime periodMonth,
  }) {
    final share = total > 0
        ? (category.actualAmount / total).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return InkWell(
      key: ValueKey('analytics-category-${category.categoryId}'),
      borderRadius: BorderRadius.circular(11),
      onTap: () => showBudgetCategorySpending(
        context: context,
        repository: widget.repository,
        spaceId: widget.spaceId,
        month: periodMonth,
        category: category,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(category.categoryName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTypography.body(context, fontSize: 13,
                  fontWeight: FontWeight.w600))),
              const SizedBox(width: 7),
              Text(Formatters.money(category.actualAmount),
                style: AppTypography.money(context, fontSize: 13)),
              const SizedBox(width: 3),
              Icon(AppIcons.chevronRight, size: 16,
                color: tokens.textoSecundario),
            ]),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 5,
                color: tokens.marca,
                backgroundColor: tokens.borda,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyMessage extends StatelessWidget {
  const _PrivacyMessage({required this.tokens});
  final FolegoColorTokens tokens;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('analytics-privacy'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: tokens.superficie,
      border: Border.all(color: tokens.borda),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(children: [
      Icon(AppIcons.eyeOff, color: tokens.textoSecundario),
      const SizedBox(width: 12),
      Expanded(child: Text(
        'Valores ocultos. Use o olho na Home para ver os gráficos.',
        style: AppTypography.body(context, fontSize: 12),
      )),
    ]),
  );
}

class _MonthlyComparisonChart extends StatelessWidget {
  const _MonthlyComparisonChart({
    required this.months,
    required this.count,
    required this.selectedIndex,
    required this.maximum,
    required this.incomeColor,
    required this.spendingColor,
    required this.onSelect,
  });

  final List<MonthlyMoneySummary> months;
  final int count;
  final int selectedIndex;
  final double maximum;
  final Color incomeColor;
  final Color spendingColor;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    final first = months.length - count;
    final scale = maximum <= 0 ? 1.0 : maximum;
    return SizedBox(
      height: 175,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = first; index < months.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: index == selectedIndex,
                label: '${analyticsMonthLabel(months[index].periodMonth)}: '
                    'receitas ${Formatters.money(months[index].realIncome)}, '
                    'gastos ${Formatters.money(months[index].spendingMade)}',
                child: InkWell(
                  key: ValueKey('analytics-month-$index'),
                  onTap: () => onSelect(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.fromLTRB(3, 8, 3, 6),
                    decoration: BoxDecoration(
                      color: index == selectedIndex
                          ? tokens.marca.withValues(alpha: .07) : null,
                      borderRadius: BorderRadius.circular(10),
                      border: index == selectedIndex
                          ? Border.all(color: tokens.marca.withValues(alpha: .25))
                          : null,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _bar(months[index].realIncome, scale, incomeColor),
                              const SizedBox(width: 3),
                              _bar(months[index].spendingMade, scale, spendingColor),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            analyticsMonthLabel(months[index].periodMonth)
                                .split('/').first,
                            style: AppTypography.label(context, fontSize: 11,
                              fontWeight: index == selectedIndex
                                  ? FontWeight.w800 : FontWeight.w500,
                              color: index == selectedIndex
                                  ? tokens.marca : tokens.textoSecundario),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(double value, double scale, Color color) {
    final ratio = (value / scale).clamp(0.0, 1.0).toDouble();
    return Expanded(
      child: FractionallySizedBox(
        heightFactor: ratio,
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(5)),
          ),
        ),
      ),
    );
  }
}
