import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/projection_model.dart';
import '../../data/repositories/folego_repository.dart';

/// Uma compra hipotética, sem gravar lançamentos ou mudar o planejamento.
/// O motor de projeções do próprio Fôlego calcula os dois cenários.
class QuickSpendSimulatorScreen extends StatefulWidget {
  const QuickSpendSimulatorScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.onBack,
  });

  final FolegoRepository repository;
  final String spaceId;
  final VoidCallback onBack;

  @override
  State<QuickSpendSimulatorScreen> createState() =>
      _QuickSpendSimulatorScreenState();
}

class _QuickSpendSimulatorScreenState extends State<QuickSpendSimulatorScreen> {
  int _reais = 200;
  int _request = 0;
  bool _loading = true;
  String? _error;
  ProjectionResult? _baseline;
  ProjectionResult? _simulated;
  int? _calculatedReais;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void didUpdateWidget(covariant QuickSpendSimulatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.repository != widget.repository) {
      // Nunca apresentar o resultado de outro espaço financeiro.
      _baseline = null;
      _simulated = null;
      _calculatedReais = null;
      _calculate();
    }
  }

  Future<void> _calculate() async {
    final serial = ++_request;
    final repository = widget.repository;
    final spaceId = widget.spaceId;
    final reais = _reais;
    setState(() {
      _loading = true;
      _error = null;
      _simulated = null;
      _calculatedReais = null;
    });
    try {
      final baseline = await repository.getProjection(
        spaceId: spaceId,
        horizonMonths: 3,
      );
      final simulated = reais == 0
          ? baseline
          : await repository.getProjection(
              spaceId: spaceId,
              horizonMonths: 3,
              adjustments: buildPurchaseSimulation(
                id: 'quick-spend-preview',
                name: 'gasto hipotético',
                totalCents: reais * 100,
                payments: 1,
                firstPayment: DateTime.now(),
              ),
            );
      if (!mounted || serial != _request ||
          widget.spaceId != spaceId || widget.repository != repository) {
        return;
      }
      setState(() {
        _baseline = baseline;
        _simulated = simulated;
        _calculatedReais = reais;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || serial != _request ||
          widget.spaceId != spaceId || widget.repository != repository) {
        return;
      }
      setState(() {
        _baseline = null;
        _simulated = null;
        _loading = false;
        _error = 'Não consegui calcular o impacto agora. Seus dados não foram alterados.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('simular um gasto'),
        leading: IconButton(
          tooltip: 'voltar ao planejamento',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: FinancialPrivacy.hidden,
        builder: (context, hidden, _) {
          final base = _baseline;
          final result = _simulated;
          final current = base?.months.isNotEmpty == true
              ? base!.months.first : null;
          final after = result?.months.isNotEmpty == true
              ? result!.months.first : null;
          final fresh = !_loading && _calculatedReais == _reais &&
              base != null && result != null && current != null && after != null;
          String money(double value) =>
              hidden ? FinancialPrivacy.maskMoney() : Formatters.money(value);
          Widget metric(String label, String value, {bool prominent = false}) =>
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: prominent ? scheme.primaryContainer
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTypography.label(
                        context, fontSize: 12,
                        color: prominent ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      )),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(value, style: AppTypography.money(
                          context, fontSize: textScale > 1.3 ? 20 : 24,
                          color: prominent ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        )),
                      ),
                    ],
                  ),
                ),
              );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                key: const ValueKey('quick-spend-screen'),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                children: [
                  Text('E SE EU GASTAR HOJE?',
                    style: AppTypography.label(context,
                      fontSize: 11, color: scheme.primary)
                        .copyWith(letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  Text('Veja o impacto antes de decidir.',
                    style: AppTypography.section(context, fontSize: 23)),
                  const SizedBox(height: 6),
                  Text('Simulação privada usando seus compromissos conhecidos. '
                      'Nenhuma compra será registrada.',
                    style: AppTypography.body(context, fontSize: 13,
                      color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('valor da compra à vista',
                          style: AppTypography.label(context, fontSize: 12)),
                        const SizedBox(height: 7),
                        Text(money(_reais.toDouble()),
                          key: const ValueKey('quick-spend-selected-amount'),
                          style: AppTypography.money(context, fontSize: 28)),
                        const SizedBox(height: 8),
                        Slider.adaptive(
                          key: const ValueKey('quick-spend-slider'),
                          min: 0,
                          max: 5000,
                          divisions: 100,
                          value: _reais.toDouble(),
                          label: hidden ? null : money(_reais.toDouble()),
                          onChanged: (value) => setState(() {
                            _reais = value.round();
                          }),
                          onChangeEnd: (_) => _calculate(),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('R\$ 0', style: AppTypography.label(
                              context, fontSize: 11)),
                            Text('R\$ 5.000', style: AppTypography.label(
                              context, fontSize: 11)),
                          ],
                        ),
                        if (!fresh && !_loading && _error == null)
                          Text('Arraste e solte para atualizar a projeção.',
                            style: AppTypography.body(context,
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _calculate,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('recalcular impacto'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_error != null)
                    Text(_error!, key: const ValueKey('quick-spend-error'))
                  else if (fresh) ...[
                    Row(
                      key: const ValueKey('quick-spend-comparison'),
                      children: [
                        metric('sem a compra',
                          money(current!.closingProjected)),
                        const SizedBox(width: 10),
                        metric('com a compra',
                          money(after!.closingProjected),
                          prominent: true),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('impacto projetado neste mês',
                            style: AppTypography.label(context,
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 7),
                          Text(money(after!.closingProjected -
                              current!.closingProjected),
                            style: AppTypography.money(context, fontSize: 21)),
                          const SizedBox(height: 7),
                          Text(
                            result!.months.any((month) => month.isCritical)
                                ? 'Atenção: há mês com saldo negativo nos próximos três meses.'
                                : 'Nenhum mês negativo nos próximos três meses da projeção.',
                            style: AppTypography.body(context, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Os saldos são mensais, não o limite diário até o '
                        'próximo salário. A simulação considera os registros '
                        'disponíveis; despesas futuras não registradas podem '
                        'mudar o resultado.',
                      style: AppTypography.body(context, fontSize: 12,
                        color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
