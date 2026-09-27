import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/intelligence/financial_insights_service.dart';
import '../core/intelligence/weekly_report_builder.dart';

class WeeklyInsightsCard extends StatefulWidget {
  const WeeklyInsightsCard({super.key, required this.service, required this.spaceId});
  final FinancialInsightsService service;
  final String spaceId;
  @override
  State<WeeklyInsightsCard> createState() => _WeeklyInsightsCardState();
}

class _WeeklyInsightsCardState extends State<WeeklyInsightsCard> {
  late Future<WeeklyFinanceReport> _report;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant WeeklyInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) _load();
  }
  void _load() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    _report = widget.service.weekly(
      spaceId: widget.spaceId,
      weekStart: monday.subtract(const Duration(days: 7)),
      asOf: now,
    );
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<WeeklyFinanceReport>(
    future: _report,
    builder: (context, snapshot) {
      final english = Localizations.localeOf(context).languageCode == 'en';
      if (!snapshot.hasData) {
        if (snapshot.hasError) {
          return Card(child: ListTile(
            title: Text(english ? 'Weekly summary unavailable' : 'Resumo semanal indisponível'),
            trailing: IconButton(
              tooltip: english ? 'Try again' : 'Tentar novamente',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(_load),
            ),
          ));
        }
        return Card(child: ListTile(
          title: Text(english ? 'Preparing your weekly summary…' : 'Preparando seu resumo semanal…'),
          leading: const CircularProgressIndicator(),
        ));
      }
      final report = snapshot.data!;
      final money = NumberFormat.currency(
        locale: english ? 'en_US' : 'pt_BR',
        symbol: english ? r'$' : r'R$',
      );
      final percentage = NumberFormat.decimalPatternDigits(
        locale: english ? 'en_US' : 'pt_BR', decimalDigits: 1,
      );
      final patterns = report.patterns
          .where((pattern) => pattern.previous > 0 &&
              pattern.variationPercent.abs() >= 5).toList()
        ..sort((a, b) => b.variationPercent.abs()
            .compareTo(a.variationPercent.abs()));
      return Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(english ? 'Last completed week' : 'Última semana concluída',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            _WeeklyMetric(label: english ? 'Income' : 'Receitas', amount: money.format(report.income)),
            _WeeklyMetric(label: english ? 'Expenses' : 'Despesas', amount: money.format(report.expenses)),
          ]),
          if (!report.comparedWithPreviousWeek)
            Text(english
                ? 'The comparison appears when the current week ends.'
                : 'A comparação aparece quando a semana atual terminar.'),
          for (final pattern in patterns.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(pattern.category),
              subtitle: Text(english
                  ? '${pattern.variationPercent > 0 ? 'Up' : 'Down'} ${percentage.format(pattern.variationPercent.abs())}% vs. the previous week.'
                  : '${pattern.variationPercent > 0 ? 'Aumento' : 'Redução'} de ${percentage.format(pattern.variationPercent.abs())}% em relação à semana anterior.'),
            ),
        ]),
      ));
    },
  );
}

class _WeeklyMetric extends StatelessWidget {
  const _WeeklyMetric({required this.label, required this.amount});
  final String label;
  final String amount;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 125),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 3),
      Text(amount, style: Theme.of(context).textTheme.titleMedium),
    ]),
  );
}
