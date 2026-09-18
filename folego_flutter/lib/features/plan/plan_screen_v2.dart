import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_budget.dart';
import '../../shared/widgets/category_icon_badge.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late DateTime _month;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<BudgetOverviewItem> _items = const [];
  final Set<String> _expandedParents = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  List<BudgetOverviewItem> get _parents {
    final items = _items.where((item) => item.isParent).toList();
    items.sort((a, b) => _sortKey(a.categoryName).compareTo(_sortKey(b.categoryName)));
    return items;
  }

  List<BudgetOverviewItem> _childrenOf(BudgetOverviewItem parent) {
    final items = _items
        .where((item) => item.parentId == parent.categoryId)
        .toList();
    items.sort((a, b) => _sortKey(a.categoryName).compareTo(_sortKey(b.categoryName)));
    return items;
  }

  BudgetMonthSummary get _summary => BudgetMonthSummary.fromItems(_items);

  int get _budgetedCount => _items
      .where((item) => item.isSubcategory && item.hasBudget)
      .length;

  bool get _isPastMonth {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    return _month.isBefore(current);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await widget.repository.getBudgetOverview(
        spaceId: widget.spaceId,
        periodMonth: _month,
      );

      if (!mounted) return;

      final parents = items.where((item) => item.isParent).toList();
      setState(() {
        _items = items;
        _loading = false;

        for (final parent in parents) {
          final children = items.where(
            (item) => item.parentId == parent.categoryId,
          );
          if (children.any((child) => child.hasBudget || child.hasActivity)) {
            _expandedParents.add(parent.categoryId);
          }
        }

        if (_expandedParents.isEmpty) {
          for (final parent in parents) {
            if (items.any((item) => item.parentId == parent.categoryId)) {
              _expandedParents.add(parent.categoryId);
              break;
            }
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _expandedParents.clear();
    });
    await _load();
  }

  void _toggleParent(String id) {
    setState(() {
      if (_expandedParents.contains(id)) {
        _expandedParents.remove(id);
      } else {
        _expandedParents.add(id);
      }
    });
  }

  void _startPlanning() {
    for (final parent in _parents) {
      final children = _childrenOf(parent);
      if (children.isEmpty) continue;
      if (!_expandedParents.contains(parent.categoryId)) {
        setState(() => _expandedParents.add(parent.categoryId));
      }
      _editBudget(children.first);
      return;
    }
  }

  Future<void> _editBudget(BudgetOverviewItem item) async {
    if (_saving) return;

    if (_isPastMonth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('meses anteriores ficam somente para consulta'),
        ),
      );
      return;
    }

    final result = await _showBudgetSheet(item);
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.repository.setBudgetLimit(
        spaceId: widget.spaceId,
        periodMonth: _month,
        categoryId: item.categoryId,
        plannedAmount: result.amount,
        scope: result.scope,
      );

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );

      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('não consegui salvar: ${_message(error)}')),
      );
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
                    MediaQuery.of(context).viewInsets.bottom + 22,
                  ),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(color: border),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            CategoryIconBadge(
                              icon: icon,
                              color: familyColor,
                              size: 46,
                              iconSize: 22,
                              radius: 14,
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
                            final first = _ScopeChoice(
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
                            final second = _ScopeChoice(
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
                                  first,
                                  const SizedBox(height: 8),
                                  second,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: first),
                                const SizedBox(width: 8),
                                Expanded(child: second),
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
                              borderRadius: BorderRadius.circular(16),
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
    ).whenComplete(controller.dispose);
  }

  Future<void> _confirmCancelRecurring(
    BuildContext sheetContext,
    BudgetOverviewItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) {
        final brightness = Theme.of(context).brightness;
        return AlertDialog(
          title: Text(
            'parar limite mensal?',
            style: AppTypography.section(context, fontSize: 18),
          ),
          content: Text(
            'o histórico continua igual. ${_monthLabel(_month)} e os próximos deixam de herdar esse limite.',
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: AppColors.secondaryText(brightness),
            ),
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
        );
      },
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
    final useColumns =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    return ColoredBox(
      color: AppColors.background(brightness),
      child: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(0, 22, 0, 140),
              children: [
                _buildHeader(brightness, layout),
                const SizedBox(height: 24),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 90),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _buildError(brightness)
                else if (useColumns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildSummary(brightness),
                            if (_budgetedCount == 0) ...[
                              const SizedBox(height: 16),
                              _buildNoPlan(brightness),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 7,
                        child: _buildCategories(brightness),
                      ),
                    ],
                  )
                else ...[
                  _buildSummary(brightness),
                  if (_budgetedCount == 0) ...[
                    const SizedBox(height: 16),
                    _buildNoPlan(brightness),
                  ],
                  const SizedBox(height: 28),
                  _buildCategories(brightness),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Brightness brightness, AppLayoutSize layout) {
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final compact = layout == AppLayoutSize.compact;

    final monthPicker = Container(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(16),
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
          Semantics(
            label: 'mês selecionado ${_monthLabel(_month)}',
            child: Padding(
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
          ),
          IconButton(
            tooltip: 'próximo mês',
            onPressed: _saving ? null : () => _changeMonth(1),
            icon: const Icon(AppIcons.chevronRight),
          ),
        ],
      ),
    );

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'plano',
          style: AppTypography.display(
            context,
            fontSize: 28,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'quanto você quer poder gastar neste mês e como está indo',
          style: AppTypography.body(
            context,
            fontSize: 13,
            color: secondaryText,
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 16),
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
        Expanded(child: title),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'resumo do mês',
            style: AppTypography.section(
              context,
              fontSize: 19,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 520 ? 2 : 4;
              const gap = 10.0;
              final width =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _Metric(
                    width: width,
                    label: 'planejado',
                    value: Formatters.money(summary.plannedAmount),
                    brightness: brightness,
                  ),
                  _Metric(
                    width: width,
                    label: 'realizado',
                    value: Formatters.money(summary.actualAmount),
                    brightness: brightness,
                  ),
                  _Metric(
                    width: width,
                    label: summary.remainingAmount >= 0
                        ? 'restante'
                        : 'acima',
                    value: Formatters.money(summary.remainingAmount.abs()),
                    brightness: brightness,
                  ),
                  _Metric(
                    width: width,
                    label: 'consumido',
                    value: summary.plannedAmount > 0 ? '$percentage%' : '—',
                    brightness: brightness,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (summary.plannedAmount > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
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
        ],
      ),
    );
  }

  Widget _buildNoPlan(Brightness brightness) {
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple(brightness).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryPurple(brightness).withValues(alpha: .18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.plan,
            color: AppColors.primaryPurple(brightness),
            size: 24,
          ),
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
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'categorias',
          style: AppTypography.section(
            context,
            fontSize: 20,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'parents resumem; limites são definidos somente nas subcategorias',
          style: AppTypography.body(
            context,
            fontSize: 12,
            color: secondaryText,
          ),
        ),
        const SizedBox(height: 14),
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
    final expanded = _expandedParents.contains(parent.categoryId);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final familyColor = CategoryVisuals.colorFor(
      category: parent.categoryName,
      brightness: brightness,
    );
    final icon = CategoryVisuals.iconFor(category: parent.categoryName);
    final budgetedActual = children
        .where((child) => child.hasBudget)
        .fold<double>(0, (total, child) => total + child.actualAmount);
    final budgetUsageRatio = parent.plannedAmount > 0
        ? budgetedActual / parent.plannedAmount
        : 0.0;
    final percentage = (budgetUsageRatio * 100).round();
    final budgetProgressState = parent.plannedAmount <= 0
        ? BudgetProgressState.noLimit
        : budgetUsageRatio > 1
            ? BudgetProgressState.exceeded
            : budgetUsageRatio >= .70
                ? BudgetProgressState.attention
                : BudgetProgressState.comfortable;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: children.isEmpty
                    ? null
                    : () => _toggleParent(parent.categoryId),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      CategoryIconBadge(
                        icon: icon,
                        color: familyColor,
                        size: 44,
                        iconSize: 22,
                        radius: 14,
                      ),
                      const SizedBox(width: 12),
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
                            const SizedBox(height: 4),
                            Text(
                              parent.hasBudget
                                  ? '${Formatters.money(parent.actualAmount)} gastos no total'
                                  : parent.hasActivity
                                      ? '${Formatters.money(parent.actualAmount)} realizado · sem limite agregado'
                                      : 'sem limites nas subcategorias',
                              style: AppTypography.label(
                                context,
                                fontSize: 10,
                                color: secondaryText,
                              ),
                            ),
                            if (parent.hasBudget) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${Formatters.money(budgetedActual)} de ${Formatters.money(parent.plannedAmount)} nos limites definidos',
                                style: AppTypography.label(
                                  context,
                                  fontSize: 9,
                                  color: secondaryText,
                                ),
                              ),
                            ],
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
                              budgetProgressState,
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: budgetUsageRatio.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: border.withValues(alpha: .60),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progressColor(budgetProgressState, brightness),
                    ),
                  ),
                ),
              ),
            if (children.isNotEmpty && expanded)
              _buildChildren(parent, children, familyColor, brightness),
          ],
        ),
      ),
    );
  }

  Widget _buildChildren(
    BudgetOverviewItem parent,
    List<BudgetOverviewItem> children,
    Color familyColor,
    Brightness brightness,
  ) {
    final childActual = children.fold<double>(
      0,
      (total, child) => total + child.actualAmount,
    );
    final directParentActual = (parent.actualAmount - childActual)
        .clamp(0.0, double.infinity)
        .toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border(brightness)),
        ),
      ),
      child: Column(
        children: [
          ...children.map(
            (child) => _buildChildCard(
              parent,
              child,
              familyColor,
              brightness,
            ),
          ),
          if (directParentActual > .009)
            _DirectParentActivity(
              parentName: parent.categoryName,
              amount: directParentActual,
              familyColor: familyColor,
              brightness: brightness,
            ),
        ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.background(brightness).withValues(alpha: .35),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: () => _editBudget(child),
          borderRadius: BorderRadius.circular(17),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: border.withValues(alpha: .80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryIconBadge(
                      icon: icon,
                      color: familyColor,
                      size: 38,
                      iconSize: 19,
                      radius: 12,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
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
                              if (!_isPastMonth)
                                Icon(
                                  AppIcons.chevronRight,
                                  size: 16,
                                  color: secondaryText,
                                ),
                            ],
                          ),
                          if (child.isRecurring) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 5,
                              children: [
                                _TinyPill(
                                  icon: AppIcons.recurring,
                                  label: 'todo mês',
                                  color: AppColors.primaryPurple(brightness),
                                ),
                                if (child.isMonthlyOverride)
                                  _TinyPill(
                                    icon: AppIcons.calendar,
                                    label: 'ajuste deste mês',
                                    color: secondaryText,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                      const SizedBox(width: 8),
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
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: child.progress,
                      minHeight: 5,
                      backgroundColor: border.withValues(alpha: .60),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  const SizedBox(height: 6),
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
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child.hasActivity
                                  ? '${Formatters.money(child.actualAmount)} realizado'
                                  : 'nenhum gasto neste mês',
                              style: AppTypography.body(
                                context,
                                fontSize: 11,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'sem limite definido',
                              style: AppTypography.label(
                                context,
                                fontSize: 10,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isPastMonth)
                        _LimitAction(
                          color: familyColor,
                          onTap: () => _editBudget(child),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(Brightness brightness) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.warning,
            size: 36,
            color: AppColors.expenseText(brightness),
          ),
          const SizedBox(height: 12),
          Text(
            'não consegui carregar seu planejamento',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: AppColors.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _load,
            child: const Text('tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesEmpty(Brightness brightness) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.plan,
            size: 36,
            color: AppColors.primaryPurple(brightness),
          ),
          const SizedBox(height: 10),
          Text(
            'nenhuma categoria disponível',
            style: AppTypography.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(brightness),
            ),
          ),
        ],
      ),
    );
  }

  Color _progressColor(BudgetProgressState state, Brightness brightness) {
    switch (state) {
      case BudgetProgressState.comfortable:
        return AppColors.positiveText(brightness);
      case BudgetProgressState.attention:
        return AppColors.primaryPurple(brightness);
      case BudgetProgressState.exceeded:
        return AppColors.expenseText(brightness);
      case BudgetProgressState.noLimit:
        return AppColors.secondaryText(brightness);
    }
  }

  String _summaryCopy(BudgetMonthSummary summary) {
    switch (summary.progressState) {
      case BudgetProgressState.comfortable:
        return '${Formatters.money(summary.remainingAmount)} ainda planejados para o mês';
      case BudgetProgressState.attention:
        return '${(summary.usageRatio * 100).round()}% do planejamento já foi usado';
      case BudgetProgressState.exceeded:
        return '${Formatters.money(summary.remainingAmount.abs())} acima do planejado';
      case BudgetProgressState.noLimit:
        return 'nenhum limite definido';
    }
  }

  double? _parseMoney(String text) {
    var normalized = text.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (normalized.isEmpty) return 0;
    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  String _monthLabel(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }

  String _message(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _sortKey(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }
}

class _BudgetEditResult {
  const _BudgetEditResult({required this.amount, required this.scope});

  final double amount;
  final BudgetLimitScope scope;
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
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);

    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: Material(
        color: selected
            ? accent.withValues(alpha: .10)
            : AppColors.background(brightness).withValues(alpha: .35),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? accent : border),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? AppIcons.check : icon,
                  size: 20,
                  color: selected ? accent : secondaryText,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.label(
                          context,
                          fontSize: 9,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.label,
    required this.value,
    required this.brightness,
  });

  final double width;
  final String label;
  final String value;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background(brightness).withValues(alpha: .45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border(brightness).withValues(alpha: .75),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.label(
                context,
                fontSize: 9,
                color: AppColors.secondaryText(brightness),
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTypography.money(
                  context,
                  fontSize: 15,
                  color: AppColors.primaryText(brightness),
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
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

class _LimitAction extends StatelessWidget {
  const _LimitAction({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            'definir limite',
            style: AppTypography.label(
              context,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoricalPill extends StatelessWidget {
  const _HistoricalPill({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.secondaryText(brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.calendar, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            'histórico · somente leitura',
            style: AppTypography.label(
              context,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectParentActivity extends StatelessWidget {
  const _DirectParentActivity({
    required this.parentName,
    required this.amount,
    required this.familyColor,
    required this.brightness,
  });

  final String parentName;
  final double amount;
  final Color familyColor;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.border(brightness).withValues(alpha: .70),
        ),
      ),
      child: Row(
        children: [
          Icon(AppIcons.info, size: 17, color: familyColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'sem subcategoria · lançado direto em ${parentName.toLowerCase()}',
              style: AppTypography.label(
                context,
                fontSize: 9,
                color: AppColors.secondaryText(brightness),
              ),
            ),
          ),
          Text(
            Formatters.money(amount),
            style: AppTypography.money(
              context,
              fontSize: 10,
              color: AppColors.primaryText(brightness),
            ),
          ),
        ],
      ),
    );
  }
}
