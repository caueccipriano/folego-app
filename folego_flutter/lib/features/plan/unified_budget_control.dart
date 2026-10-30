import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/ui/app_snackbars.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_budget.dart';

/// The flexible ceiling lives beside category limits in the Plan.
/// The two scopes remain independent; their values must never be added.
class UnifiedBudgetControl extends StatefulWidget {
  const UnifiedBudgetControl({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.periodMonth,
    required this.onOpenDetails,
    this.refreshToken,
    this.onSaved,
    this.overviewLoader,
    this.saveOverride,
  });

  final FolegoRepository repository;
  final String spaceId;
  final DateTime periodMonth;
  final VoidCallback onOpenDetails;
  final Object? refreshToken;
  final VoidCallback? onSaved;

  @visibleForTesting
  final Future<FlexibleBudgetOverview> Function(DateTime)? overviewLoader;
  @visibleForTesting
  final Future<void> Function(DateTime, double)? saveOverride;

  @override
  State<UnifiedBudgetControl> createState() => _UnifiedBudgetControlState();
}

class _UnifiedBudgetControlState extends State<UnifiedBudgetControl> {
  int _request = 0;
  bool _loading = true;
  bool _saving = false;
  FlexibleBudgetOverview? _overview;
  String? _error;

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  bool get _isPastMonth {
    final now = DateTime.now();
    return widget.periodMonth.isBefore(DateTime(now.year, now.month));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant UnifiedBudgetControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        !_sameMonth(oldWidget.periodMonth, widget.periodMonth) ||
        oldWidget.repository != widget.repository) {
      _overview = null; // No values from another financial space or month.
      unawaited(_load());
    } else if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final spaceId = widget.spaceId;
    final month = DateTime(widget.periodMonth.year, widget.periodMonth.month);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await (widget.overviewLoader?.call(month) ??
          widget.repository.getFlexibleBudgetOverview(
            spaceId: spaceId,
            periodMonth: month,
          ));
      if (!mounted || request != _request || widget.spaceId != spaceId ||
          !_sameMonth(widget.periodMonth, month)) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request || widget.spaceId != spaceId ||
          !_sameMonth(widget.periodMonth, month)) return;
      setState(() {
        _overview = null;
        _error = 'não foi possível consultar o teto flexível';
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    if (_saving || _isPastMonth || _overview == null) return;
    final overview = _overview!;
    final controller = TextEditingController(
      text: FinancialPrivacy.hidden.value || !overview.explicitLimit
          ? ''
          : overview.limitAmount.toStringAsFixed(2).replaceAll('.', ','),
    );
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, update) => Padding(
            padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('teto de gastos flexíveis',
                  style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Limita somente os gastos flexíveis deste mês. '
                  'Os limites por categoria continuam independentes. '
                  'Não representa o saldo disponível para gastar.',
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('unified-flex-limit-input'),
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixText: 'R\$ ',
                    labelText: 'teto deste mês',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  key: const ValueKey('unified-flex-save'),
                  onPressed: () {
                    final raw = controller.text.trim()
                        .replaceAll('R\$', '').replaceAll(' ', '')
                        .replaceAll('.', '').replaceAll(',', '.');
                    final value = double.tryParse(raw);
                    if (value == null || !value.isFinite || value < 0) {
                      update(() => error = 'informe um valor válido');
                      return;
                    }
                    Navigator.of(sheetContext).pop(value);
                  },
                  child: const Text('salvar teto'),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (result == null || !mounted) return;

    final spaceId = widget.spaceId;
    final month = DateTime(widget.periodMonth.year, widget.periodMonth.month);
    setState(() => _saving = true);
    try {
      if (widget.saveOverride != null) {
        await widget.saveOverride!(month, result);
      } else {
        await widget.repository.setFlexibleBudgetLimit(
          spaceId: spaceId, periodMonth: month, limitAmount: result,
        );
      }
      if (!mounted || widget.spaceId != spaceId ||
          !_sameMonth(widget.periodMonth, month)) return;
      AppSnackbars.show(context, 'teto atualizado para este mês');
      await _load();
      if (mounted) widget.onSaved?.call();
    } catch (_) {
      if (mounted && widget.spaceId == spaceId &&
          _sameMonth(widget.periodMonth, month)) {
        AppSnackbars.show(context, 'não foi possível salvar o teto. tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    return ValueListenableBuilder<bool>(
      valueListenable: FinancialPrivacy.hidden,
      builder: (context, hidden, _) {
        final overview = _overview;
        String money(double amount) => hidden ? 'R\$ ••••' : Formatters.money(amount);
        return Column(
          key: const ValueKey('unified-budget-control'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 26),
            Text('gastos flexíveis',
              style: AppTypography.section(context, fontSize: 15)),
            const SizedBox(height: 5),
            if (_loading && overview == null)
              const Text('consultando teto flexível…')
            else if (_error != null) ...[
              Text(_error!, style: TextStyle(color: secondary)),
              Align(alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _load, child: const Text('tentar novamente'))),
            ] else if (overview != null) ...[
              Text(overview.configured
                ? 'teto ${money(overview.limitAmount)} · usado ${money(overview.usedAmount)}'
                : 'nenhum teto definido',
                key: const ValueKey('unified-budget-values'),
                style: AppTypography.body(context, fontSize: 13)),
              const SizedBox(height: 3),
              Text(
                !overview.explicitLimit && overview.configured
                    ? 'valor herdado dos limites por categoria, não é um teto próprio'
                    : overview.configured
                        ? overview.isExceeded
                            ? 'acima do teto em ${money(overview.exceededAmount)}'
                            : 'resta no teto: ${money(overview.remainingAmount)}'
                        : 'defina um teto somente se quiser controlar os gastos flexíveis',
                style: AppTypography.body(context, fontSize: 11, color: secondary),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  if (!_isPastMonth)
                    TextButton.icon(
                      key: const ValueKey('unified-flex-edit'),
                      onPressed: _saving ? null : _edit,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(overview.explicitLimit ? 'ajustar teto' : 'definir teto próprio'),
                    ),
                  TextButton(
                    key: const ValueKey('plan-open-flex-budget'),
                    onPressed: widget.onOpenDetails,
                    child: const Text('detalhes dos gastos flexíveis'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
