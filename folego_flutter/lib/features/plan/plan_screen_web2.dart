import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/ui/app_snackbars.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_budget.dart';
import '../../shared/widgets/category_icon_badge.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_section_header.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_sheet_handle.dart';

typedef PlanBudgetLoader =
    Future<List<BudgetOverviewItem>> Function({
      required String spaceId,
      required DateTime periodMonth,
    });

typedef PlanBudgetSaver =
    Future<void> Function({
      required String spaceId,
      required DateTime periodMonth,
      required String categoryId,
      required num plannedAmount,
      required BudgetLimitScope scope,
    });

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.refreshToken,
    this.loadOverride,
    this.saveOverride,
    this.onProjectionRequested,
    this.onFlexibleBudgetRequested,
  });

  final FolegoRepository repository;
  final String spaceId;

  /// Changes when the shared Realtime coordinator invalidates the Plan domain.
  /// It intentionally is not used as this widget's key, so interaction state
  /// and scroll position survive a refresh.
  final Object? refreshToken;

  final VoidCallback? onProjectionRequested;
  final VoidCallback? onFlexibleBudgetRequested;

  @visibleForTesting
  final PlanBudgetLoader? loadOverride;

  @visibleForTesting
  final PlanBudgetSaver? saveOverride;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late DateTime _month;
  late final ScrollController _scrollController;

  final Set<String> _expandedCategoryIds = <String>{};
  List<BudgetOverviewItem> _items = const [];

  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  bool _hasLoadedOnce = false;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _scrollController = ScrollController();
    _load(initial: true);
  }

  @override
  void didUpdateWidget(covariant PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.spaceId != widget.spaceId) {
      final now = DateTime.now();
      _month = DateTime(now.year, now.month);
      _items = const [];
      _expandedCategoryIds.clear();
      _hasLoadedOnce = false;
      _loading = true;
      _error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(initial: true);
      });
      return;
    }

    if (oldWidget.refreshToken != widget.refreshToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<BudgetOverviewItem> get _parents {
    final parents = _items.where((item) => item.isParent).toList();
    parents.sort(
      (a, b) => _sortKey(a.categoryName).compareTo(_sortKey(b.categoryName)),
    );
    return parents;
  }

  List<BudgetOverviewItem> _childrenOf(BudgetOverviewItem parent) {
    final children = _items
        .where((item) => item.parentId == parent.categoryId)
        .toList();
    children.sort(
      (a, b) => _sortKey(a.categoryName).compareTo(_sortKey(b.categoryName)),
    );
    return children;
  }

  BudgetMonthSummary get _summary => BudgetMonthSummary.fromItems(_items);

  int get _budgetedCount => _items
      .where((item) => item.isSubcategory && item.hasBudget)
      .length;

  bool get _isPastMonth {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  Future<List<BudgetOverviewItem>> _fetchBudgetOverview() {
    final loader = widget.loadOverride;
    if (loader != null) {
      return loader(spaceId: widget.spaceId, periodMonth: _month);
    }
    return widget.repository.getBudgetOverview(
      spaceId: widget.spaceId,
      periodMonth: _month,
    );
  }

  Future<void> _load({bool initial = false}) async {
    final generation = ++_loadGeneration;
    final showInitialLoading = initial || !_hasLoadedOnce;

    if (mounted) {
      setState(() {
        if (showInitialLoading) {
          _loading = true;
        } else {
          _refreshing = true;
        }
        _error = null;
      });
    }

    try {
      final items = await _fetchBudgetOverview();
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _items = items;
        _loading = false;
        _refreshing = false;
        _hasLoadedOnce = true;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _hasLoadedOnce = true;
        _error = _message(error);
      });
    }
  }

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    await _load();
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (!_expandedCategoryIds.add(categoryId)) {
        _expandedCategoryIds.remove(categoryId);
      }
    });
  }

  void _startPlanning() {
    for (final parent in _parents) {
      final children = _childrenOf(parent);
      if (children.isNotEmpty) {
        _editBudget(children.first);
        return;
      }
    }
  }

  Future<void> _saveBudget({
    required BudgetOverviewItem item,
    required _BudgetEditResult result,
  }) async {
    final saver = widget.saveOverride;
    if (saver != null) {
      await saver(
        spaceId: widget.spaceId,
        periodMonth: _month,
        categoryId: item.categoryId,
        plannedAmount: result.amount,
        scope: result.scope,
      );
      return;
    }

    await widget.repository.setBudgetLimit(
      spaceId: widget.spaceId,
      periodMonth: _month,
      categoryId: item.categoryId,
      plannedAmount: result.amount,
      scope: result.scope,
    );
  }

  Future<void> _editBudget(BudgetOverviewItem item) async {
    if (_saving) return;

    if (_isPastMonth) {
      AppSnackbars.show(
        context,
        'meses anteriores ficam somente para consulta',
      );
      return;
    }

    final result = await _showBudgetSheet(item);
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await _saveBudget(item: item, result: result);
      if (!mounted) return;

      final text = switch (result.scope) {
        BudgetLimitScope.cancelFromMonth =>
          'limite mensal encerrado a partir de ${_monthLabel(_month)}',
        BudgetLimitScope.fromMonth =>
          '${item.categoryName}: ${Formatters.money(result.amount)} todo mês',
        BudgetLimitScope.month => result.amount == 0
            ? 'limite de ${item.categoryName.toLowerCase()} removido neste mês'
            : '${item.categoryName}: ${Formatters.money(result.amount)} neste mês',
      };

      AppSnackbars.show(context, text);
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppSnackbars.show(context, 'não consegui salvar: ${_message(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<_BudgetEditResult?> _showBudgetSheet(BudgetOverviewItem item) {
    final controller = TextEditingController(
      text: item.hasBudget
          ? item.plannedAmount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    // The modal route can keep painting during its reverse animation after its
    // Future resolves. Disposing this short-lived controller in `whenComplete`
    // therefore races that animation. The controller becomes unreachable with
    // the route and is collected normally after the sheet is removed.
    return showModalBottomSheet<_BudgetEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var scope = BudgetLimitScope.month;
        String? validationError;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final brightness = Theme.of(context).brightness;
            final surface = AppColors.surface(brightness);
            final border = AppColors.border(brightness);
            final primaryText = AppColors.primaryText(brightness);
            final secondaryText = AppColors.secondaryText(brightness);
            final accent = AppColors.primaryPurple(brightness);
            final parentName = item.parentName ?? item.categoryName;
            final familyColor = CategoryVisuals.colorFor(
              category: parentName,
              brightness: brightness,
            );
            final icon = CategoryVisuals.iconFor(
              category: parentName,
              subcategory: item.categoryName,
            );

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.viewInsetsOf(context).bottom + 22,
                  ),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.sheet),
                    ),
                    border: Border.all(color: border),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSheetHandle(),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            CategoryIconBadge(
                              icon: icon,
                              color: familyColor,
                              size: 46,
                              iconSize: 22,
                              radius: AppRadii.control,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.hasBudget
                                        ? 'editar limite'
                                        : 'definir limite',
                                    style: AppTypography.section(
                                      context,
                                      fontSize: 19,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.parentName ?? ''}${item.parentName == null ? '' : ' › '}${item.categoryName}',
                                    style: AppTypography.body(
                                      context,
                                      fontSize: 12,
                                      color: secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          key: const ValueKey('plan-budget-amount'),
                          controller: controller,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTypography.money(
                            context,
                            fontSize: 20,
                            color: primaryText,
                          ),
                          decoration: InputDecoration(
                            labelText: 'limite mensal',
                            prefixText: 'R\$ ',
                            errorText: validationError,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          item.isRecurring
                              ? 'onde quer aplicar a mudança?'
                              : 'como você quer usar esse limite?',
                          style: AppTypography.body(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stack = constraints.maxWidth < 390;
                            final monthChoice = _ScopeChoice(
                              selected: scope == BudgetLimitScope.month,
                              icon: AppIcons.calendar,
                              title: item.isRecurring
                                  ? 'só neste mês'
                                  : 'só este mês',
                              subtitle: 'não muda os outros meses',
                              onTap: () => setSheetState(
                                () => scope = BudgetLimitScope.month,
                              ),
                            );
                            final recurringChoice = _ScopeChoice(
                              selected: scope == BudgetLimitScope.fromMonth,
                              icon: AppIcons.recurring,
                              title: item.isRecurring
                                  ? 'neste e nos próximos'
                                  : 'todo mês',
                              subtitle: item.isRecurring
                                  ? 'vale daqui para frente'
                                  : 'repete até você mudar',
                              onTap: () => setSheetState(
                                () => scope = BudgetLimitScope.fromMonth,
                              ),
                            );

                            if (stack) {
                              return Column(
                                children: [
                                  monthChoice,
                                  const SizedBox(height: 8),
                                  recurringChoice,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: monthChoice),
                                const SizedBox(width: 8),
                                Expanded(child: recurringChoice),
                              ],
                            );
                          },
                        ),
                        if (item.actualAmount > 0) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: familyColor.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(AppRadii.control),
                              border: Border.all(
                                color: familyColor.withValues(alpha: .20),
                              ),
                            ),
                            child: Text(
                              '${Formatters.money(item.actualAmount)} já realizado neste mês',
                              style: AppTypography.body(
                                context,
                                fontSize: 12,
                                color: secondaryText,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          key: const ValueKey('plan-save-budget'),
                          onPressed: () {
                            final amount = _parseMoney(controller.text);
                            if (amount == null || amount < 0) {
                              setSheetState(() {
                                validationError = 'digite um valor válido';
                              });
                              return;
                            }
                            if (scope == BudgetLimitScope.fromMonth &&
                                amount <= 0) {
                              setSheetState(() {
                                validationError =
                                    'para todo mês, use um valor maior que zero';
                              });
                              return;
                            }
                            Navigator.of(context).pop(
                              _BudgetEditResult(amount: amount, scope: scope),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.lime,
                            foregroundColor: AppColors.iconOnLime,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('salvar limite'),
                        ),
                        if (item.isRecurring) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _confirmCancelRecurring(
                              context,
                              item,
                            ),
                            icon: Icon(
                              AppIcons.recurring,
                              size: 18,
                              color: accent,
                            ),
                            label: Text(
                              'parar a partir deste mês',
                              style: AppTypography.body(
                                context,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmCancelRecurring(
    BuildContext sheetContext,
    BudgetOverviewItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        title: const Text('parar limite mensal?'),
        content: Text(
          'o histórico continua igual. ${_monthLabel(_month)} e os próximos deixam de herdar esse limite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('manter'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('parar'),
          ),
        ],
      ),
    );

    if (confirmed == true && sheetContext.mounted) {
      Navigator.of(sheetContext).pop(
        const _BudgetEditResult(
          amount: 0,
          scope: BudgetLimitScope.cancelFromMonth,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    if (_loading && !_hasLoadedOnce) {
      return ColoredBox(
        color: AppColors.background(brightness),
        child: const SafeArea(
          child: AppLoadingState(label: 'organizando seu planejamento'),
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return ColoredBox(
        color: AppColors.background(brightness),
        child: SafeArea(
          child: AppContentContainer.dashboard(
            fillHeight: true,
            child: _buildError(),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.background(brightness),
      child: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: desktop
              ? _buildDesktopLayout(brightness, layout)
              : _buildMobileLayout(brightness, layout),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(Brightness brightness, AppLayoutSize layout) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('plan-scroll'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 76),
        children: [
          _buildHeader(brightness, layout),
          if (_refreshing) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 12),
          _buildSummary(brightness),
          if (_budgetedCount == 0) ...[
            const SizedBox(height: 12),
            _buildNoPlan(brightness),
          ],
          const SizedBox(height: 10),
          _buildCategories(brightness),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(Brightness brightness, AppLayoutSize layout) {
    return Column(
      key: const ValueKey('plan-desktop-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: _buildHeader(brightness, layout),
        ),
        if (_refreshing) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 22),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    key: const ValueKey('plan-summary-column'),
                    children: [
                      _buildSummary(brightness),
                      if (_budgetedCount == 0) ...[
                        const SizedBox(height: 16),
                        _buildNoPlan(brightness),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 7,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    key: const ValueKey('plan-scroll'),
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 72),
                    children: [_buildCategories(brightness)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Brightness brightness, AppLayoutSize layout) {
    final primaryText = AppColors.primaryText(brightness);
    final compact = layout == AppLayoutSize.compact;

    final monthPicker = Container(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'mês anterior',
            onPressed: _saving ? null : () => _changeMonth(-1),
            icon: const Icon(AppIcons.chevronLeft),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              _monthLabel(_month),
              style: AppTypography.label(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
          ),
          IconButton(
            tooltip: 'próximo mês',
            onPressed: _saving ? null : () => _changeMonth(1),
            icon: const Icon(AppIcons.chevronRight),
          ),
        ],
      ),
    );

    const title = AppPageHeader(
      title: 'plano',
      subtitle: 'seu limite, seus gastos e o que ainda cabe neste mês',
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 10),
          _PlanModeToggle(
            projection: false,
            onProjection: widget.onProjectionRequested,
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: monthPicker),
          if (_isPastMonth) ...[
            const SizedBox(height: 10),
            _HistoricalPill(brightness: brightness),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 14),
              SizedBox(
                width: 260,
                child: _PlanModeToggle(
                  projection: false,
                  onProjection: widget.onProjectionRequested,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            monthPicker,
            if (_isPastMonth) ...[
              const SizedBox(height: 8),
              _HistoricalPill(brightness: brightness),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSummary(Brightness brightness) {
    final summary = _summary;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final progressColor = _progressColor(summary.progressState, brightness);
    final percentage = (summary.usageRatio * 100).round();
    final remainingLabel = summary.remainingAmount >= 0
        ? 'ainda pode gastar'
        : 'passou do planejado';
    final remainingColor = summary.remainingAmount < 0
        ? AppColors.expenseText(brightness)
        : primaryText;

    return Container(
      key: const ValueKey('plan-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.feature),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'resumo do mês',
            style: AppTypography.section(
              context,
              fontSize: 18,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            remainingLabel,
            style: AppTypography.label(
              context,
              fontSize: 11,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.money(summary.remainingAmount.abs()),
              style: AppTypography.money(
                context,
                fontSize: 28,
                color: remainingColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'planejado',
                  value: Formatters.money(summary.plannedAmount),
                  brightness: brightness,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'realizado',
                  value: Formatters.money(summary.actualAmount),
                  brightness: brightness,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'consumido',
                  value: summary.plannedAmount > 0 ? '$percentage%' : '—',
                  brightness: brightness,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.plannedAmount > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: summary.usageRatio.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: border.withValues(alpha: .65),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _summaryCopy(summary),
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: secondaryText,
              ),
            ),
          ] else
            Text(
              'defina limites nas subcategorias para acompanhar o mês',
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: secondaryText,
              ),
            ),
          if (widget.onFlexibleBudgetRequested != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('plan-open-flex-budget'),
                onPressed: widget.onFlexibleBudgetRequested,
                icon: const Icon(AppIcons.plan, size: 17),
                label: const Text('teto flexível'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoPlan(Brightness brightness) {
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: purple.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: purple.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.plan, color: purple, size: 24),
          const SizedBox(height: 10),
          Text(
            'nenhum limite definido para ${_monthLabel(_month)}',
            style: AppTypography.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'gastos realizados continuam aparecendo mesmo sem limite.',
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondaryText,
            ),
          ),
          if (!_isPastMonth) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _startPlanning,
              icon: const Icon(AppIcons.add, size: 18),
              label: const Text('começar planejamento'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategories(Brightness brightness) {
    return Column(
      key: const ValueKey('plan-categories'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'categorias',
          subtitle: 'toque para ver quanto ainda cabe em cada subcategoria',
        ),
        const SizedBox(height: 10),
        if (_parents.isEmpty)
          _buildCategoriesEmpty(brightness)
        else
          ..._parents.map(
            (parent) => _buildParentCard(parent, brightness),
          ),
      ],
    );
  }

  Widget _buildParentCard(
    BudgetOverviewItem parent,
    Brightness brightness,
  ) {
    final children = _childrenOf(parent);
    final expanded = _expandedCategoryIds.contains(parent.categoryId);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final familyColor = CategoryVisuals.colorFor(
      category: parent.categoryName,
      brightness: brightness,
    );
    final icon = CategoryVisuals.iconFor(category: parent.categoryName);
    final percentage = (parent.usageRatio * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('plan-parent-${parent.categoryId}'),
                onTap: children.isEmpty
                    ? null
                    : () => _toggleCategory(parent.categoryId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      CategoryIconBadge(
                        icon: icon,
                        color: familyColor,
                        size: 40,
                        iconSize: 20,
                        radius: 13,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parent.categoryName,
                              style: AppTypography.body(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              parent.hasBudget
                                  ? parent.remainingAmount >= 0
                                      ? '${Formatters.money(parent.remainingAmount)} ainda disponíveis'
                                      : '${Formatters.money(parent.remainingAmount.abs())} acima do planejado'
                                  : parent.hasActivity
                                      ? '${Formatters.money(parent.actualAmount)} realizado · sem limite agregado'
                                      : 'sem limites nas subcategorias',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                context,
                                fontSize: 10,
                                color: parent.hasBudget &&
                                        parent.remainingAmount < 0
                                    ? AppColors.expenseText(brightness)
                                    : secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (parent.hasBudget) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$percentage%',
                          style: AppTypography.label(
                            context,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _progressColor(
                              parent.progressState,
                              brightness,
                            ),
                          ),
                        ),
                      ],
                      if (children.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 180),
                          turns: expanded ? .25 : 0,
                          child: Icon(
                            AppIcons.chevronRight,
                            size: 20,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (parent.hasBudget)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    value: parent.progress,
                    minHeight: 4,
                    backgroundColor: border.withValues(alpha: .60),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progressColor(parent.progressState, brightness),
                    ),
                  ),
                ),
              ),
            if (children.isNotEmpty && expanded)
              Container(
                key: ValueKey('plan-children-${parent.categoryId}'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Column(
                  children: children
                      .map(
                        (child) => _buildChildCard(
                          parent,
                          child,
                          familyColor,
                          brightness,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard(
    BudgetOverviewItem parent,
    BudgetOverviewItem child,
    Color familyColor,
    Brightness brightness,
  ) {
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final icon = CategoryVisuals.iconFor(
      category: parent.categoryName,
      subcategory: child.categoryName,
    );
    final percentage = (child.usageRatio * 100).round();
    final progressColor = _progressColor(child.progressState, brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: AppColors.background(brightness).withValues(alpha: .35),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          key: ValueKey('plan-child-${child.categoryId}'),
          onTap: () => _editBudget(child),
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: border.withValues(alpha: .80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CategoryIconBadge(
                      icon: icon,
                      color: familyColor,
                      size: 36,
                      iconSize: 18,
                      radius: 11,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        child.categoryName,
                        style: AppTypography.body(
                          context,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                    ),
                    if (child.isRecurring)
                      _TinyPill(
                        icon: AppIcons.recurring,
                        label: child.isMonthlyOverride
                            ? 'todo mês · ajuste'
                            : 'todo mês',
                        color: AppColors.primaryPurple(brightness),
                      ),
                    if (!_isPastMonth) ...[
                      const SizedBox(width: 6),
                      Icon(
                        AppIcons.chevronRight,
                        size: 16,
                        color: secondaryText,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 9),
                if (child.hasBudget) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${Formatters.money(child.actualAmount)} de ${Formatters.money(child.plannedAmount)}',
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            color: primaryText,
                          ),
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: AppTypography.label(
                          context,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: progressColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: LinearProgressIndicator(
                      value: child.progress,
                      minHeight: 4,
                      backgroundColor: border.withValues(alpha: .60),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    child.remainingAmount >= 0
                        ? '${Formatters.money(child.remainingAmount)} restantes'
                        : '${Formatters.money(child.remainingAmount.abs())} acima do planejado',
                    style: AppTypography.label(
                      context,
                      fontSize: 10,
                      color: child.remainingAmount < 0
                          ? AppColors.expenseText(brightness)
                          : secondaryText,
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          child.hasActivity
                              ? '${Formatters.money(child.actualAmount)} realizado · sem limite'
                              : 'nenhum gasto neste mês · sem limite',
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            color: secondaryText,
                          ),
                        ),
                      ),
                      if (!_isPastMonth)
                        Text(
                          'definir',
                          style: AppTypography.label(
                            context,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: familyColor,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesEmpty(Brightness brightness) {
    return AppEmptyState(
      icon: AppIcons.categoryUnclassified,
      title: 'nenhuma categoria disponível para planejamento',
      description: 'ative ou crie categorias para começar a definir seus limites',
      accentColor: AppColors.primaryPurple(brightness),
    );
  }

  Widget _buildError() {
    return Center(
      child: AppErrorState(
        title: 'não consegui carregar seu planejamento',
        description: _error,
        onRetry: () => _load(initial: true),
      ),
    );
  }

  Color _progressColor(BudgetProgressState state, Brightness brightness) {
    return switch (state) {
      BudgetProgressState.noLimit => AppColors.secondaryText(brightness),
      BudgetProgressState.comfortable => AppColors.positiveText(brightness),
      BudgetProgressState.attention => AppColors.warningText(brightness),
      BudgetProgressState.exceeded => AppColors.expenseText(brightness),
    };
  }

  String _summaryCopy(BudgetMonthSummary summary) {
    if (summary.progressState == BudgetProgressState.exceeded) {
      return 'o realizado passou do total planejado para o mês';
    }
    if (summary.progressState == BudgetProgressState.attention) {
      return 'você já consumiu boa parte do que planejou para o mês';
    }
    return 'seu realizado continua dentro do total planejado';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.brightness,
  });

  final String label;
  final String value;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final border = AppColors.border(brightness);
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background(brightness).withValues(alpha: .38),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: border.withValues(alpha: .75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label(
              context,
              fontSize: 9,
              color: AppColors.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.money(
                context,
                fontSize: 13,
                color: AppColors.primaryText(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeChoice extends StatelessWidget {
  const _ScopeChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = AppColors.primaryPurple(brightness);
    final border = selected ? accent : AppColors.border(brightness);
    return Material(
      color: selected ? accent.withValues(alpha: .08) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? accent
                    : AppColors.secondaryText(brightness),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText(brightness),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.label(
                        context,
                        fontSize: 9,
                        color: AppColors.secondaryText(brightness),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.label(
              context,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricalPill extends StatelessWidget {
  const _HistoricalPill({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warningText(brightness).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        'somente consulta',
        style: AppTypography.label(
          context,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.warningText(brightness),
        ),
      ),
    );
  }
}

class _BudgetEditResult {
  const _BudgetEditResult({required this.amount, required this.scope});

  final double amount;
  final BudgetLimitScope scope;
}

double? _parseMoney(String value) {
  final normalized = value
      .trim()
      .replaceAll('R\$', '')
      .replaceAll(' ', '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return double.tryParse(normalized);
}

String _monthLabel(DateTime month) {
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${months[month.month - 1]} ${month.year}';
}

String _sortKey(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');
}

String _message(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}


class _PlanModeToggle extends StatelessWidget {
  const _PlanModeToggle({
    required this.projection,
    this.onProjection,
  });

  final bool projection;
  final VoidCallback? onProjection;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final accent = AppColors.primaryPurple(brightness);
    final secondary = AppColors.secondaryText(brightness);

    Widget item({
      required String label,
      required bool selected,
      required VoidCallback? onTap,
    }) {
      return Expanded(
        child: Material(
          color: selected ? accent.withValues(alpha: .13) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.label(
                  context,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : secondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('plan-mode-toggle'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          item(
            label: 'resumo',
            selected: !projection,
            onTap: null,
          ),
          item(
            label: 'projeção',
            selected: projection,
            onTap: projection ? null : onProjection,
          ),
        ],
      ),
    );
  }
}
