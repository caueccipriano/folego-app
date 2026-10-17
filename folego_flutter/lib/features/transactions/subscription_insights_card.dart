import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/recurring_item.dart';
import '../../data/models/subscription_insights.dart';

class SubscriptionInsightsCard extends StatefulWidget {
  const SubscriptionInsightsCard({super.key, required this.items, required this.onEdit, this.load});
  final List<RecurringItem> items;
  final Future<List<SubscriptionCharge>> Function()? load;
  final Future<void> Function(RecurringItem) onEdit;
  @override
  State<SubscriptionInsightsCard> createState() => _SubscriptionInsightsCardState();
}

class _SubscriptionInsightsCardState extends State<SubscriptionInsightsCard> {
  late Future<List<SubscriptionCharge>> _history;
  String _scope(List<RecurringItem> items) => items.map((i) => '${i.spaceId}/${i.id}').join('|');
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void didUpdateWidget(covariant SubscriptionInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_scope(oldWidget.items) != _scope(widget.items)) { _reload(); }
  }
  void _reload() { _history = widget.load?.call() ?? Future.value(const []); }
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: FinancialPrivacy.hidden,
    builder: (context, hidden, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('conferência de assinaturas', style: Theme.of(context).textTheme.titleMedium),
            for (final insight in duplicateSubscriptionInsights(widget.items)) ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(insight.item.name), subtitle: Text(insight.message),
              onTap: () => widget.onEdit(insight.item),
            ),
            FutureBuilder<List<SubscriptionCharge>>(
              future: _history,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
                }
                if (snapshot.hasError || widget.load == null) {
                  return const Text('histórico de cobranças indisponível. Isso não significa ausência de reajustes.');
                }
                final charges = snapshot.data ?? const <SubscriptionCharge>[];
                final changes = changedSubscriptionInsights(widget.items, charges);
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (changes.isEmpty) const Text('nenhuma mudança identificada nas cobranças comparáveis desta consulta'),
                  for (final insight in changes) ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(insight.item.name),
                    subtitle: Text('${insight.message}\n${_amounts(charges, insight.item.id)}'),
                    onTap: () => widget.onEdit(insight.item),
                  ),
                  Text('${charges.length} cobranças realizadas consultadas, até 200. A comparação exige dois ciclos vinculados à mesma assinatura. Cobranças sem esse vínculo e fora da consulta não são analisadas.'),
                ]);
              },
            ),
            TextButton(onPressed: () => setState(_reload), child: const Text('conferir cobranças novamente')),
            const Text('São alertas para revisão. Nenhum cadastro é encerrado ou cobrança excluída automaticamente.'),
          ],
        ),
      ),
    ),
  );

  String _amounts(List<SubscriptionCharge> charges, String id) {
    final sorted = charges.where((c) => c.recurringId == id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (sorted.isEmpty) { return ''; }
    final latest = sorted.first;
    final previous = sorted.where((c) => c.date.isBefore(latest.date)).firstOrNull;
    if (previous == null) { return ''; }
    return '${Formatters.fullDate.format(previous.date)}: ${Formatters.money(previous.amount)} → ${Formatters.fullDate.format(latest.date)}: ${Formatters.money(latest.amount)}';
  }
}
