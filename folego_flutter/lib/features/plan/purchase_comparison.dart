import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/privacy/financial_privacy.dart';
import '../../data/models/projection_model.dart';

class PurchaseOption {
  const PurchaseOption({
    required this.name,
    required this.adjustments,
    required this.totalCents,
  });
  final String name;
  final List<ProjectionAdjustment> adjustments;
  final int totalCents;
}

List<PurchaseOption> buildPurchaseOptions({
  required String name,
  required int cashCents,
  required int installmentCents,
  required int payments,
  required DateTime firstPayment,
  int delayMonths = 1,
  String? categoryId,
  String? categoryName,
}) {
  if (delayMonths < 1 || delayMonths > 24) throw ArgumentError('invalid_delay');
  final targetMonth = DateTime(
    firstPayment.year,
    firstPayment.month + delayMonths,
  );
  final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
  final delayed = DateTime(
    targetMonth.year,
    targetMonth.month,
    firstPayment.day.clamp(1, lastDay),
  );
  List<ProjectionAdjustment> build(
    String id,
    int total,
    int count,
    DateTime date,
  ) => buildPurchaseSimulation(
    id: id,
    name: name,
    totalCents: total,
    payments: count,
    firstPayment: date,
    categoryId: categoryId,
    categoryName: categoryName,
  );
  return [
    PurchaseOption(
      name: 'à vista agora',
      totalCents: cashCents,
      adjustments: build('compare-cash', cashCents, 1, firstPayment),
    ),
    PurchaseOption(
      name: 'parcelar em ${payments}x',
      totalCents: installmentCents,
      adjustments: build(
        'compare-installment',
        installmentCents,
        payments,
        firstPayment,
      ),
    ),
    PurchaseOption(
      name: 'adiar $delayMonths mês(es)',
      totalCents: cashCents,
      adjustments: build('compare-later', cashCents, 1, delayed),
    ),
  ];
}

/// Exact cents still scheduled after the displayed projection horizon.
int purchaseCentsBeyondHorizon(PurchaseOption option, DateTime lastMonth) {
  final boundary = DateTime(lastMonth.year, lastMonth.month + 1);
  var cents = 0;
  for (final change in option.adjustments) {
    if (change.frequency == 'once') {
      if (!DateTime(change.startsOn.year, change.startsOn.month).isBefore(boundary)) {
        cents += (change.amountDelta * 100).round();
      }
    } else if (change.frequency == 'monthly' && change.endsOn != null) {
      var month = DateTime(change.startsOn.year, change.startsOn.month);
      final end = DateTime(change.endsOn!.year, change.endsOn!.month);
      while (!month.isAfter(end)) {
        if (!month.isBefore(boundary)) { cents += (change.amountDelta * 100).round(); }
        month = DateTime(month.year, month.month + 1);
      }
    }
  }
  return cents;
}

class PurchaseComparisonDialog extends StatefulWidget {
  const PurchaseComparisonDialog({
    super.key,
    required this.options,
    required this.load,
    required this.horizonMonths,
  });
  final List<PurchaseOption> options;
  final Future<ProjectionResult> Function(List<ProjectionAdjustment>) load;
  final int horizonMonths;
  @override
  State<PurchaseComparisonDialog> createState() =>
      _PurchaseComparisonDialogState();
}

class _PurchaseComparisonDialogState extends State<PurchaseComparisonDialog> {
  late Future<List<ProjectionResult>> _results;
  @override
  void initState() {
    super.initState();
    _results = _load();
  }

  Future<List<ProjectionResult>> _load() => Future.wait([
    widget.load(const []),
    ...widget.options.map((o) => widget.load(o.adjustments)),
  ]);
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: FinancialPrivacy.hidden,
    builder: (context, hidden, _) => AlertDialog(
    title: const Text('qual cenário cabe melhor?'),
    content: SizedBox(
      width: 760,
      child: SingleChildScrollView(
        child: FutureBuilder<List<ProjectionResult>>(
          future: _results,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Não foi possível comparar todos os cenários. Nenhum lançamento foi criado.',
                  ),
                  TextButton(
                    onPressed: () => setState(() => _results = _load()),
                    child: const Text('tentar novamente'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final base = snapshot.data!.first;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Horizonte: ${widget.horizonMonths} meses. Sem a compra, o menor saldo projetado é ${hidden ? '••••' : Formatters.money(base.summary.minimumBalance)}.',
                ),
                const Text(
                  'Comparação com os compromissos conhecidos. Não inclui juros futuros ou novas despesas ainda não registradas. Adiar mantém o preço à vista informado.',
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < widget.options.length; i++)
                  _option(widget.options[i], snapshot.data![i + 1], base, hidden),
                const Text(
                  'Parcelas além do horizonte continuam devidas, mesmo quando não aparecem no saldo final. Escolher um cenário altera apenas a simulação.',
                ),
              ],
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('voltar'),
      ),
    ],
    ),
  );
  Widget _option(PurchaseOption option, ProjectionResult result, ProjectionResult base, bool hidden) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(option.name, style: Theme.of(context).textTheme.titleMedium),
          Text('total: ${hidden ? '••••' : Formatters.money(option.totalCents / 100)}'),
          Text('diferença de preço frente à opção à vista: ${hidden ? '••••' : Formatters.money((option.totalCents - widget.options.first.totalCents) / 100)}'),
          Text('mudança no menor saldo frente a não comprar: ${hidden ? '••••' : Formatters.money(result.summary.minimumBalance - base.summary.minimumBalance)}'),
          Text('meses com saldo negativo neste horizonte: ${hidden ? '••••' : result.months.where((month) => month.isCritical).length}'),
          if (result.months.isNotEmpty)
            Text('pagamentos depois do horizonte: ${hidden ? '••••' : Formatters.money(purchaseCentsBeyondHorizon(option, result.months.last.month) / 100)}'),
          Text(
            'menor saldo: ${hidden ? '••••' : Formatters.money(result.summary.minimumBalance)}',
          ),
          Text(
            'saldo final: ${hidden ? '••••' : Formatters.money(result.summary.endingBalance)}',
          ),
          Text(
            result.summary.criticalMonth == null
                ? 'sem mês crítico projetado neste horizonte'
                : 'primeiro mês crítico: ${Formatters.fullDate.format(result.summary.criticalMonth!)}',
          ),
          Text(
            'primeiro pagamento: ${Formatters.fullDate.format(option.adjustments.first.startsOn)}',
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, option.adjustments),
            child: const Text('usar este cenário'),
          ),
        ],
      ),
    ),
  );
}
