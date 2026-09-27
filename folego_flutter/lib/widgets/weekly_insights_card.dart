import 'package:flutter/material.dart';
import '../core/intelligence/financial_insights_service.dart';
import '../core/intelligence/weekly_report_builder.dart';

class WeeklyInsightsCard extends StatefulWidget {
  const WeeklyInsightsCard({
    super.key, required this.service, required this.spaceId,
  });
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
      spaceId: widget.spaceId, weekStart: monday.subtract(const Duration(days: 7)), asOf: now);
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeeklyFinanceReport>(
      future: _report,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Card(child: ListTile(
              title: const Text('Resumo semanal indisponível'),
              trailing: IconButton(
                tooltip: 'Tentar novamente',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(_load),
              ),
            ));
          }
          return const Card(child: ListTile(
            title: Text('Preparando seu resumo semanal…'),
            leading: CircularProgressIndicator(),
          ));
        }
        final report = snapshot.data!;
        final patterns = report.patterns
            .where((pattern) => pattern.previous > 0 &&
                pattern.variationPercent.abs() >= 5).toList()
          ..sort((a, b) => b.variationPercent.abs()
              .compareTo(a.variationPercent.abs()));
        return Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Última semana concluída', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Receitas: R\$ ${report.income.toStringAsFixed(2)}'),
            Text('Despesas: R\$ ${report.expenses.toStringAsFixed(2)}'),
            if (!report.comparedWithPreviousWeek)
              const Text('Semana em andamento: a comparação aparece quando ela terminar.'),
            for (final pattern in patterns.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(pattern.category),
                subtitle: Text('${pattern.variationPercent > 0 ? 'Aumento' : 'Redução'} de ${pattern.variationPercent.abs().toStringAsFixed(1)}% em relação à semana anterior.'),
              ),
          ]),
        ));
      },
    );
  }
}
