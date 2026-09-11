import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';
import '../../data/repositories/folego_repository.dart';

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

    _month = DateTime(now.year, now.month);

    _load();
  }

  List<BudgetOverviewItem> get _parents {
    final result = _items.where((item) => item.isParent).toList();

    result.sort(
      (a, b) => _sortKey(a.categoryName).compareTo(_sortKey(b.categoryName)),
    );

    return result;
  }

  List<BudgetOverviewItem> _childrenOf(BudgetOverviewItem parent) {
    final result = _items
        .where((item) => item.parentId == parent.categoryId)
        .toList();

    result.sort(
      (a, b) => _sortKey(a.categoryName).compareTo(_sortKey(b.categoryName)),
    );

    return result;
  }

  double get _totalPlanned {
    return _parents.fold(0.0, (total, item) => total + item.plannedAmount);
  }

  double get _totalActual {
    return _parents.fold(0.0, (total, item) => total + item.actualAmount);
  }

  double get _totalRemaining {
    return _totalPlanned - _totalActual;
  }

  int get _budgetedCount {
    return _parents.where((item) => item.hasBudget).length;
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

        if (_expandedParents.isEmpty) {
          final relevant = parents.where(
            (item) => item.hasBudget || item.hasActivity,
          );

          _expandedParents.addAll(relevant.map((item) => item.categoryId));

          if (_expandedParents.isEmpty && parents.isNotEmpty) {
            final firstWithChildren = parents.where(
              (parent) =>
                  items.any((item) => item.parentId == parent.categoryId),
            );

            if (firstWithChildren.isNotEmpty) {
              _expandedParents.add(firstWithChildren.first.categoryId);
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

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });

    await _load();
  }

  void _toggleParent(String categoryId) {
    setState(() {
      if (_expandedParents.contains(categoryId)) {
        _expandedParents.remove(categoryId);
      } else {
        _expandedParents.add(categoryId);
      }
    });
  }

  String _monthLabel(DateTime date) {
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

    return '${months[date.month - 1]} '
        '${date.year}';
  }

  double? _parseMoney(String text) {
    var normalized = text.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');

    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(normalized);
  }

  Color _progressColor(BudgetOverviewItem item, Brightness brightness) {
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

  String _statusLabel(BudgetOverviewItem item) {
    if (!item.hasBudget) {
      return item.hasActivity
          ? '${Formatters.money(item.actualAmount)} gasto'
          : 'Sem limite';
    }

    if (item.isOverBudget) {
      return 'Acima do plano';
    }

    switch (item.status) {
      case 'critical':
        return 'Quase no limite';

      case 'warning':
        return 'Atenção';

      default:
        return 'Dentro do plano';
    }
  }

  Future<void> _editBudget(BudgetOverviewItem item) async {
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
          builder: (innerContext, setSheetState) {
            final sheetBrightness = Theme.of(innerContext).brightness;

            final primaryText = AppColors.primaryText(sheetBrightness);

            final secondaryText = AppColors.secondaryText(sheetBrightness);

            final border = AppColors.border(sheetBrightness);

            final familyColor = CategoryVisuals.colorFor(
              category: item.categoryName,
              brightness: sheetBrightness,
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
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: familyColor.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          CategoryVisuals.iconFor(category: item.categoryName),
                          color: familyColor,
                          size: 23,
                        ),
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Planejar ${item.categoryName}',
                              style: AppTypography.section(
                                innerContext,
                                fontSize: 18,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _monthLabel(_month),
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
                      labelText: 'Limite mensal',
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
                      child: Row(
                        children: [
                          Icon(
                            CategoryVisuals.iconFor(
                              category: item.categoryName,
                            ),
                            size: 19,
                            color: familyColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Você já gastou '
                              '${Formatters.money(item.actualAmount)} '
                              'nesta categoria.',
                              style: AppTypography.body(
                                innerContext,
                                fontSize: 12,
                                color: secondaryText,
                              ),
                            ),
                          ),
                        ],
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
                    child: const Text('Salvar planejamento'),
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
                ? 'Limite de ${item.categoryName} removido.'
                : '${item.categoryName} planejado em '
                      '${Formatters.money(newAmount)}.',
          ),
        ),
      );

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não consegui salvar: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final background = AppColors.background(brightness);

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
                children: [
                  _buildHeader(brightness),

                  const SizedBox(height: 24),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator()),
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
                        (parent) => _buildCategoryTree(parent, brightness),
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

  Widget _buildHeader(Brightness brightness) {
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
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Mês anterior',
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(AppIcons.chevronLeft),
                  ),
                  IconButton(
                    tooltip: 'Próximo mês',
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(AppIcons.chevronRight),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          'Organize o mês sem transformar '
          'sua vida em uma planilha.',
          style: AppTypography.body(
            context,
            fontSize: 13,
            color: secondaryText,
          ),
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.lime.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.calendar, size: 17, color: AppColors.lime),
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

  Widget _buildSummary(Brightness brightness) {
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
              Expanded(child: _summaryMetric('Planejado', _totalPlanned)),
              const SizedBox(width: 10),
              Expanded(child: _summaryMetric('Realizado', _totalActual)),
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
                const Icon(AppIcons.plan, color: Colors.white, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '$_budgetedCount '
                    '${_budgetedCount == 1 ? 'categoria planejada' : 'categorias planejadas'}',
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

  Widget _summaryMetric(String label, double value) {
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

  Widget _buildCategoriesHeader(Brightness brightness) {
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
          'Abra uma categoria para ver suas subcategorias.',
          style: AppTypography.body(
            context,
            fontSize: 12,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTree(BudgetOverviewItem parent, Brightness brightness) {
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

    final progressColor = _progressColor(parent, brightness);

    final percentage = (parent.usageRatio * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: familyColor.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          CategoryVisuals.iconFor(
                            category: parent.categoryName,
                          ),
                          color: familyColor,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: children.isEmpty
                              ? null
                              : () => _toggleParent(parent.categoryId),
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
                              const SizedBox(height: 3),
                              Text(
                                _statusLabel(parent),
                                style: AppTypography.label(
                                  context,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: progressColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      TextButton(
                        onPressed: () => _editBudget(parent),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryText,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        child: Text(
                          parent.hasBudget
                              ? Formatters.money(parent.plannedAmount)
                              : 'Definir',
                          style: AppTypography.label(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                      ),

                      if (children.isNotEmpty)
                        IconButton(
                          tooltip: expanded ? 'Recolher' : 'Ver subcategorias',
                          onPressed: () => _toggleParent(parent.categoryId),
                          visualDensity: VisualDensity.compact,
                          icon: AnimatedRotation(
                            duration: const Duration(milliseconds: 180),
                            turns: expanded ? .25 : 0,
                            child: Icon(
                              AppIcons.chevronRight,
                              size: 19,
                              color: secondaryText,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (parent.hasBudget || parent.hasActivity) ...[
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Gasto ${Formatters.money(parent.actualAmount)}',
                            style: AppTypography.label(
                              context,
                              fontSize: 10,
                              color: secondaryText,
                            ),
                          ),
                        ),
                        if (parent.hasBudget)
                          Text(
                            '$percentage%',
                            style: AppTypography.label(
                              context,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                      ],
                    ),

                    if (parent.hasBudget) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: parent.progress,
                          minHeight: 6,
                          backgroundColor: border.withValues(alpha: .55),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
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

    final uncategorized = (parent.actualAmount - childActualTotal).clamp(
      0.0,
      double.infinity,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 7),

          Container(
            width: 2,
            height: 30,
            decoration: BoxDecoration(
              color: familyColor.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          const SizedBox(width: 13),

          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: familyColor.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              CategoryVisuals.iconFor(
                category: parent.categoryName,
                subcategory: child.categoryName,
              ),
              size: 18,
              color: familyColor,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              child.categoryName,
              style: AppTypography.body(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryText,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Text(
            child.actualAmount > 0 ? Formatters.money(child.actualAmount) : '—',
            style: AppTypography.money(
              context,
              fontSize: 12,
              color: child.actualAmount > 0 ? primaryText : secondaryText,
            ),
          ),
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 7),
          Container(
            width: 2,
            height: 30,
            decoration: BoxDecoration(
              color: familyColor.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 13),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: familyColor.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              CategoryVisuals.iconFor(category: parent.categoryName),
              size: 18,
              color: familyColor,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sem subcategoria',
                  style: AppTypography.body(
                    context,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                ),
                Text(
                  'gastos registrados direto em ${parent.categoryName}',
                  style: AppTypography.label(
                    context,
                    fontSize: 9,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Formatters.money(amount),
            style: AppTypography.money(
              context,
              fontSize: 12,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Brightness brightness) {
    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
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
            'Não consegui carregar seu planejamento.',
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
          FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }

  Widget _buildEmpty(Brightness brightness) {
    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
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
            'Nenhuma categoria encontrada.',
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
            'Suas categorias aparecerão aqui.',
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
