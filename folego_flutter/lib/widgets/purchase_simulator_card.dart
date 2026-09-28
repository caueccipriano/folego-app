import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/intelligence/purchase_scenario_service.dart';

class PurchaseSimulatorCard extends StatefulWidget {
  const PurchaseSimulatorCard({super.key, required this.service, required this.spaceId});
  final PurchaseScenarioService service;
  final String spaceId;
  @override
  State<PurchaseSimulatorCard> createState() => _PurchaseSimulatorCardState();
}

class _PurchaseSimulatorCardState extends State<PurchaseSimulatorCard> {
  final _amount = TextEditingController();
  int _installments = 1;
  bool _busy = false;
  String? _error;
  double? _payment;
  double? _before;
  double? _after;
  DateTime? _firstNegativeMonth;
  bool _hasResult = false;

  bool get _english => Localizations.localeOf(context).languageCode == 'en';
  String _money(double amount) => NumberFormat.currency(
    locale: _english ? 'en_US' : 'pt_BR', symbol: _english ? '\$' : 'R\$',
  ).format(amount);

  @override
  void dispose() { _amount.dispose(); super.dispose(); }

  Future<void> _simulate() async {
    final raw = _amount.text.trim().replaceAll(RegExp(r'[^0-9,.]'), '');
    final normalized = raw.contains(',')
        ? raw.replaceAll('.', '').replaceAll(',', '.')
        : raw;
    final value = double.tryParse(normalized);
    if (value == null || !value.isFinite || value <= 0) {
      setState(() { _error = _english
          ? 'Enter a valid amount, such as 350.00.'
          : 'Digite um valor válido. Exemplo: 350,00'; _hasResult = false; });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; _hasResult = false; });
    try {
      final scenario = await widget.service.simulate(
        spaceId: widget.spaceId, purchaseAmount: value, installments: _installments,
      );
      if (!mounted) return;
      setState(() {
        _payment = scenario.monthlyPayment;
        _before = scenario.baseline.summary.endingBalance;
        _after = scenario.withPurchase.summary.endingBalance;
        _firstNegativeMonth = scenario.firstNegativeMonth;
        _hasResult = true;
      });
    } on StateError catch (error) {
      if (mounted) { setState(() => _error = error.message); }
    } catch (_) {
      if (mounted) { setState(() => _error = _english
          ? 'Unable to simulate. Check your budget setup and try again.'
          : 'Não foi possível simular. Confira seu planejamento e tente novamente.'); }
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = _english;
    final risk = _hasResult && _firstNegativeMonth != null;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(english ? 'What if I buy it?' : 'E se eu comprar?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(english
            ? 'Estimate the impact without recording a transaction.'
            : 'Veja o impacto estimado sem registrar nenhum gasto.'),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _simulate(),
          decoration: InputDecoration(
            labelText: english ? 'Purchase amount' : 'Valor da compra (reais)',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _installments,
          decoration: InputDecoration(labelText: english ? 'Installments' : 'Parcelas'),
          items: [1, 2, 3, 4, 5, 6, 10, 12]
              .map((n) => DropdownMenuItem(value: n, child: Text('${n}x'))).toList(),
          onChanged: _busy ? null : (n) => setState(() => _installments = n ?? 1),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _simulate,
          child: Text(_busy
              ? (english ? 'Calculating…' : 'Calculando…')
              : (english ? 'See budget impact' : 'Ver impacto no orçamento')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_hasResult && _payment != null && _before != null && _after != null) ...[
          const SizedBox(height: 18),
          const Divider(),
          Text(english ? 'Your estimated result' : 'Resultado estimado',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _ResultMetric(
            label: english ? 'Estimated installment' : 'Parcela estimada',
            value: _money(_payment!),
          ),
          const SizedBox(height: 12),
          _ResultMetric(
            label: english ? 'Projected ending balance before' : 'Saldo final projetado antes',
            value: _money(_before!),
          ),
          const SizedBox(height: 8),
          _ResultMetric(
            label: english ? 'Projected ending balance after' : 'Saldo final projetado depois',
            value: _money(_after!),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: risk
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(risk ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                const SizedBox(width: 8),
                Expanded(child: Text(risk
                    ? (english
                        ? 'Projected negative balance in ${DateFormat('MM/yyyy').format(_firstNegativeMonth!)}.'
                        : 'Saldo negativo projetado em ${DateFormat('MM/yyyy').format(_firstNegativeMonth!)}.')
                    : (english
                        ? 'No negative months in the projected period.'
                        : 'Nenhum mês negativo no período projetado.'))),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            english ? 'Estimate only, not a guarantee.' : 'Esta simulação é uma estimativa, não uma garantia.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ]),
    ));
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
