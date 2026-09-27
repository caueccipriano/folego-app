import 'package:flutter/material.dart';
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
  String? _result;
  @override
  void dispose() { _amount.dispose(); super.dispose(); }

  Future<void> _simulate() async {
    final value = double.tryParse(_amount.text.trim().replaceAll('.', '').replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _result = 'Digite um valor válido. Exemplo: 350,00');
      return;
    }
    setState(() { _busy = true; _result = null; });
    try {
      final scenario = await widget.service.simulate(
        spaceId: widget.spaceId, purchaseAmount: value,
        installments: _installments);
      final before = scenario.baseline.summary.endingBalance;
      final after = scenario.withPurchase.summary.endingBalance;
      if (!mounted) return;
      setState(() => _result =
        'Parcela estimada: R\$ ${scenario.monthlyPayment.toStringAsFixed(2)}. '
        'Saldo final projetado: de R\$ ${before.toStringAsFixed(2)} '
        'para R\$ ${after.toStringAsFixed(2)}. '
        '${scenario.firstNegativeMonth == null ? 'Nenhum mês negativo na projeção consultada.' : 'Atenção: existe mês com saldo negativo na projeção.'} '
        'Simulação, não é uma garantia.');
    } catch (_) {
      if (mounted) setState(() => _result =
        'Não foi possível simular. Confira se o planejamento está configurado e tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('E se eu comprar?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: _amount,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor da compra (R$)')),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _installments,
          decoration: const InputDecoration(labelText: 'Parcelas'),
          items: [1, 2, 3, 4, 5, 6, 10, 12]
              .map((n) => DropdownMenuItem(value: n, child: Text('$n x')))
              .toList(),
          onChanged: _busy ? null : (n) => setState(() => _installments = n ?? 1)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _simulate,
          child: Text(_busy ? 'Calculando…' : 'Simular compra')),
        if (_result != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_result!)),
      ],
    )),
  );
