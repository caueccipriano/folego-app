import 'package:flutter/material.dart';
import '../core/intelligence/financial_report_builder.dart';
import '../core/intelligence/financial_insights_service.dart';

/// Resumo compacto na Home: explicações ficam disponíveis sob demanda.
class MonthlyInsightsCard extends StatefulWidget {
  const MonthlyInsightsCard({
    super.key,
    required this.service,
    required this.spaceId,
    required this.month,
  });
  final FinancialInsightsService service;
  final String spaceId;
  final DateTime month;

  @override
  State<MonthlyInsightsCard> createState() => _MonthlyInsightsCardState();
}

class _MonthlyInsightsCardState extends State<MonthlyInsightsCard> {
  late Future<MonthlyIntelligenceReport> _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MonthlyInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _load();
    }
  }

  void _load() {
    _report = widget.service.monthly(
      spaceId: widget.spaceId,
      month: widget.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MonthlyIntelligenceReport>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: ListTile(
              leading: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Analisando seu mês…'),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            child: ListTile(
              title: const Text('Análise indisponível'),
              subtitle: const Text('Seus lançamentos não foram alterados.'),
              trailing: IconButton(
                tooltip: 'Tentar novamente',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(_load),
              ),
            ),
          );
        }

        final insights = snapshot.data!.insights.toList();
        if (insights.isEmpty) {
          return const Card(
            child: ListTile(
              title: Text('Seu mês em perspectiva'),
              subtitle: Text('Sem observações novas por enquanto.'),
            ),
          );
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: ValueKey('monthly-insights-${widget.spaceId}-${widget.month.year}-${widget.month.month}'),
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            title: Text(
              'Seu mês em perspectiva',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                insights.first.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            trailing: const Icon(Icons.expand_more),
            children: [
              for (final insight in insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(insight.title,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(insight.description,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
