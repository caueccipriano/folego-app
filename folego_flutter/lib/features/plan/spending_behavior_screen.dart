import 'package:flutter/material.dart';
import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/spending_behavior.dart';
import '../../data/models/registered_spending_margin.dart';
import '../../data/repositories/folego_repository.dart';

typedef SpendingLoader = Future<List<SpendingBehaviorEntry>> Function(String, DateTime);
typedef SpendingSaver = Future<void> Function(String, SpendingBehaviorEntry, ExpenseBehavior);
typedef RegisteredIncomeLoader = Future<double> Function(String, DateTime);

/// Suggestions are intentionally limited to recognisable, specific names.
/// They are never automatically written to financial events.
ExpenseBehavior? suggestExpenseBehavior(SpendingBehaviorEntry entry) {
  if (entry.behavior != ExpenseBehavior.unclassified) return null;
  final text = entry.description.toLowerCase().trim();
  const fixed = [
    'wellhub', 'spotify', 'amazon music', 'chatgpt plus',
    'claro móvel', 'mensalidade de seguro', 'seguro superprotegido',
    'tarifa mensalidade pacote serviços', 'pagamento empréstimo clt',
    'amazon kindle unltd',
  ];
  const variable = [
    'uber ', 'uberbr', 'supermercado ', 'atacadao ', 'covabra ',
    'tauste ', 'ifood', 'ifd*', 'auto posto ', 'burger king',
    'outback', 'farmacia ', 'padaria ', 'posto vibra ', 'oba hortifruti',
  ];
  if (fixed.any((v) => text == v || text.startsWith(v + ' '))) {
    return ExpenseBehavior.fixed;
  }
  if (variable.any(text.startsWith)) return ExpenseBehavior.variable;
  return null;
}

class SpendingBehaviorScreen extends StatefulWidget {
  const SpendingBehaviorScreen({
    super.key, required this.repository, required this.spaceId,
    required this.periodMonth, this.loadOverride, this.saveOverride,
    this.incomeOverride, this.onChanged,
  });
  final FolegoRepository repository;
  final String spaceId;
  final DateTime periodMonth;
  final SpendingLoader? loadOverride;
  final SpendingSaver? saveOverride;
  final RegisteredIncomeLoader? incomeOverride;
  final VoidCallback? onChanged;

  @override
  State<SpendingBehaviorScreen> createState() => _SpendingBehaviorScreenState();
}

class _SpendingBehaviorScreenState extends State<SpendingBehaviorScreen> {
  List<SpendingBehaviorEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  String? _savingId;
  double? _registeredIncome;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SpendingBehaviorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.periodMonth.year != widget.periodMonth.year ||
        oldWidget.periodMonth.month != widget.periodMonth.month) {
      _generation++;
      _entries = const [];
      _registeredIncome = null;
      _error = null;
      _savingId = null;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_generation;
    final spaceId = widget.spaceId;
    final month = widget.periodMonth;
    if (mounted) {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final result = widget.loadOverride == null
          ? await widget.repository.getSpendingBehaviorEntries(
              spaceId: spaceId, periodMonth: month)
          : await widget.loadOverride!(spaceId, month);
      double? income;
      try {
        // Synthetic expense-only tests do not query a real backend.
        if (widget.incomeOverride != null) {
          income = await widget.incomeOverride!(spaceId, month);
        } else if (widget.loadOverride == null) {
          income = await widget.repository.getRegisteredIncomeForMonth(
            spaceId: spaceId, periodMonth: month,
          );
        }
        if (income != null && (!income.isFinite || income < 0)) {
          income = null;
        }
      } catch (_) {
        // Expenses remain usable without claiming a zero-income balance.
        income = null;
      }
      if (!mounted || request != _generation ||
          spaceId != widget.spaceId ||
          month.year != widget.periodMonth.year ||
          month.month != widget.periodMonth.month) {
        return;
      }
      setState(() {
        _entries = result;
        _registeredIncome = income;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _generation) {
        return;
      }
      setState(() {
        _entries = const [];
        _registeredIncome = null;
        _error = 'não foi possível consultar os tipos de gastos.';
        _loading = false;
      });
    }
  }

  Future<void> _classify(SpendingBehaviorEntry entry) async {
    if (_savingId != null) {
      return;
    }
    final selected = await showModalBottomSheet<ExpenseBehavior>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('como funciona este gasto?',
                  style: AppTypography.section(sheetContext, fontSize: 18)),
              const SizedBox(height: 6),
              Text('fixo tem valor relativamente estável; variável pode mudar. '
                  'uma conta recorrente também pode ser variável.',
                  style: AppTypography.body(sheetContext, fontSize: 12)),
              const SizedBox(height: 10),
              ListTile(
                key: const ValueKey('spending-select-fixed'),
                title: const Text('fixo'),
                subtitle: const Text('aluguel ou assinatura de valor estável'),
                selected: entry.behavior == ExpenseBehavior.fixed,
                onTap: () => Navigator.pop(sheetContext, ExpenseBehavior.fixed),
              ),
              ListTile(
                key: const ValueKey('spending-select-variable'),
                title: const Text('variável'),
                subtitle: const Text('mercado, energia, transporte'),
                selected: entry.behavior == ExpenseBehavior.variable,
                onTap: () => Navigator.pop(sheetContext, ExpenseBehavior.variable),
              ),
              ListTile(
                key: const ValueKey('spending-select-unclassified'),
                title: const Text('sem classificação'),
                selected: entry.behavior == ExpenseBehavior.unclassified,
                onTap: () => Navigator.pop(
                  sheetContext, ExpenseBehavior.unclassified),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == entry.behavior || !mounted) {
      return;
    }
    setState(() => _savingId = entry.id);
    try {
      if (widget.saveOverride == null) {
        await widget.repository.setSpendingBehavior(
          spaceId: widget.spaceId, entry: entry, behavior: selected);
      } else {
        await widget.saveOverride!(widget.spaceId, entry, selected);
      }
      widget.onChanged?.call();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('tipo de gasto salvo.')));
    } catch (error) {
      final concurrent = error is StateError &&
          error.message.toString().contains('classificação alterada');
      if (concurrent) {
        await _load();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(concurrent
              ? 'outro dispositivo alterou este gasto. a lista foi atualizada.'
              : 'não foi possível salvar. atualize e tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _reviewBatchSuggestions() async {
    if (_loading || _savingId != null) return;
    final candidates = _entries.where((entry) =>
      suggestExpenseBehavior(entry) != null).toList();
    if (candidates.isEmpty) return;
    final selected = candidates.map((entry) => entry.id).toSet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, rebuild) => AlertDialog(
          title: const Text('classificar em lote?'),
          content: SizedBox(
            width: 440,
            height: MediaQuery.sizeOf(dialogContext).height * .5,
            child: Column(children: [
              const Text(
                'Sugestões de descrições específicas. Revise cada item. '
                'Nada será alterado antes da confirmação.'),
              const SizedBox(height: 12),
              Expanded(child: ListView(
                children: [
                  for (final item in candidates)
                    CheckboxListTile(
                      value: selected.contains(item.id),
                      title: Text(item.description),
                      subtitle: Text(
                        suggestExpenseBehavior(item) == ExpenseBehavior.fixed
                            ? 'sugestão: fixo' : 'sugestão: variável'),
                      onChanged: (yes) => rebuild(() {
                        if (yes == true) {
                          selected.add(item.id);
                        } else {
                          selected.remove(item.id);
                        }
                      }),
                    ),
                ],
              )),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('cancelar')),
            FilledButton(
              onPressed: selected.isEmpty ? null :
                () => Navigator.pop(dialogContext, true),
              child: Text('confirmar ' + selected.length.toString()),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted || selected.isEmpty) return;
    setState(() => _savingId = '__batch__');
    var changed = 0;
    var failed = 0;
    try {
      for (final entry in candidates) {
        if (!selected.contains(entry.id)) continue;
        final proposal = suggestExpenseBehavior(entry);
        if (proposal == null) continue;
        try {
          if (widget.saveOverride != null) {
            await widget.saveOverride!(widget.spaceId, entry, proposal);
          } else {
            await widget.repository.setSpendingBehavior(
              spaceId: widget.spaceId, entry: entry, behavior: proposal);
          }
          changed++;
        } catch (_) {
          failed++;
        }
      }
      if (mounted) {
        widget.onChanged?.call();
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(changed.toString() + ' gasto(s) classificados. ' +
            failed.toString() + ' precisam de revisão manual.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final totals = SpendingBehaviorSummary.fromEntries(_entries);
    return Scaffold(
      appBar: AppBar(
        title: const Text('tipos de gastos'),
        actions: [
          IconButton(
            key: const ValueKey('spending-behavior-refresh'),
            tooltip: 'atualizar',
            onPressed: _loading || _savingId != null ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                key: const ValueKey('spending-behavior-list'),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 80),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('fixos x variáveis.',
                              style: AppTypography.display(context,
                                  fontSize: 27, color: ink)),
                          const SizedBox(height: 6),
                          Text('gastos confirmados de '
                              '${Formatters.monthYear.format(widget.periodMonth)}',
                              style: AppTypography.body(context,
                                  fontSize: 12, color: secondary)),
                          const SizedBox(height: 8),
                          Text('por data da compra, antes de reembolsos. '
                              'compras no cartão entram pelo valor integral uma '
                              'vez, não pelo pagamento da fatura.',
                              style: AppTypography.body(context,
                                  fontSize: 11, color: secondary)),
                          const SizedBox(height: 14),
                          if (!_loading && _savingId == null &&
                              _entries.any((e) => suggestExpenseBehavior(e) != null))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                key: const ValueKey('spending-batch-suggestions'),
                                icon: const Icon(Icons.auto_awesome),
                                label: Text('revisar ' +
                                  _entries.where((e) => suggestExpenseBehavior(e) != null)
                                    .length.toString() + ' sugestões em lote'),
                                onPressed: _reviewBatchSuggestions,
                              ),
                            ),
                          if (_loading) const LinearProgressIndicator(),
                          if (_error != null) ...[
                            Text(_error!, style: AppTypography.body(
                                context, fontSize: 12)),
                            TextButton(onPressed: _load,
                                child: const Text('tentar novamente')),
                          ] else ...[
                            ValueListenableBuilder<bool>(
                              valueListenable: FinancialPrivacy.hidden,
                              builder: (context, hidden, child) =>
                                  _SpendingTotals(totals: totals, hidden: hidden),
                            ),
                            const SizedBox(height: 14),
                            ValueListenableBuilder<bool>(
                              valueListenable: FinancialPrivacy.hidden,
                              builder: (context, hidden, child) =>
                                  _RegisteredMarginCard(
                                    margin: _registeredIncome == null
                                        ? null
                                        : buildRegisteredSpendingMargin(
                                            registeredIncome: _registeredIncome!,
                                            expenses: totals,
                                          ),
                                    hidden: hidden,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(totals.count == 0
                                ? 'nenhum gasto confirmado neste mês.'
                                : '${totals.count} gasto(s) · '
                                  '${totals.unclassifiedCount} sem tipo',
                                style: AppTypography.body(context,
                                    fontSize: 12, color: secondary)),
                            const SizedBox(height: 5),
                            Text('toque em um gasto para classificar. '
                                'isso não altera valor, categoria ou saldo.',
                                style: AppTypography.body(context,
                                    fontSize: 11, color: secondary)),
                          ],
                        ],
                      ),
                    );
                  }
                  final entry = _entries[index - 1];
                  final date = Formatters.shortDate.format(entry.occurredAt.toLocal());
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: AppColors.surface(brightness),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        side: BorderSide(color: AppColors.border(brightness)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: ValueKey('spending-entry-${entry.id}'),
                        enabled: _savingId == null,
                        onTap: () => _classify(entry),
                        title: Text(entry.description,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(context, fontSize: 13,
                                fontWeight: FontWeight.w700, color: ink)),
                        subtitle: Text('$date · ${_metadata(entry)}',
                            style: AppTypography.body(context,
                                fontSize: 11, color: secondary)),
                        trailing: ValueListenableBuilder<bool>(
                          valueListenable: FinancialPrivacy.hidden,
                          builder: (context, hidden, child) => Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(Formatters.money(entry.amount),
                                  style: AppTypography.money(
                                      context, fontSize: 13, color: ink)),
                              Text(_label(entry.behavior),
                                  style: AppTypography.body(
                                      context, fontSize: 11, color: secondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _label(ExpenseBehavior behavior) => switch (behavior) {
    ExpenseBehavior.fixed => 'fixo',
    ExpenseBehavior.variable => 'variável',
    ExpenseBehavior.unclassified => 'sem tipo',
  };

  static String _metadata(SpendingBehaviorEntry entry) {
    final values = <String>[];
    if (entry.frequencyClass == 'recurring') values.add('recorrente');
    if (entry.frequencyClass == 'one_off') values.add('pontual');
    if (entry.necessityClass == 'need') values.add('essencial');
    if (entry.necessityClass == 'want') values.add('não essencial');
    return values.isEmpty ? 'sem outros marcadores' : values.join(' · ');
  }
}

class _SpendingTotals extends StatelessWidget {
  const _SpendingTotals({required this.totals, required this.hidden});
  final SpendingBehaviorSummary totals;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final amounts = [
      totals.fixed, totals.variable, totals.unclassified,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (var i = 0; i < ExpenseBehavior.values.length; i++) ...[
              Row(
                children: [
                  Expanded(child: Text(ExpenseBehavior.values[i].label,
                      style: AppTypography.body(context, fontSize: 12,
                          color: ink, fontWeight: FontWeight.w700))),
                  Text(Formatters.money(amounts[i]),
                      style: AppTypography.money(context,
                          fontSize: 14, color: ink)),
                  const SizedBox(width: 7),
                  Text(hidden ? '••' :
                      '${(totals.shareOf(ExpenseBehavior.values[i])*100).round()}%',
                      style: AppTypography.label(context,
                          fontSize: 11, color: secondary)),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: hidden ? 0 : totals.shareOf(ExpenseBehavior.values[i]),
                  backgroundColor: AppColors.border(brightness),
                ),
              ),
              const SizedBox(height: 13),
            ],
            Text('total: ${Formatters.money(totals.total)}',
                key: const ValueKey('spending-behavior-total'),
                style: AppTypography.body(context, fontSize: 13,
                    color: ink, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}


/// Income comparison is deliberately observational, not a commitment engine.
class _RegisteredMarginCard extends StatelessWidget {
  const _RegisteredMarginCard({required this.margin, required this.hidden});

  final RegisteredSpendingMargin? margin;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = AppColors.primaryText(brightness);
    final muted = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);

    return DecoratedBox(
      key: const ValueKey('spending-registered-income-margin'),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('renda x gastos fixos',
                style: AppTypography.section(context, fontSize: 17)),
            const SizedBox(height: 7),
            Text(
              'comparação de receitas e gastos confirmados '
              'por data do lançamento neste mês.',
              style: AppTypography.body(context, fontSize: 11, color: muted),
            ),
            const SizedBox(height: 12),
            if (margin == null)
              Text(
                'receitas indisponíveis nesta consulta. não é possível '
                'calcular uma margem confiável agora.',
                key: const ValueKey('spending-income-unavailable'),
                style: AppTypography.body(context, fontSize: 12, color: muted),
              )
            else ...[
              _MarginLine('receitas registradas', margin!.registeredIncome),
              _MarginLine('fixos classificados e registrados',
                  margin!.expenses.fixed),
              const Divider(height: 18),
              _MarginLine(
                'referência para variáveis após fixos',
                margin!.afterClassifiedFixed,
                key: const ValueKey('spending-after-fixed'),
                emphasize: true,
              ),
              const SizedBox(height: 5),
              _MarginLine(
                'diferença após todos os gastos registrados',
                margin!.afterAllRecordedSpending,
                key: const ValueKey('spending-after-all-recorded'),
              ),
              if (margin!.hasUnknownExpenses) ...[
                const SizedBox(height: 9),
                Text(
                  'atenção: há ${margin!.expenses.unclassifiedCount} '
                  'gasto(s) sem classificação. eles estão incluídos '
                  'na diferença após todos os gastos.',
                  key: const ValueKey('spending-unknown-warning'),
                  style: AppTypography.body(
                    context, fontSize: 11, color: ink,
                  ),
                ),
              ],
              if (margin!.fixedShareOfIncome != null && !hidden) ...[
                const SizedBox(height: 8),
                Text(
                  '${(margin!.fixedShareOfIncome! * 100).round()}% das '
                  'receitas registradas equivalem aos gastos fixos '
                  'já classificados.',
                  style: AppTypography.body(
                    context, fontSize: 11, color: muted,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Text(
              'não é saldo livre para gastar: parcelas futuras, contas '
              'a vencer, reservas, dívidas e itens não cadastrados podem '
              'reduzir sua margem real. gastos no cartão são contados '
              'na compra, não no pagamento da fatura.',
              style: AppTypography.body(context, fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarginLine extends StatelessWidget {
  const _MarginLine(
    this.label,
    this.amount, {
    super.key,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                context, fontSize: 12,
                color: AppColors.secondaryText(brightness),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Formatters.money(amount),
            style: emphasize
                ? AppTypography.money(context, fontSize: 16,
                    color: AppColors.primaryText(brightness))
                : AppTypography.money(context, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
