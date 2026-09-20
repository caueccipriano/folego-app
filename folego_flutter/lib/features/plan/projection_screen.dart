import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category_item.dart';
import '../../data/models/projection_model.dart';
import '../../data/models/recurring_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_section_header.dart';

class ProjectionScreen extends StatefulWidget {
  const ProjectionScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.onBack,
  });

  final FolegoRepository repository;
  final String spaceId;
  final VoidCallback onBack;

  @override
  State<ProjectionScreen> createState() => _ProjectionScreenState();
}

class _ProjectionScreenState extends State<ProjectionScreen> {
  int _horizon = 12;
  int _selectedMonth = 0;
  bool _showCategories = false;
  bool _loading = true;
  bool _savingPlan = false;
  String? _error;

  ProjectionResult? _base;
  ProjectionResult? _simulated;
  List<ProjectionAdjustment> _adjustments = const [];
  Set<String> _disabledVariableIncomeKeys = <String>{};

  List<RecurringItem>? _recurringItems;
  List<CategoryItem>? _expenseCategories;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProjectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      _selectedMonth = 0;
      _adjustments = const [];
      _disabledVariableIncomeKeys.clear();
      _recurringItems = null;
      _expenseCategories = null;
      _load();
    }
  }

  ProjectionResult? get _display => _simulated ?? _base;

  Future<void> _load({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final baseFuture = widget.repository.getProjection(
        spaceId: widget.spaceId,
        horizonMonths: _horizon,
        disabledVariableIncomeKeys: _disabledVariableIncomeKeys,
      );
      final simulatedFuture = _adjustments.isEmpty
          ? Future<ProjectionResult?>.value(null)
          : widget.repository
                .getProjection(
                  spaceId: widget.spaceId,
                  horizonMonths: _horizon,
                  adjustments: _adjustments,
                  disabledVariableIncomeKeys: _disabledVariableIncomeKeys,
                )
                .then<ProjectionResult?>((value) => value);

      final values = await Future.wait<dynamic>([
        baseFuture,
        simulatedFuture,
      ]);

      if (!mounted) return;
      final base = values[0] as ProjectionResult;
      final simulated = values[1] as ProjectionResult?;
      final maxIndex = math.max(0, (simulated ?? base).months.length - 1);

      setState(() {
        _base = base;
        _simulated = simulated;
        _selectedMonth = _selectedMonth.clamp(0, maxIndex);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _setHorizon(int value) async {
    if (_horizon == value) return;
    setState(() {
      _horizon = value;
      _selectedMonth = 0;
    });
    await _load();
  }

  Future<void> _openScenarioSettings() async {
    final projection = _base;
    if (projection == null) return;

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final working = Set<String>.from(_disabledVariableIncomeKeys);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final brightness = Theme.of(context).brightness;
            final secondary = AppColors.secondaryText(brightness);
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'cenário atual',
                    style: AppTypography.section(context, fontSize: 20),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'se nada mudar e seus compromissos atuais continuarem, esta é a projeção',
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'receitas variáveis',
                    style: AppTypography.body(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'você pode desligar uma entrada incerta sem mexer nas receitas garantidas',
                    style: AppTypography.body(
                      context,
                      fontSize: 11,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (projection.variableIncomes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'nenhuma receita variável cadastrada',
                        style: AppTypography.body(
                          context,
                          fontSize: 12,
                          color: secondary,
                        ),
                      ),
                    )
                  else
                    ...projection.variableIncomes.map((item) {
                      final enabled = !working.contains(item.key);
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: enabled,
                        title: Text(item.name),
                        subtitle: Text(Formatters.money(item.amount)),
                        onChanged: (value) {
                          setSheetState(() {
                            if (value) {
                              working.remove(item.key);
                            } else {
                              working.add(item.key);
                            }
                          });
                        },
                      );
                    }),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(working),
                    child: const Text('aplicar ao cenário'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() => _disabledVariableIncomeKeys = result);
    await _load();
  }

  Future<void> _ensureSimulationSources() async {
    if (_recurringItems != null && _expenseCategories != null) return;
    final values = await Future.wait<dynamic>([
      widget.repository.listRecurringItems(widget.spaceId),
      widget.repository.listExpenseCategories(widget.spaceId),
    ]);
    if (!mounted) return;
    _recurringItems = values[0] as List<RecurringItem>;
    _expenseCategories = values[1] as List<CategoryItem>;
  }

  Future<void> _openSimulation() async {
    try {
      await _ensureSimulationSources();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('não consegui abrir a simulação: ${_friendlyError(error)}')),
      );
      return;
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<List<ProjectionAdjustment>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectionSimulationSheet(
        recurringItems: _recurringItems ?? const [],
        categories: _expenseCategories ?? const [],
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;
    setState(() => _adjustments = result);
    await _load();
  }

  Future<void> _discardSimulation() async {
    if (_adjustments.isEmpty) return;
    setState(() {
      _adjustments = const [];
      _simulated = null;
    });
    await _load(quiet: true);
  }

  Future<void> _addSimulationToPlanning() async {
    if (_adjustments.isEmpty || _savingPlan) return;
    setState(() => _savingPlan = true);
    try {
      await widget.repository.addProjectionPlanningItems(
        spaceId: widget.spaceId,
        items: _adjustments,
      );
      if (!mounted) return;
      setState(() {
        _adjustments = const [];
        _simulated = null;
        _recurringItems = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('mudança adicionada ao planejamento — nenhum lançamento histórico foi criado'),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('não consegui adicionar ao planejamento: ${_friendlyError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _savingPlan = false);
    }
  }

  Future<void> _openMonthDetail(int index) async {
    final projection = _display;
    if (projection == null || index < 0 || index >= projection.months.length) {
      return;
    }
    setState(() => _selectedMonth = index);
    final month = projection.months[index];
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProjectionMonthDetail(
        month: month,
        isCurrentMonth: index == 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: AppColors.background(brightness),
      child: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: _loading
              ? const AppLoadingState(label: 'calculando sua projeção')
              : _error != null
                  ? AppErrorState(
                      title: 'não consegui carregar sua projeção',
                      description: _error,
                      onRetry: () => _load(),
                    )
                  : _buildContent(brightness),
        ),
      ),
    );
  }

  Widget _buildContent(Brightness brightness) {
    final projection = _display;
    if (projection == null) return const SizedBox.shrink();

    final accent = AppColors.primaryPurple(brightness);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 72),
          children: [
            _ProjectionHeader(
              onBack: widget.onBack,
              onScenario: _openScenarioSettings,
            ),
            const SizedBox(height: 12),
            if (wide)
              Row(
                children: [
                  Expanded(
                    child: _HorizonSelector(
                      value: _horizon,
                      onChanged: _setHorizon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ProjectionSimulateButton(
                    brightness: brightness,
                    accent: accent,
                    onPressed: _openSimulation,
                  ),
                ],
              )
            else
              _HorizonSelector(
                value: _horizon,
                onChanged: _setHorizon,
              ),
            const SizedBox(height: 12),
            if (!projection.hasProjectionInputs && _adjustments.isEmpty)
              _ProjectionEmptyState(onBack: widget.onBack)
            else ...[
              _ProjectionHero(
                projection: projection,
                simulated: _simulated != null,
                baseEndingBalance: _base?.summary.endingBalance,
              ),
              if (!wide) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ProjectionSimulateButton(
                    brightness: brightness,
                    accent: accent,
                    onPressed: _openSimulation,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AppSectionHeader(
                title: 'saldo projetado',
                subtitle: _simulated == null
                    ? 'como seu saldo evolui se o cenário atual continuar'
                    : 'antes x depois da mudança simulada',
              ),
              const SizedBox(height: 12),
              _ProjectionChartCard(
                base: _base!,
                simulated: _simulated,
              ),
              const SizedBox(height: 12),
              _MonthCarousel(
                months: projection.months,
                selectedIndex: _selectedMonth,
                onTap: _openMonthDetail,
              ),
              const SizedBox(height: 14),
              _ProjectionViewToggle(
                categories: _showCategories,
                onChanged: (value) {
                  setState(() => _showCategories = value);
                },
              ),
              const SizedBox(height: 12),
              if (_showCategories)
                _ProjectionCategories(
                  projection: projection,
                  selectedIndex: _selectedMonth,
                  desktopMatrix: wide,
                )
              else
                _ProjectionInsights(projection: projection),
              if (_simulated != null) ...[
                const SizedBox(height: 18),
                _SimulationComparison(
                  base: _base!,
                  simulated: _simulated!,
                  saving: _savingPlan,
                  onDiscard: _discardSimulation,
                  onPersist: _addSimulationToPlanning,
                ),
              ],
              const SizedBox(height: 28),
            ],
          ],
        );
      },
    );
  }
}

class _ProjectionSimulateButton extends StatelessWidget {
  const _ProjectionSimulateButton({
    required this.brightness,
    required this.accent,
    required this.onPressed,
  });

  final Brightness brightness;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('projection-simulate-change'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: brightness == Brightness.dark
            ? AppColors.darkPrimaryText
            : Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        shape: const StadiumBorder(),
      ),
      icon: const Icon(AppIcons.adjustments, size: 18),
      label: const Text('simular mudança'),
    );
  }
}

class _ProjectionHeader extends StatelessWidget {
  const _ProjectionHeader({
    required this.onBack,
    required this.onScenario,
  });

  final VoidCallback onBack;
  final VoidCallback onScenario;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final surface = AppColors.surface(brightness);

    return AppPageHeader(
      title: 'projeção',
      subtitle: 'veja como os próximos meses podem fechar',
      leading: IconButton(
        tooltip: 'voltar ao resumo',
        onPressed: onBack,
        icon: const Icon(AppIcons.back),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: border),
            ),
            child: Text(
              'atual',
              style: AppTypography.label(
                context,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: secondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const ValueKey('projection-scenario-settings'),
            tooltip: 'ajustar cenário',
            onPressed: onScenario,
            icon: const Icon(AppIcons.adjustments),
          ),
        ],
      ),
    );
  }
}

class _HorizonSelector extends StatelessWidget {
  const _HorizonSelector({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final border = AppColors.border(brightness);
    final accent = AppColors.primaryPurple(brightness);
    final secondary = AppColors.secondaryText(brightness);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [3, 6, 12, 24].map((months) {
          final selected = value == months;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text('$months meses'),
              onSelected: (_) => onChanged(months),
              selectedColor: accent.withValues(alpha: .14),
              side: BorderSide(
                color: selected ? accent.withValues(alpha: .45) : border,
              ),
              labelStyle: AppTypography.label(
                context,
                color: selected ? accent : secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ProjectionHero extends StatelessWidget {
  const _ProjectionHero({
    required this.projection,
    required this.simulated,
    this.baseEndingBalance,
  });

  final ProjectionResult projection;
  final bool simulated;
  final double? baseEndingBalance;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final accent = AppColors.primaryPurple(brightness);
    final alert = AppColors.expenseText(brightness);
    final border = AppColors.border(brightness);
    final summary = projection.summary;
    final critical = summary.criticalMonth;

    return Container(
      key: const ValueKey('projection-hero'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: brightness == Brightness.dark ? .12 : .08),
          AppColors.surface(brightness),
        ),
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'seu futuro financeiro',
            style: AppTypography.section(
              context,
              fontSize: 18,
              color: primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            simulated
                ? 'saldo projetado depois da mudança'
                : 'saldo projetado no fim do período',
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondary,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.money(summary.endingBalance),
              style: AppTypography.money(
                context,
                fontSize: 32,
                color: summary.endingBalance < 0 ? alert : primary,
              ),
            ),
          ),
          if (simulated && baseEndingBalance != null) ...[
            const SizedBox(height: 7),
            Text(
              'diferença vs. antes: ${_signedMoney(summary.endingBalance - baseEndingBalance!)}',
              style: AppTypography.body(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: summary.endingBalance - baseEndingBalance! >= 0
                    ? AppColors.positiveText(brightness)
                    : alert,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'menor saldo',
                  value: Formatters.money(summary.minimumBalance),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  label: 'maior saldo',
                  value: Formatters.money(summary.maximumBalance),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  label: 'economia projetada',
                  value: Formatters.money(summary.projectedSavings),
                ),
              ),
            ],
          ),
          if (critical != null) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: alert.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: alert.withValues(alpha: .25)),
                ),
                child: Text(
                  'próximo mês crítico: ${_monthYear(critical)}',
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: alert,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final primary = AppColors.primaryText(brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: AppTypography.label(
            context,
            fontSize: 9,
            color: secondary,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTypography.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectionChartCard extends StatelessWidget {
  const _ProjectionChartCard({
    required this.base,
    this.simulated,
  });

  final ProjectionResult base;
  final ProjectionResult? simulated;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final border = AppColors.border(brightness);
    final surface = AppColors.surface(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final accent = AppColors.primaryPurple(brightness);
    final alert = AppColors.expenseText(brightness);

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _ProjectionLinePainter(
                baseValues: base.months
                    .map((month) => month.closingBalance)
                    .toList(growable: false),
                simulatedValues: simulated?.months
                    .map((month) => month.closingBalance)
                    .toList(growable: false),
                baseColor: simulated == null ? accent : secondary,
                simulatedColor: accent,
                gridColor: border,
                alertColor: alert,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (simulated != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDash(color: secondary, dashed: false, label: 'antes'),
                const SizedBox(width: 16),
                _LegendDash(color: accent, dashed: true, label: 'depois'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectionLinePainter extends CustomPainter {
  const _ProjectionLinePainter({
    required this.baseValues,
    required this.baseColor,
    required this.simulatedColor,
    required this.gridColor,
    required this.alertColor,
    this.simulatedValues,
  });

  final List<double> baseValues;
  final List<double>? simulatedValues;
  final Color baseColor;
  final Color simulatedColor;
  final Color gridColor;
  final Color alertColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (baseValues.isEmpty) return;
    final all = <double>[
      ...baseValues,
      ...?simulatedValues,
      0,
    ];
    var minValue = all.reduce(math.min);
    var maxValue = all.reduce(math.max);
    if ((maxValue - minValue).abs() < 1) {
      maxValue += 1;
      minValue -= 1;
    }
    final range = maxValue - minValue;
    const topPadding = 12.0;
    const bottomPadding = 12.0;
    const sidePadding = 10.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - sidePadding * 2;

    Offset point(List<double> values, int index) {
      final x = values.length <= 1
          ? sidePadding + chartWidth / 2
          : sidePadding + chartWidth * index / (values.length - 1);
      final normalized = (values[index] - minValue) / range;
      final y = topPadding + chartHeight * (1 - normalized);
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .65)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = topPadding + chartHeight * i / 2;
      canvas.drawLine(
        Offset(sidePadding, y),
        Offset(size.width - sidePadding, y),
        gridPaint,
      );
    }

    if (minValue < 0 && maxValue > 0) {
      final zeroY = topPadding + chartHeight * (1 - ((0 - minValue) / range));
      canvas.drawLine(
        Offset(sidePadding, zeroY),
        Offset(size.width - sidePadding, zeroY),
        Paint()
          ..color = alertColor.withValues(alpha: .30)
          ..strokeWidth = 1.2,
      );
    }

    _drawSeries(
      canvas,
      baseValues,
      point,
      baseColor,
      dashed: false,
    );
    if (simulatedValues != null && simulatedValues!.isNotEmpty) {
      _drawSeries(
        canvas,
        simulatedValues!,
        point,
        simulatedColor,
        dashed: true,
      );
    }
  }

  void _drawSeries(
    Canvas canvas,
    List<double> values,
    Offset Function(List<double>, int) point,
    Color color, {
    required bool dashed,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < values.length - 1; i++) {
      final start = point(values, i);
      final end = point(values, i + 1);
      if (dashed) {
        _drawDashedLine(canvas, start, end, paint);
      } else {
        canvas.drawLine(start, end, paint);
      }
    }

    for (var i = 0; i < values.length; i++) {
      final p = point(values, i);
      final pointColor = values[i] < 0 ? alertColor : color;
      canvas.drawCircle(
        p,
        4.2,
        Paint()..color = pointColor,
      );
      canvas.drawCircle(
        p,
        2,
        Paint()
          ..color = Colors.white.withValues(alpha: .85),
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dash = 7.0;
    const gap = 5.0;
    final vector = end - start;
    final length = vector.distance;
    if (length == 0) return;
    final unit = vector / length;
    var distance = 0.0;
    while (distance < length) {
      final from = start + unit * distance;
      final to = start + unit * math.min(distance + dash, length);
      canvas.drawLine(from, to, paint);
      distance += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ProjectionLinePainter oldDelegate) {
    return oldDelegate.baseValues != baseValues ||
        oldDelegate.simulatedValues != simulatedValues ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.simulatedColor != simulatedColor;
  }
}

class _LegendDash extends StatelessWidget {
  const _LegendDash({
    required this.color,
    required this.dashed,
    required this.label,
  });

  final Color color;
  final bool dashed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Row(
            children: dashed
                ? [
                    Container(width: 7, height: 2, color: color),
                    const SizedBox(width: 4),
                    Container(width: 7, height: 2, color: color),
                  ]
                : [Expanded(child: Container(height: 2, color: color))],
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.label(context, fontSize: 9)),
      ],
    );
  }
}

class _MonthCarousel extends StatelessWidget {
  const _MonthCarousel({
    required this.months,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<ProjectionMonth> months;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = AppColors.primaryPurple(brightness);
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(months.length, (index) {
          final selected = index == selectedIndex;
          final month = months[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              key: ValueKey('projection-month-$index'),
              onPressed: () => onTap(index),
              backgroundColor: selected
                  ? accent.withValues(alpha: .14)
                  : Colors.transparent,
              side: BorderSide(
                color: selected ? accent.withValues(alpha: .45) : border,
              ),
              label: Text(
                _monthShort(month.month).toUpperCase(),
                style: AppTypography.label(
                  context,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : secondary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ProjectionViewToggle extends StatelessWidget {
  const _ProjectionViewToggle({
    required this.categories,
    required this.onChanged,
  });

  final bool categories;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final accent = AppColors.primaryPurple(brightness);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'resumo',
              selected: !categories,
              accent: accent,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'categorias',
              selected: categories,
              accent: accent,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: .13) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.label(
              context,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected
                  ? accent
                  : AppColors.secondaryText(Theme.of(context).brightness),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectionInsights extends StatelessWidget {
  const _ProjectionInsights({required this.projection});

  final ProjectionResult projection;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final months = projection.months;
    if (months.isEmpty) return const SizedBox.shrink();

    final minMonth = months.reduce(
      (a, b) => a.closingBalance <= b.closingBalance ? a : b,
    );
    ProjectionMonth? critical;
    for (final month in months) {
      if (month.isCritical) {
        critical = month;
        break;
      }
    }
    final text = critical == null
        ? 'seu menor saldo projetado ocorre em ${_monthYear(minMonth.month)}'
        : 'Em ${_monthYear(critical.month)}, o fechamento projetado fica em ${Formatters.money(critical.closingBalance)}.';

    ProjectionMonth? installmentEnd;
    for (var i = 1; i < months.length; i++) {
      if (months[i - 1].cardInstallments > 0 &&
          months[i].cardInstallments == 0) {
        installmentEnd = months[i];
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'leitura do cenário',
            style: AppTypography.section(context, fontSize: 17),
          ),
          const SizedBox(height: 9),
          Text(
            text,
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: secondary,
            ),
          ),
          if (installmentEnd != null) ...[
            const SizedBox(height: 8),
            Text(
              'A partir de ${_monthYear(installmentEnd.month)}, as parcelas de cartão já conhecidas deixam de aparecer neste horizonte.',
              style: AppTypography.body(
                context,
                fontSize: 12,
                color: secondary,
              ),
            ),
          ],
          if (projection.variableIncomes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'receitas variáveis podem ser ligadas ou desligadas no ícone de ajustes do cenário',
              style: AppTypography.body(
                context,
                fontSize: 12,
                color: secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectionCategories extends StatelessWidget {
  const _ProjectionCategories({
    required this.projection,
    required this.selectedIndex,
    required this.desktopMatrix,
  });

  final ProjectionResult projection;
  final int selectedIndex;
  final bool desktopMatrix;

  @override
  Widget build(BuildContext context) {
    if (projection.months.isEmpty) return const SizedBox.shrink();
    if (!desktopMatrix) {
      final month = projection.months[selectedIndex.clamp(
        0,
        projection.months.length - 1,
      )];
      return _CategoryMonthList(month: month);
    }
    return _CategoryMatrix(projection: projection);
  }
}

class _CategoryMonthList extends StatelessWidget {
  const _CategoryMonthList({required this.month});

  final ProjectionMonth month;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final surface = AppColors.surface(brightness);

    if (month.categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          'nenhuma categoria prevista em ${_monthYear(month.month)}',
          style: AppTypography.body(
            context,
            fontSize: 12,
            color: secondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _monthYear(month.month),
          style: AppTypography.section(context, fontSize: 17),
        ),
        const SizedBox(height: 10),
        ...month.categories.map(
          (category) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.categoryOther, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.name,
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  Formatters.money(category.amount),
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryMatrix extends StatelessWidget {
  const _CategoryMatrix({required this.projection});

  final ProjectionResult projection;

  @override
  Widget build(BuildContext context) {
    final names = <String>{};
    for (final month in projection.months) {
      names.addAll(month.categories.map((item) => item.name));
    }
    final rows = names.toList()..sort();
    final values = <String, Map<DateTime, double>>{};
    for (final month in projection.months) {
      for (final item in month.categories) {
        values.putIfAbsent(item.name, () => {})[month.month] = item.amount;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: AppTypography.label(
          context,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: AppTypography.body(context, fontSize: 11),
        columns: [
          const DataColumn(label: Text('categoria')),
          ...projection.months.map(
            (month) => DataColumn(
              numeric: true,
              label: Text(_monthShort(month.month).toUpperCase()),
            ),
          ),
        ],
        rows: rows.map((name) {
          return DataRow(
            cells: [
              DataCell(Text(name)),
              ...projection.months.map(
                (month) => DataCell(
                  Text(
                    Formatters.money(values[name]?[month.month] ?? 0),
                  ),
                ),
              ),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ProjectionMonthDetail extends StatelessWidget {
  const _ProjectionMonthDetail({
    required this.month,
    required this.isCurrentMonth,
  });

  final ProjectionMonth month;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _monthYear(month.month),
            style: AppTypography.section(context, fontSize: 21),
          ),
          const SizedBox(height: 5),
          Text(
            isCurrentMonth
                ? 'realizado + ainda previsto = fechamento'
                : 'fechamento projetado e compromissos previstos',
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondary,
            ),
          ),
          const SizedBox(height: 18),
          if (isCurrentMonth) ...[
            _DetailLine(
              label: 'realizado até agora',
              value: month.realizedToDate ?? month.openingBalance,
            ),
            _DetailLine(
              label: 'ainda previsto',
              value: month.stillExpected ?? month.netChange,
              signed: true,
            ),
            const Divider(height: 24),
            _DetailLine(
              label: 'fechamento projetado',
              value: month.closingProjected,
              emphasize: true,
            ),
          ] else ...[
            _DetailLine(
              label: 'saldo inicial',
              value: month.openingBalance,
            ),
            _DetailLine(
              label: 'receitas previstas',
              value: month.income,
              signed: true,
              forcePositive: true,
            ),
            _DetailLine(
              label: 'despesas diretas previstas',
              value: -month.directExpenses,
              signed: true,
            ),
            _DetailLine(
              label: 'recorrências',
              value: -month.recurringExpenses,
              signed: true,
            ),
            _DetailLine(
              label: 'faturas / parcelas',
              value: -month.cardInstallments,
              signed: true,
            ),
            _DetailLine(
              label: 'dívidas / financiamentos',
              value: -month.debts,
              signed: true,
            ),
            _DetailLine(
              label: 'transferência para reserva',
              value: -month.reserveTransfers,
              signed: true,
            ),
            _DetailLine(
              label: 'investimentos planejados',
              value: -month.investments,
              signed: true,
            ),
            _DetailLine(
              label: 'movimentações planejadas',
              value: month.otherInflows - month.otherOutflows,
              signed: true,
            ),
            const Divider(height: 24),
            _DetailLine(
              label: 'saldo final projetado',
              value: month.closingBalance,
              emphasize: true,
            ),
          ],
          if (month.categories.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'principais compromissos',
              style: AppTypography.section(context, fontSize: 17),
            ),
            const SizedBox(height: 10),
            ...month.categories.take(8).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTypography.body(context, fontSize: 12),
                      ),
                    ),
                    Text(
                      Formatters.money(item.amount),
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.signed = false,
    this.forcePositive = false,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool signed;
  final bool forcePositive;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = value < 0
        ? AppColors.expenseText(brightness)
        : AppColors.primaryText(brightness);
    String formatted;
    if (signed) {
      if (forcePositive && value >= 0) {
        formatted = '+${Formatters.money(value)}';
      } else {
        formatted = _signedMoney(value);
      }
    } else {
      formatted = Formatters.money(value);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                context,
                fontSize: emphasize ? 13 : 12,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            formatted,
            style: emphasize
                ? AppTypography.money(context, fontSize: 18, color: color)
                : AppTypography.body(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SimulationComparison extends StatelessWidget {
  const _SimulationComparison({
    required this.base,
    required this.simulated,
    required this.saving,
    required this.onDiscard,
    required this.onPersist,
  });

  final ProjectionResult base;
  final ProjectionResult simulated;
  final bool saving;
  final VoidCallback onDiscard;
  final VoidCallback onPersist;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final border = AppColors.border(brightness);
    final surface = AppColors.surface(brightness);
    final difference =
        simulated.summary.endingBalance - base.summary.endingBalance;
    final differenceColor = difference >= 0
        ? AppColors.positiveText(brightness)
        : AppColors.expenseText(brightness);

    return Container(
      key: const ValueKey('projection-simulation-comparison'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'impacto da simulação',
            style: AppTypography.section(context, fontSize: 17),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CompareValue(
                  label: 'antes',
                  value: base.summary.endingBalance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompareValue(
                  label: 'depois',
                  value: simulated.summary.endingBalance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'diferença: ${_signedMoney(difference)}',
            style: AppTypography.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: differenceColor,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onDiscard,
                  child: const Text('descartar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('projection-add-to-plan'),
                  onPressed: saving ? null : onPersist,
                  child: Text(
                    saving ? 'adicionando…' : 'adicionar ao planejamento',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareValue extends StatelessWidget {
  const _CompareValue({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(context, fontSize: 10)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Formatters.money(value),
            style: AppTypography.money(context, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

class _ProjectionEmptyState extends StatelessWidget {
  const _ProjectionEmptyState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.chartLine,
      title: 'a projeção precisa conhecer seus compromissos',
      description:
          'cadastre receitas e despesas recorrentes, parcelas ou dívidas. aí o Fôlego consegue mostrar como os próximos meses provavelmente fecham',
      action: OutlinedButton.icon(
        onPressed: onBack,
        icon: const Icon(AppIcons.back, size: 17),
        label: const Text('voltar ao planejamento'),
      ),
    );
  }
}


enum _SimulationTemplate {
  free,
  car,
  salary,
  cancelSubscription,
  reduceCategory,
}

class _ProjectionSimulationSheet extends StatefulWidget {
  const _ProjectionSimulationSheet({
    required this.recurringItems,
    required this.categories,
  });

  final List<RecurringItem> recurringItems;
  final List<CategoryItem> categories;

  @override
  State<_ProjectionSimulationSheet> createState() =>
      _ProjectionSimulationSheetState();
}

class _ProjectionSimulationSheetState
    extends State<_ProjectionSimulationSheet> {
  _SimulationTemplate _template = _SimulationTemplate.free;
  DateTime _startsOn = DateTime.now();

  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _entry = TextEditingController(text: '10000');
  final _installment = TextEditingController(text: '1200');
  final _months = TextEditingController(text: '36');
  final _maintenance = TextEditingController(text: '150');
  final _ipva = TextEditingController();
  final _salary = TextEditingController(text: '1000');
  final _reduction = TextEditingController(text: '200');

  bool _freeRecurring = true;
  String _freeComponent = 'direct_expense';
  RecurringItem? _subscription;
  CategoryItem? _category;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _entry.dispose();
    _installment.dispose();
    _months.dispose();
    _maintenance.dispose();
    _ipva.dispose();
    _salary.dispose();
    _reduction.dispose();
    super.dispose();
  }

  List<RecurringItem> get _subscriptions => widget.recurringItems
      .where((item) => item.active && item.isExpense)
      .toList(growable: false);

  List<CategoryItem> get _leafCategories => widget.categories
      .where((item) => item.parentId != null)
      .toList(growable: false);

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _startsOn = picked);
  }

  void _submit() {
    final idBase = DateTime.now().microsecondsSinceEpoch.toString();
    List<ProjectionAdjustment> result;

    switch (_template) {
      case _SimulationTemplate.car:
        final entry = _money(_entry.text);
        final installment = _money(_installment.text);
        final months = int.tryParse(_months.text.trim()) ?? 0;
        final maintenance = _money(_maintenance.text);
        final ipva = _money(_ipva.text);
        if (months <= 0 ||
            (entry <= 0 && installment <= 0 && maintenance <= 0 && ipva <= 0)) {
          _invalid('preencha pelo menos um custo e uma quantidade de parcelas');
          return;
        }
        final end = DateTime(
          _startsOn.year,
          _startsOn.month + months - 1,
          _startsOn.day,
        );
        result = [
          if (entry > 0)
            ProjectionAdjustment(
              id: '$idBase-entry',
              name: 'novo carro — entrada',
              component: 'direct_expense',
              amountDelta: entry,
              frequency: 'once',
              startsOn: _startsOn,
              categoryName: 'transporte',
            ),
          if (installment > 0)
            ProjectionAdjustment(
              id: '$idBase-installment',
              name: 'novo carro — financiamento',
              component: 'debt',
              amountDelta: installment,
              frequency: 'monthly',
              startsOn: _startsOn,
              endsOn: end,
              categoryName: 'dívidas / financiamentos',
            ),
          if (maintenance > 0)
            ProjectionAdjustment(
              id: '$idBase-maintenance',
              name: 'novo carro — manutenção',
              component: 'recurring_expense',
              amountDelta: maintenance,
              frequency: 'monthly',
              startsOn: _startsOn,
              categoryName: 'transporte',
            ),
          if (ipva > 0)
            ProjectionAdjustment(
              id: '$idBase-ipva',
              name: 'novo carro — IPVA',
              component: 'direct_expense',
              amountDelta: ipva,
              frequency: 'yearly',
              startsOn: _startsOn,
              categoryName: 'transporte',
            ),
        ];
      case _SimulationTemplate.salary:
        final amount = _money(_salary.text);
        if (amount <= 0) {
          _invalid('informe o novo valor mensal');
          return;
        }
        result = [
          ProjectionAdjustment(
            id: '$idBase-salary',
            name: 'novo salário',
            component: 'income',
            amountDelta: amount,
            frequency: 'monthly',
            startsOn: _startsOn,
          ),
        ];
      case _SimulationTemplate.cancelSubscription:
        final item = _subscription;
        if (item == null) {
          _invalid('selecione uma recorrência para cancelar');
          return;
        }
        result = [
          ProjectionAdjustment(
            id: '$idBase-cancel',
            name: 'cancelar ${item.name}',
            component: 'recurring_expense',
            amountDelta: -item.amount,
            frequency: 'monthly',
            startsOn: _startsOn,
            endsOn: item.endsOn,
            categoryName: item.categoryName ?? 'assinaturas',
            categoryId: item.categoryId,
          ),
        ];
      case _SimulationTemplate.reduceCategory:
        final category = _category;
        final amount = _money(_reduction.text);
        if (category == null || amount <= 0) {
          _invalid('selecione uma categoria e informe a redução');
          return;
        }
        result = [
          ProjectionAdjustment(
            id: '$idBase-reduce',
            name: 'reduzir ${category.name}',
            component: 'direct_expense',
            amountDelta: -amount,
            frequency: 'monthly',
            startsOn: _startsOn,
            categoryName: category.name,
            categoryId: category.id,
          ),
        ];
      case _SimulationTemplate.free:
        final amount = _money(_amount.text);
        if (_name.text.trim().isEmpty || amount <= 0) {
          _invalid('informe um nome e um valor');
          return;
        }
        result = [
          ProjectionAdjustment(
            id: '$idBase-free',
            name: _name.text.trim(),
            component: _freeComponent,
            amountDelta: amount,
            frequency: _freeRecurring ? 'monthly' : 'once',
            startsOn: _startsOn,
            categoryName: _category?.name,
            categoryId: _category?.id,
          ),
        ];
    }

    Navigator.of(context).pop(result);
  }

  void _invalid(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final secondary = AppColors.secondaryText(brightness);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .90,
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(brightness),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'simular mudança',
                  style: AppTypography.section(context, fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'nada aqui vira lançamento. primeiro você vê o efeito no futuro',
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: secondary,
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _templateChip('livre', _SimulationTemplate.free),
                      _templateChip('novo carro', _SimulationTemplate.car),
                      _templateChip('novo salário', _SimulationTemplate.salary),
                      _templateChip(
                        'cancelar assinatura',
                        _SimulationTemplate.cancelSubscription,
                      ),
                      _templateChip(
                        'reduzir categoria',
                        _SimulationTemplate.reduceCategory,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ..._fieldsForTemplate(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickStart,
                  icon: const Icon(AppIcons.calendar, size: 17),
                  label: Text(
                    'começa em ${Formatters.fullDate.format(_startsOn)}',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(AppIcons.chartLine, size: 18),
                  label: const Text('ver impacto'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _templateChip(String label, _SimulationTemplate value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: _template == value,
        label: Text(label),
        onSelected: (_) => setState(() => _template = value),
      ),
    );
  }

  List<Widget> _fieldsForTemplate() {
    switch (_template) {
      case _SimulationTemplate.car:
        return [
          _moneyField(_entry, 'entrada'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _moneyField(_installment, 'parcela mensal')),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _months,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'parcelas'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _moneyField(_maintenance, 'manutenção mensal'),
          const SizedBox(height: 10),
          _moneyField(_ipva, 'IPVA anual'),
        ];
      case _SimulationTemplate.salary:
        return [
          _moneyField(_salary, 'nova renda mensal'),
        ];
      case _SimulationTemplate.cancelSubscription:
        return [
          DropdownButtonFormField<RecurringItem>(
            initialValue: _subscription,
            decoration: const InputDecoration(
              labelText: 'recorrência / assinatura',
            ),
            items: _subscriptions
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      '${item.name} · ${Formatters.money(item.amount)}',
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _subscription = value),
          ),
        ];
      case _SimulationTemplate.reduceCategory:
        return [
          _categoryDropdown(),
          const SizedBox(height: 10),
          _moneyField(_reduction, 'redução mensal'),
        ];
      case _SimulationTemplate.free:
        return [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'nome da mudança'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _freeComponent,
            decoration: const InputDecoration(labelText: 'tipo'),
            items: const [
              DropdownMenuItem(value: 'income', child: Text('nova renda')),
              DropdownMenuItem(
                value: 'direct_expense',
                child: Text('nova despesa'),
              ),
              DropdownMenuItem(value: 'reserve', child: Text('aporte em reserva')),
              DropdownMenuItem(
                value: 'investment',
                child: Text('investimento planejado'),
              ),
              DropdownMenuItem(
                value: 'other_outflow',
                child: Text('outra saída planejada'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _freeComponent = value);
            },
          ),
          const SizedBox(height: 10),
          _moneyField(_amount, 'valor'),
          const SizedBox(height: 10),
          _categoryDropdown(optional: true),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _freeRecurring,
              title: const Text('repete todo mês'),
              onChanged: (value) => setState(() => _freeRecurring = value),
            ),
          ),
        ];
    }
  }

  Widget _categoryDropdown({bool optional = false}) {
    return DropdownButtonFormField<CategoryItem>(
      initialValue: _category,
      decoration: InputDecoration(
        labelText: optional ? 'categoria (opcional)' : 'categoria',
      ),
      isExpanded: true,
      items: _leafCategories
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: (value) => setState(() => _category = value),
    );
  }

  Widget _moneyField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: 'R\$ '),
    );
  }
}

double _money(String value) => Formatters.parseMoney(value).toDouble();

String _signedMoney(double value) {
  if (value > 0) return '+${Formatters.money(value)}';
  if (value < 0) return '-${Formatters.money(value.abs())}';
  return Formatters.money(0);
}

String _monthShort(DateTime value) {
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return months[value.month - 1];
}

String _monthYear(DateTime value) {
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${months[value.month - 1]}/${value.year}';
}

String _friendlyError(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '');
  if (text.contains('read_access_denied')) return 'sem acesso a esta projeção';
  if (text.contains('write_access_denied')) return 'sem permissão para alterar este planejamento';
  return text;
}
