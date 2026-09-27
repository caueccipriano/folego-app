import 'package:flutter/material.dart';
import '../core/intelligence/financial_report_builder.dart';
import '../core/intelligence/financial_insights_service.dart';

/// Componente isolado: a tela existente pode incorporá-lo sem mudar a navegação.
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
          return const Card(child: ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Analisando seu mês…'),
          ));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Card(child: ListTile(
            title: const Text('Não foi possível carregar a análise'),
            subtitle: const Text('Seus lançamentos não foram alterados.'),
            trailing: IconButton(
              tooltip: 'Tentar novamente',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(_load),
            ),
          ));
        }
        final report = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seu mês em perspectiva',
                  style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...report.insights.map((insight) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(insight.title),
                  subtitle: Text(insight.description),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}
