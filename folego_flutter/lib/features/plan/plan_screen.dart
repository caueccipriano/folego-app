import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';
import '../../data/repositories/folego_repository.dart';
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
  String? _error;

  List<BudgetOverviewItem> _items = [];

  final Set<String> _expandedParents = <String>{};

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _month = DateTime(
      now.year,
      now.month,
    );

    _load();
  }

  List<BudgetOverviewItem> get _parents {
    final result = _items.where((item) => item.isParent).toList();

    result.sort(
      (a, b) => _sortKey(
        a.categoryName,
      ).compareTo(
        _sortKey(b.categoryName),
      ),
    );

    return result;
  }

  List<BudgetOverviewItem> _childrenOf(
    BudgetOverviewItem parent,
  ) {
    final result = _items
        .where(
          (item) => item.parentId == parent.categoryId,
        )
        .toList();

    result.sort(
      (a, b) => _sortKey(
        a.categoryName,
      ).compareTo(
        _sortKey(b.categoryName),
      ),
    );

    return result;
  }

  double get _totalPlanned {
    return _parents.fold(
      0.0,
      (total, item) => total + item.plannedAmount,
    );
  }

  double get _totalActual {
    return _parents.fold(
      0.0,
      (total, item) => total + item.actualAmount,
    );
  }

  double get _totalRemaining => _totalPlanned - _totalActual;

  int get _budgetedCount {
    return _items
        .where(
          (item) => item.isSubcategory && item.hasBudget,
        )
        .length;
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

      if (!mounted) {
        return;
      }

      final parents = items.where((item) => item.isParent).toList();

      setState(() {
        _items = items;
        _loading = false;

        for (final parent in parents) {
          final children = items.where(
            (item) => item.parentId == parent.categoryId,
          );

          final hasRelevantChild = children.any(
            (child) => child.hasBudget || child.hasActivity,
          );

          if (hasRelevantChild) {
            _expandedParents.add(parent.categoryId);
          }
        }

        if (_expandedParents.isEmpty) {
          for (final parent in parents) {
            final hasChildren = items.any(
              (item) => item.parentId == parent.categoryId,
            );

            if (hasChildren) {
              _expandedParents.add(parent.categoryId);
              break;
            }
          }
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _changeMonth(
    int delta,
  ) async {
    setState(() {
      _month = DateTime(
        _month.year,
        _month.month + delta,
      );

      _expandedParents.clear();
    });

    await _load();
  }

  void _toggleParent(
    String categoryId,
  ) {
    setState(() {
      if (_expandedParents.contains(categoryId)) {
        _expandedParents.remove(categoryId);
      } else {
        _expandedParents.add(categoryId);
      }
    });
  }

  void _expandParent(
    String categoryId,
  ) {
    if (_expandedParents.contains(categoryId)) {
      return;
    }

    setState(() {
      _expandedParents.add(categoryId);
    });
  }

  String _monthLabel(
    DateTime date,
  ) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  double? _parseMoney(
    String text,
  ) {
    var normalized = text.trim().replaceAll(
          RegExp(r'[^0-9,.\-]'),
          '',
        );

    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains(',')) {
      normalized = normalized
          .replaceAll('.', '')
          .replaceAll(',', '.');
    }

    return double.tryParse(normalized);
  }

  Color _progressColor(
    BudgetOverviewItem item,
    Brightness brightness,
  ) {
    if (item.isOverBudget || item.status == 'critical') {
      return AppColors.expenseText(brightness);
    }

    if (item.status == 'warning') {
      return brightness == Brightness.dark
          ? AppColors.healthDark
          : AppColors.healthLight;
    }

    return AppColors.primaryPurple(brightness);
  }

  String _statusLabel(
    BudgetOverviewItem item,
  ) {
    if (!item.hasBudget) {
      if (item.hasActivity) {
        return '${Formatters.money(item.actualAmount)} gasto';
      }

      return '';
    }

    if (item.isOverBudget) {
      return 'acima do plano';
    }

    switch (item.status) {
      case 'critical':
        return 'quase no limite';

      case 'warning':
        return 'atenção';

      default:
        return 'dentro do plano';
    }
  }

  Future<void> _editBudget(
    BudgetOverviewItem item,
  ) async {
    final controller = TextEditingController(
      text: item.plannedAmount > 0
          ? item.plannedAmount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    String? validationError;

    final newAmount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            innerContext,
            setSheetState,
          ) {
            final brightness = Theme.of(innerContext).brightness;

            final primaryText = AppColors.primaryText(brightness);

            final secondaryText = AppColors.secondaryText(brightness);

            final border = AppColors.border(brightness);

            final parentName = item.parentName ?? item.categoryName;

            final familyColor = CategoryVisuals.colorFor(
              category: parentName,
              brightness: brightness,
            );

            final icon = CategoryVisuals.iconFor(
              category: parentName,
              subcategory: item.isSubcategory ? item.categoryName : null,
            );

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(innerContext).viewInsets.bottom + 24,
              ),
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

                  const SizedBox(height: 22),

                  Row(
                    children: [
                      CategoryIconBadge(
                        icon: icon,
                        color: familyColor,
                        size: 48,
                        iconSize: 23,
                        radius: 15,
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'planejar ${item.categoryName.toLowerCase()}',
                              style: AppTypography.section(
                                innerContext,
                                fontSize: 18,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.parentName ?? _monthLabel(_month),
                              style: AppTypography.body(
                                innerContext,
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
                      innerContext,
                      fontSize: 20,
                      color: primaryText,
                    ),
                    decoration: InputDecoration(
                      labelText: 'limite mensal',
                      prefixText: 'R\$ ',
                      errorText: validationError,
                    ),
                  ),

                  if (item.actualAmount > 0) ...[
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: familyColor.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: familyColor.withValues(alpha: .20),
                        ),
                      ),
                      child: Text(
                        'você já gastou '
                        '${Formatters.money(item.actualAmount)} '
                        'em ${item.categoryName.toLowerCase()}',
                        style: AppTypography.body(
                          innerContext,
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
                          validationError = 'Digite um valor válido.';
                        });

                        return;
                      }

                      Navigator.of(innerContext).pop(amount);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.iconOnLime,
                    ),
                    child: const Text('salvar planejamento'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (newAmount == null || !mounted) {
      return;
    }

    try {
      await widget.repository.setBudgetItem(
        spaceId: widget.spaceId,
        periodMonth: _month,
        categoryId: item.categoryId,
        plannedAmount: newAmount,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newAmount == 0
                ? 'limite de ${item.categoryName.toLowerCase()} removido'
                : '${item.categoryName}: ${Formatters.money(newAmount)}',
          ),
        ),
      );

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'não consegui salvar: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final brightness = Theme.of(context).brightness;

    return ColoredBox(
      color: AppColors.background(brightness),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 760,
            ),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  18,
                  22,
                  18,
                  140,
                ),
                children: [
                  _buildHeader(brightness),

                  const SizedBox(height: 24),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 80,
                      ),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    _buildError(brightness)
                  else ...[
                    _buildSummary(brightness),

                    const SizedBox(height: 30),

                    _buildCategoriesHeader(brightness),

                    const SizedBox(height: 14),

                    if (_parents.isEmpty)
                      _buildEmpty(brightness)
                    else
                      ..._parents.map(
                        (parent) => _buildCategoryTree(
                          parent,
                          brightness,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    Brightness brightness,
  ) {
    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'plano',
                style: AppTypography.display(
                  context,
                  fontSize: 28,
                  color: primaryText,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: border,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'mês anterior',
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(
                      AppIcons.chevronLeft,
                    ),
                  ),
                  IconButton(
                    tooltip: 'próximo mês',
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(
                      AppIcons.chevronRight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          'organize o mês sem transformar sua vida em uma planilha',
          style: AppTypography.body(
            context,
            fontSize: 13,
            color: secondaryText,
          ),
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: AppColors.lime.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.calendar,
                size: 17,
                color: AppColors.lime,
              ),
              const SizedBox(width: 7),
              Text(
                _monthLabel(_month),
                style: AppTypography.label(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(
    Brightness brightness,
  ) {
    final purple = AppColors.primaryPurple(brightness);

    final remaining = _totalRemaining;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: purple,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'seu plano do mês',
            style: AppTypography.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: .75),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            remaining >= 0
                ? Formatters.money(remaining)
                : '${Formatters.money(remaining.abs())} acima',
            style: AppTypography.money(
              context,
              fontSize: 29,
              color: AppColors.lime,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            remaining >= 0
                ? 'ainda disponíveis no orçamento'
                : 'acima do que você planejou',
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: Colors.white.withValues(alpha: .75),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  'planejado',
                  _totalPlanned,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryMetric(
                  'realizado',
                  _totalActual,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                const Icon(
                  AppIcons.plan,
                  color: Colors.white,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '$_budgetedCount '
                    '${_budgetedCount == 1 ? 'subcategoria planejada' : 'subcategorias planejadas'}',
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(
    String label,
    double value,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label(
              context,
              fontSize: 10,
              color: Colors.white.withValues(alpha: .70),
            ),
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.money(value),
              style: AppTypography.money(
                context,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesHeader(
    Brightness brightness,
  ) {
    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          'defina seus limites nas subcategorias',
          style: AppTypography.body(
            context,
            fontSize: 12,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTree(
    BudgetOverviewItem parent,
    Brightness brightness,
  ) {
    final children = _childrenOf(parent);

    final expanded = _expandedParents.contains(parent.categoryId);

    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final familyColor = CategoryVisuals.colorFor(
      category: parent.categoryName,
      brightness: brightness,
    );

    final parentIcon = CategoryVisuals.iconFor(
      category: parent.categoryName,
    );

    final progressColor = _progressColor(
      parent,
      brightness,
    );

    final status = _statusLabel(parent);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: children.isEmpty
                    ? null
                    : () => _toggleParent(
                          parent.categoryId,
                        ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      CategoryIconBadge(
                        icon: parentIcon,
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
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),

                            const SizedBox(height: 5),

                            if (parent.hasBudget)
                              Text(
                                '${Formatters.money(parent.plannedAmount)} planejado',
                                style: AppTypography.label(
                                  context,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: familyColor,
                                ),
                              )
                            else ...[
                              if (status.isNotEmpty) ...[
                                Text(
                                  status,
                                  style: AppTypography.label(
                                    context,
                                    fontSize: 10,
                                    color: secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],

                              if (children.isNotEmpty)
                                _LimitActionChip(
                                  label: 'definir limite',
                                  color: familyColor,
                                  showChevron: false,
                                  onTap: () => _expandParent(
                                    parent.categoryId,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),

                      if (parent.actualAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Formatters.money(
                                  parent.actualAmount,
                                ),
                                style: AppTypography.money(
                                  context,
                                  fontSize: 12,
                                  color: primaryText,
                                ),
                              ),
                              Text(
                                'gasto',
                                style: AppTypography.label(
                                  context,
                                  fontSize: 9,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (children.isNotEmpty)
                        AnimatedRotation(
                          duration: const Duration(
                            milliseconds: 180,
                          ),
                          turns: expanded ? .25 : 0,
                          child: Icon(
                            AppIcons.chevronRight,
                            size: 20,
                            color: secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (parent.hasBudget)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  14,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: parent.progress,
                    minHeight: 5,
                    backgroundColor: border.withValues(alpha: .55),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressColor,
                    ),
                  ),
                ),
              ),

            if (children.isNotEmpty && expanded)
              _buildChildren(
                parent: parent,
                children: children,
                brightness: brightness,
                familyColor: familyColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildren({
    required BudgetOverviewItem parent,
    required List<BudgetOverviewItem> children,
    required Brightness brightness,
    required Color familyColor,
  }) {
    final border = AppColors.border(brightness);

    final childActualTotal = children.fold<double>(
      0,
      (total, child) => total + child.actualAmount,
    );

    final uncategorized = (parent.actualAmount - childActualTotal)
        .clamp(
          0.0,
          double.infinity,
        )
        .toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: border,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        12,
        5,
        12,
        10,
      ),
      child: Column(
        children: [
          ...children.map(
            (child) => _buildChildRow(
              parent: parent,
              child: child,
              brightness: brightness,
              familyColor: familyColor,
            ),
          ),

          if (uncategorized > .009)
            _buildUncategorizedRow(
              parent: parent,
              amount: uncategorized,
              brightness: brightness,
              familyColor: familyColor,
            ),
        ],
      ),
    );
  }

  Widget _buildChildRow({
    required BudgetOverviewItem parent,
    required BudgetOverviewItem child,
    required Brightness brightness,
    required Color familyColor,
  }) {
    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final border = AppColors.border(brightness);

    final progressColor = _progressColor(
      child,
      brightness,
    );

    final percentage = (child.usageRatio * 100).round();

    final childIcon = CategoryVisuals.iconFor(
      category: parent.categoryName,
      subcategory: child.categoryName,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editBudget(child),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 10,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CategoryIconBadge(
                      icon: childIcon,
                      color: familyColor,
                      size: 36,
                      iconSize: 19,
                      radius: 11,
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.categoryName,
                            style: AppTypography.body(
                              context,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),

                          if (child.hasBudget || child.hasActivity) ...[
                            const SizedBox(height: 3),
                            Text(
                              child.hasBudget
                                  ? '${Formatters.money(child.actualAmount)} de ${Formatters.money(child.plannedAmount)}'
                                  : '${Formatters.money(child.actualAmount)} gasto',
                              style: AppTypography.label(
                                context,
                                fontSize: 10,
                                color: child.hasBudget
                                    ? progressColor
                                    : secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    if (child.hasBudget)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.money(
                              child.plannedAmount,
                            ),
                            style: AppTypography.label(
                              context,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            AppIcons.chevronRight,
                            size: 16,
                            color: secondaryText,
                          ),
                        ],
                      )
                    else
                      _LimitActionChip(
                        label: 'definir limite',
                        color: familyColor,
                        onTap: () => _editBudget(child),
                      ),
                  ],
                ),

                if (child.hasBudget) ...[
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: child.progress,
                            minHeight: 4,
                            backgroundColor: border.withValues(alpha: .55),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressColor,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        '$percentage%',
                        style: AppTypography.label(
                          context,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: secondaryText,
                        ),
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

  Widget _buildUncategorizedRow({
    required BudgetOverviewItem parent,
    required double amount,
    required Brightness brightness,
    required Color familyColor,
  }) {
    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final icon = CategoryVisuals.iconFor(
      category: parent.categoryName,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        7,
        8,
        7,
        4,
      ),
      child: Row(
        children: [
          CategoryIconBadge(
            icon: icon,
            color: familyColor,
            size: 36,
            iconSize: 18,
            radius: 11,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sem subcategoria',
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'lançado direto em ${parent.categoryName.toLowerCase()}',
                  style: AppTypography.label(
                    context,
                    fontSize: 9,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),

          Text(
            Formatters.money(amount),
            style: AppTypography.money(
              context,
              fontSize: 11,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    Brightness brightness,
  ) {
    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.warning,
            size: 38,
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
              color: primaryText,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _load,
            child: const Text(
              'tentar novamente',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(
    Brightness brightness,
  ) {
    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.plan,
            size: 40,
            color: AppColors.primaryPurple(brightness),
          ),
          const SizedBox(height: 12),
          Text(
            'nenhuma categoria encontrada',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'suas categorias aparecerão aqui',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  String _sortKey(
    String value,
  ) {
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

class _LimitActionChip extends StatelessWidget {
  const _LimitActionChip({
    required this.label,
    required this.color,
    required this.onTap,
    this.showChevron = true,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: color.withValues(alpha: .26),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.label(
                  context,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),

              if (showChevron) ...[
                const SizedBox(width: 4),
                Icon(
                  AppIcons.chevronRight,
                  size: 13,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}