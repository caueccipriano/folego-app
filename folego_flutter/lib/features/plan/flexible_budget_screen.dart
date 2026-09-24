import 'package:flutter/material.dart';

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
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_section_header.dart';

class FlexibleBudgetScreen extends StatefulWidget {
  const FlexibleBudgetScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<FlexibleBudgetScreen> createState() => _FlexibleBudgetScreenState();
}

class _FlexibleBudgetScreenState extends State<FlexibleBudgetScreen> {
  late DateTime _month;
  FlexibleBudgetOverview? _overview;
  List<BudgetOverviewItem> _items = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  bool get _isPastMonth {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  List<BudgetOverviewItem> get _flexibleItems {
    final result = _items
        .where(
          (item) =>
              item.isSubcategory &&
              !item.essential &&
              (item.hasActivity || item.hasBudget),
        )
        .toList();
    result.sort((a, b) {
      final activity = b.actualAmount.compareTo(a.actualAmount);
      if (activity != 0) return activity;
      return a.categoryName.toLowerCase().compareTo(b.categoryName.toLowerCase());
    });
    return result;
  }

  int get _activeWithoutLimit => _flexibleItems
      .where((item) => item.hasActivity && !item.hasBudget)
      .length;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        widget.repository.getFlexibleBudgetOverview(
          spaceId: widget.spaceId,
          periodMonth: _month,
        ),
        widget.repository.getBudgetOverview(
          spaceId: widget.spaceId,
          periodMonth: _month,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = values[0] as FlexibleBudgetOverview;
        _items = values[1] as List<BudgetOverviewItem>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'não consegui carregar este planejamento agora';
      });
    }
  }

  Future<void> _changeMonth(int delta) async {
    if (_saving) return;
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _load();
  }

  Future<void> _editGlobalLimit() async {
    if (_saving || _isPastMonth) return;
    final overview = _overview;
    final controller = TextEditingController(
      text: overview != null && overview.configured
          ? overview.limitAmount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'seu teto de gastos flexíveis',
                  style: AppTypography.section(context, fontSize: 20),
                ),
                const SizedBox(height: 7),
                Text(
                  'este é o máximo que você quer gastar no mês com o que é flexível. limites por categoria ajudam a distribuir, mas não mudam este teto.',
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    color: AppColors.secondaryText(Theme.of(context).brightness),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey('flex-budget-limit-input'),
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'teto deste mês',
                    prefixText: 'R\$ ',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const ValueKey('flex-budget-save-limit'),
                  onPressed: () {
                    final parsed = _parseMoney(controller.text);
                    if (parsed == null || parsed < 0) {
                      setSheetState(() => error = 'digite um valor válido');
                      return;
                    }
                    Navigator.of(sheetContext).pop(parsed);
                  },
                  child: const Text('salvar teto flexível'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (amount == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.setFlexibleBudgetLimit(
        spaceId: widget.spaceId,
        periodMonth: _month,
        limitAmount: amount,
      );
      if (!mounted) return;
      AppSnackbars.show(
        context,
        'teto flexível de ${Formatters.money(amount)} salvo para ${_monthLabel(_month)}',
      );
      await _load();
    } catch (error) {
      if (mounted) {
        AppSnackbars.show(
          context,
          'não consegui salvar agora. confira os dados e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCategoryLimit(BudgetOverviewItem item) async {
    if (_saving || _isPastMonth) return;
    final controller = TextEditingController(
      text: item.hasBudget
          ? item.plannedAmount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.hasBudget ? 'editar limite' : 'definir limite',
                  style: AppTypography.section(context, fontSize: 20),
                ),
                const SizedBox(height: 5),
                Text(
                  item.categoryName,
                  style: AppTypography.body(
                    context,
                    color: AppColors.secondaryText(Theme.of(context).brightness),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey('flex-category-limit-input'),
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'limite deste mês',
                    prefixText: 'R\$ ',
                    helperText: 'use R\$ 0 para remover o limite desta categoria',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    final parsed = _parseMoney(controller.text);
                    if (parsed == null || parsed < 0) {
                      setSheetState(() => error = 'digite um valor válido');
                      return;
                    }
                    Navigator.of(sheetContext).pop(parsed);
                  },
                  child: const Text('salvar limite'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (amount == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.setBudgetLimit(
        spaceId: widget.spaceId,
        periodMonth: _month,
        categoryId: item.categoryId,
        plannedAmount: amount,
        scope: BudgetLimitScope.month,
      );
      if (!mounted) return;
      AppSnackbars.show(
        context,
        amount == 0
            ? 'limite de ${item.categoryName.toLowerCase()} removido'
            : '${item.categoryName}: ${Formatters.money(amount)} neste mês',
      );
      await _load();
    } catch (error) {
      if (mounted) {
        AppSnackbars.show(
          context,
          'não consegui salvar: ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 100),
              children: [
                AppPageHeader(
                  title: 'orçamento flexível',
                  subtitle: 'controle do que pode variar sem apertar o mês',
                  leading: IconButton(
                    tooltip: 'voltar',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(AppIcons.back),
                  ),
                ),
                const SizedBox(height: 18),
                _monthPicker(brightness),
                const SizedBox(height: 18),
                if (_loading && _overview == null)
                  const AppLoadingState(label: 'organizando seu orçamento flexível')
                else if (_error != null && _overview == null)
                  AppErrorState(
                    title: 'não consegui carregar seu orçamento flexível',
                    description: _error,
                    onRetry: _load,
                  )
                else ...[
                  _globalCard(brightness),
                  const SizedBox(height: 22),
                  _categorySection(brightness),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _monthPicker(Brightness brightness) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _monthLabel(_month),
                style: AppTypography.display(
                  context,
                  fontSize: 25,
                  color: AppColors.primaryText(brightness),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _isPastMonth ? 'mês encerrado · somente consulta' : 'seu limite para gastos flexíveis',
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  color: AppColors.secondaryText(brightness),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'mês anterior',
          onPressed: _saving ? null : () => _changeMonth(-1),
          icon: const Icon(AppIcons.chevronLeft),
        ),
        IconButton(
          tooltip: 'próximo mês',
          onPressed: _saving ? null : () => _changeMonth(1),
          icon: const Icon(AppIcons.chevronRight),
        ),
      ],
    );
  }

  Widget _globalCard(Brightness brightness) {
    final overview = _overview!;
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final stateColor = _progressColor(overview.progressState, brightness);
    final ratio = overview.limitAmount > 0
        ? overview.usageRatio.clamp(0.0, 1.0)
        : 0.0;

    return Container(
      key: const ValueKey('flex-budget-global-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.feature),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'teto flexível do mês',
                  style: AppTypography.section(context, fontSize: 19),
                ),
              ),
              if (!_isPastMonth)
                TextButton(
                  key: const ValueKey('flex-budget-edit-global'),
                  onPressed: _saving ? null : _editGlobalLimit,
                  child: Text(overview.explicitLimit ? 'editar' : 'definir'),
                ),
            ],
          ),
          Text(
            overview.explicitLimit
                ? 'este teto é independente dos limites por categoria'
                : 'valor herdado dos limites por categoria · defina um teto próprio para separar as duas coisas',
            style: AppTypography.body(context, fontSize: 11, color: secondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniMetric(
                label: 'teto',
                value: overview.configured ? Formatters.money(overview.limitAmount) : '—',
                brightness: brightness,
              ),
              _MiniMetric(
                label: 'usado',
                value: Formatters.money(overview.usedAmount),
                brightness: brightness,
              ),
              _MiniMetric(
                label: overview.isExceeded ? 'ultrapassou' : 'ainda pode gastar',
                value: Formatters.money(
                  overview.isExceeded ? overview.exceededAmount : overview.remainingAmount,
                ),
                brightness: brightness,
              ),
            ],
          ),
          if (overview.configured) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: border.withValues(alpha: .65),
                valueColor: AlwaysStoppedAnimation<Color>(stateColor),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              overview.isExceeded
                  ? 'você ultrapassou seu orçamento flexível em ${Formatters.money(overview.exceededAmount)}'
                  : 'você ainda tem ${Formatters.money(overview.remainingAmount)} dentro do teto flexível',
              style: AppTypography.body(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: overview.isExceeded ? stateColor : AppColors.primaryText(brightness),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              'defina quanto você quer permitir para gastos flexíveis neste mês.',
              style: AppTypography.body(context, fontSize: 12, color: secondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categorySection(Brightness brightness) {
    final items = _flexibleItems;
    final secondary = AppColors.secondaryText(brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'limites por categoria',
          subtitle:
              'eles ajudam a distribuir seu dinheiro. um gasto flexível continua contando no teto global mesmo quando a categoria está sem limite',
        ),
        if (_activeWithoutLimit > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.warningText(brightness).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Text(
              '$_activeWithoutLimit ${_activeWithoutLimit == 1 ? 'categoria com gasto está' : 'categorias com gastos estão'} sem limite definido.',
              style: AppTypography.body(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText(brightness),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (items.isEmpty)
          Text(
            'nenhuma categoria flexível teve gasto ou limite neste mês.',
            style: AppTypography.body(context, fontSize: 12, color: secondary),
          )
        else
          ...items.map((item) => _categoryCard(item, brightness)),
      ],
    );
  }

  Widget _categoryCard(BudgetOverviewItem item, Brightness brightness) {
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final family = item.parentName ?? item.categoryName;
    final color = CategoryVisuals.colorFor(category: family, brightness: brightness);
    final icon = CategoryVisuals.iconFor(
      category: family,
      subcategory: item.categoryName,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        child: InkWell(
          key: ValueKey('flex-budget-category-${item.categoryId}'),
          onTap: _isPastMonth || _saving ? null : () => _editCategoryLimit(item),
          borderRadius: BorderRadius.circular(AppRadii.compactCard),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.compactCard),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                CategoryIconBadge(
                  icon: icon,
                  color: color,
                  size: 40,
                  iconSize: 20,
                  radius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.categoryName,
                        style: AppTypography.body(
                          context,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.hasBudget
                            ? '${Formatters.money(item.actualAmount)} de ${Formatters.money(item.plannedAmount)}'
                            : '${Formatters.money(item.actualAmount)} gasto · sem limite definido',
                        style: AppTypography.label(
                          context,
                          fontSize: 10,
                          color: item.hasBudget ? secondary : AppColors.warningText(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isPastMonth) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.hasBudget ? 'editar' : 'definir',
                    style: AppTypography.label(
                      context,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.brightness,
  });

  final String label;
  final String value;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background(brightness).withValues(alpha: .45),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border(brightness)),
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
          Text(
            value,
            style: AppTypography.money(
              context,
              fontSize: 14,
              color: AppColors.primaryText(brightness),
            ),
          ),
        ],
      ),
    );
  }
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
  const names = <String>[
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
  return '${names[month.month - 1]} ${month.year}';
}
