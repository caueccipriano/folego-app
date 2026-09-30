import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/intelligence/purchase_scenario_service.dart';
import '../core/intelligence/purchase_timeline.dart';
import 'purchase_timeline_card.dart';

class PurchaseSimulatorCard extends StatefulWidget {
  const PurchaseSimulatorCard({super.key, required this.service, required this.spaceId, this.embedded = false});
  final PurchaseScenarioService service;
  final String spaceId;
  final bool embedded;
  @override
  State<PurchaseSimulatorCard> createState() => _PurchaseSimulatorCardState();
}

class _PurchaseSimulatorCardState extends State<PurchaseSimulatorCard> {
  final _amount = TextEditingController();
  int _installments = 1;
  int _horizonMonths = 12;
  int _requestEpoch = 0;
  String? _boundIdentity;
  String? _resultOwnerUserId;
  String? _resultSpaceId;
  List<PurchaseTimelineMonth> _timeline = const [];
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
  void initState() {
    super.initState();
    _boundIdentity = widget.service.repository.currentUserId;
  }

  void _clearResult() {
    _hasResult = false;
    _error = null;
    _payment = null;
    _before = null;
    _after = null;
    _firstNegativeMonth = null;
    _timeline = const [];
    _resultOwnerUserId = null;
    _resultSpaceId = null;
  }

  @override
  void didUpdateWidget(covariant PurchaseSimulatorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIdentity = widget.service.repository.currentUserId;
    if (oldWidget.spaceId != widget.spaceId ||
        !identical(oldWidget.service.repository, widget.service.repository) ||
        _boundIdentity != nextIdentity) {
      _requestEpoch++;
      _boundIdentity = nextIdentity;
      _busy = false;
      _amount.clear();
      _clearResult();
    }
  }

  @override
  void dispose() {
    _requestEpoch++;
    _amount.dispose();
    super.dispose();
  }

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
    final epoch = ++_requestEpoch;
    final repository = widget.service.repository;
    final space = widget.spaceId;
    final userId = repository.currentUserId;
    if (userId == null) {
      setState(() => _error = _english
          ? 'Sign in before simulating.' : 'Entre na sua conta para simular.');
      return;
    }
    bool current() => mounted &&
        epoch == _requestEpoch &&
        identical(repository, widget.service.repository) &&
        widget.spaceId == space &&
        repository.currentUserId == userId;
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _clearResult(); });
    try {
      final scenario = await widget.service.simulate(
        spaceId: space, purchaseAmount: value, installments: _installments,
        horizonMonths: _horizonMonths,
      );
      if (!current()) return;
      setState(() {
        _resultOwnerUserId = userId;
        _resultSpaceId = space;
        _timeline = purchaseTimeline(scenario.baseline, scenario.withPurchase);
        _payment = scenario.monthlyPayment;
        _before = scenario.baseline.summary.endingBalance;
        _after = scenario.withPurchase.summary.endingBalance;
        _firstNegativeMonth = scenario.firstNegativeMonth;
        _hasResult = true;
      });
    } on StateError catch (error) {
      if (current()) { setState(() => _error = error.message); }
    } catch (_) {
      if (current()) { setState(() => _error = _english
          ? 'Unable to simulate. Check your budget setup and try again.'
          : 'Não foi possível simular. Confira seu planejamento e tente novamente.'); }
    } finally {
      if (current()) { setState(() => _busy = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = _english;
    final resultVisible = _hasResult &&
        _resultOwnerUserId != null &&
        _resultOwnerUserId == widget.service.repository.currentUserId &&
        _resultSpaceId == widget.spaceId;
    final risk = resultVisible && _firstNegativeMonth != null;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(widget.embedded ? 20 : 16, 16, widget.embedded ? 20 : 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!widget.embedded) ...[
          Text(english ? 'What if I buy it?' : 'E se eu comprar?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
        ],
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
          onChanged: (_) { if (_hasResult) setState(_clearResult); },
          decoration: InputDecoration(
            labelText: english ? 'Purchase amount' : 'Valor da compra (reais)',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey('purchase-installments-$_installments'),
          initialValue: _installments,
          decoration: InputDecoration(labelText: english ? 'Installments' : 'Parcelas'),
          items: [1, 2, 3, 4, 5, 6, 10, 12]
              .map((n) => DropdownMenuItem(value: n, child: Text('${n}x'))).toList(),
          onChanged: _busy ? null : (n) => setState(() {
            _installments = n ?? 1;
            _clearResult();
          }),
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
        if (resultVisible && _payment != null && _before != null && _after != null) ...[
          const SizedBox(height: 18),
          const Divider(),
          Text(english ? 'Your estimated result' : 'Resultado estimado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
          PurchaseTimelineCard(months: _timeline),
          const SizedBox(height: 8),
          Text(
            english ? 'Estimate only, not a guarantee.' : 'Esta simulação é uma estimativa, não uma garantia.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ]),
    );
    return widget.embedded ? content : Card(child: content);
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
