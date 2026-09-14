import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../shared/widgets/category_icon_badge.dart';
import 'quick_register_sheet.dart';
import 'upcoming_events_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.space, required this.repository});

  final FinancialSpace space;
  final FolegoRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FolegoSnapshot? _snapshot;

  List<TransactionItem> _transactions = const [];
  List<CategoryItem> _categories = const [];

  String _name = 'você';

  bool _loading = true;
  String? _error;

  Map<String, CategoryItem> get _categoryById {
    return {for (final category in _categories) category.id: category};
  }

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final values = await Future.wait([
        widget.repository.getProfileName(),
        widget.repository.getSnapshot(widget.space.id),
        widget.repository.getTransactions(widget.space.id),
        widget.repository.listExpenseCategories(widget.space.id),
        widget.repository.listIncomeCategories(widget.space.id),
      ]);

      if (!mounted) {
        return;
      }

      final expenseCategories = values[3] as List<CategoryItem>;

      final incomeCategories = values[4] as List<CategoryItem>;

      final categoriesById = <String, CategoryItem>{};

      for (final category in [...expenseCategories, ...incomeCategories]) {
        categoriesById[category.id] = category;
      }

      setState(() {
        _name = values[0] as String;

        _snapshot = values[1] as FolegoSnapshot;

        _transactions = values[2] as List<TransactionItem>;

        _categories = categoriesById.values.toList();

        _loading = false;
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

  Future<void> _openRegister(String type) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => QuickRegisterSheet(
        space: widget.space,
        repository: widget.repository,
        initialType: type,
      ),
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _openUpcomingEvents() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UpcomingEventsScreen(
          repository: widget.repository,
          spaceId: widget.space.id,
        ),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature entra na próxima etapa do Fôlego.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _snapshot == null) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    if (_error != null && _snapshot == null) {
      return _buildError();
    }

    final snapshot = _snapshot!;

    final brightness = Theme.of(context).brightness;

    final background = AppColors.background(brightness);

    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final primaryPurple = AppColors.primaryPurple(brightness);

    final categories = _topCategories(brightness);

    final latest = _latestTransaction();

    final layout = AppBreakpoints.of(context);
    final useTwoColumns =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    // Espaço da bottom nav flutuante +
    // safe area do aparelho.
    final bottomListPadding = MediaQuery.paddingOf(context).bottom + 180;

    final hero = _buildHero(
      snapshot: snapshot,
      primaryPurple: primaryPurple,
    );

    final quickActions = _buildQuickActions(
      surface: surface,
      border: border,
      primaryText: primaryText,
      brightness: brightness,
    );

    final upcoming = _buildUpcomingCard(
      surface: surface,
      border: border,
      primaryText: primaryText,
      secondaryText: secondaryText,
      primaryPurple: primaryPurple,
    );

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(0, 26, 0, bottomListPadding),
              children: [
                _buildHeader(
                  snapshot: snapshot,
                  surface: surface,
                  border: border,
                  primaryText: primaryText,
                ),

                const SizedBox(height: 26),

                if (useTwoColumns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: hero,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            quickActions,
                            const SizedBox(height: 24),
                            upcoming,
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  hero,
                  const SizedBox(height: 26),
                  quickActions,
                  const SizedBox(height: 24),
                  upcoming,
                ],

                const SizedBox(height: 32),

                _buildSectionHeader(
                  title: 'seus gastos',
                  subtitle: 'onde seu dinheiro passou neste período',
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _CategoryCard(
                        summary: categories[0],
                        surface: surface,
                        border: border,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CategoryCard(
                        summary: categories[1],
                        surface: surface,
                        border: border,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CategoryCard(
                        summary: categories[2],
                        surface: surface,
                        border: border,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                      ),
                    ),
                  ],
                ),

                if (latest != null) ...[
                  const SizedBox(height: 30),
                  _buildSectionHeader(
                    title: 'último movimento',
                    subtitle: 'o que aconteceu por último',
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 14),
                  _buildLatestCard(
                    latest: latest,
                    brightness: brightness,
                    surface: surface,
                    border: border,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.warning, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _load,
                child: const Text('tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required FolegoSnapshot snapshot,
    required Color surface,
    required Color border,
    required Color primaryText,
  }) {
    final daysChip = snapshot.daysUntilIncome == null
        ? null
        : Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.flame, size: 18, color: AppColors.lime),
                const SizedBox(width: 6),
                Text(
                  '${snapshot.daysUntilIncome} '
                  'dia${snapshot.daysUntilIncome == 1 ? '' : 's'}',
                  style: AppTypography.label(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
              ],
            ),
          );

    if (AppBreakpoints.of(context) == AppLayoutSize.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'e aí, ${_name.toLowerCase()}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.display(
              context,
              fontSize: 28,
              color: primaryText,
            ),
          ),
          if (daysChip != null) ...[const SizedBox(height: 12), daysChip],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            'e aí, ${_name.toLowerCase()}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.display(
              context,
              fontSize: 30,
              color: primaryText,
            ),
          ),
        ),
        if (daysChip != null) ...[const SizedBox(width: 12), daysChip],
      ],
    );
  }

  Widget _buildHero({
    required FolegoSnapshot snapshot,
    required Color primaryPurple,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: primaryPurple,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'te sobra pra gastar',
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: .78),
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.money(snapshot.spendablePool),
              style: AppTypography.money(
                context,
                fontSize: 52,
                color: AppColors.lime,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.calendar,
                  size: 17,
                  color: Colors.white.withValues(alpha: .85),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'depois dos compromissos '
                    'até o próximo recebimento',
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: .82),
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

  Widget _buildQuickActions({
    required Color surface,
    required Color border,
    required Color primaryText,
    required Brightness brightness,
  }) {
    final positive = AppColors.positiveText(brightness);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _QuickAction(
            label: 'gasto',
            icon: AppIcons.expense,
            background: AppColors.lime,
            foreground: AppColors.iconOnLime,
            onTap: () => _openRegister('expense'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            label: 'receita',
            icon: AppIcons.income,
            background: surface,
            foreground: positive,
            borderColor: border,
            onTap: () => _openRegister('income'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            label: 'metas',
            icon: AppIcons.goals,
            background: AppColors.primaryPurple(brightness),
            foreground: Colors.white,
            onTap: () => _comingSoon('Metas'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            label: 'diário',
            icon: AppIcons.journal,
            background: surface,
            foreground: primaryText,
            borderColor: border,
            onTap: () => _comingSoon('Diário'),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard({
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color secondaryText,
    required Color primaryPurple,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openUpcomingEvents,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              CategoryIconBadge(
                icon: AppIcons.calendar,
                color: primaryPurple,
                size: 46,
                iconSize: 22,
                radius: 15,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'próximos dias',
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'veja o que entra e sai '
                      'nos próximos 30 dias',
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, size: 20, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.section(
            context,
            fontSize: 20,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: AppTypography.body(
            context,
            fontSize: 12,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildLatestCard({
    required TransactionItem latest,
    required Brightness brightness,
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color secondaryText,
  }) {
    // Tipo + valor são considerados.
    // Assim, qualquer valor negativo também
    // recebe obrigatoriamente a semântica
    // de despesa/alerta.
    final isNegative = latest.isExpense || latest.amount < 0;

    final isPositive = latest.isIncome && latest.amount >= 0;

    final amountColor = isNegative
        ? AppColors.expenseText(brightness)
        : isPositive
        ? AppColors.positiveText(brightness)
        : AppColors.primaryPurple(brightness);

    final categoryPath = _categoryPathFor(latest);

    final isTransfer = latest.eventType == 'transfer';

    final categoryColor = latest.isIncome
        ? AppColors.positiveText(brightness)
        : isTransfer
        ? AppColors.primaryPurple(brightness)
        : CategoryVisuals.colorFor(
            category: categoryPath.category,
            brightness: brightness,
          );

    final categoryIcon = latest.isIncome
        ? AppIcons.income
        : isTransfer
        ? AppIcons.transfer
        : CategoryVisuals.iconFor(
            category: categoryPath.category,
            subcategory: categoryPath.subcategory,
          );

    final categoryLabel = latest.categoryName?.trim().isNotEmpty == true
        ? latest.categoryName!.trim()
        : _typeLabel(latest.eventType);

    final sign = isNegative
        ? '-'
        : isPositive
        ? '+'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          CategoryIconBadge(
            icon: categoryIcon,
            color: categoryColor,
            size: 46,
            iconSize: 22,
            radius: 15,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latest.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        categoryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(
                          context,
                          fontSize: 11,
                          color: secondaryText,
                        ),
                      ),
                    ),
                    Text(
                      ' · ${_relativeDate(latest.occurredAt)}',
                      style: AppTypography.label(
                        context,
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$sign${Formatters.money(latest.amount.abs())}',
              style: AppTypography.money(
                context,
                fontSize: 15,
                color: amountColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_CategorySummary> _topCategories(Brightness brightness) {
    final totals = <String, double>{};

    for (final transaction in _transactions) {
      if (!_isExpense(transaction.eventType)) {
        continue;
      }

      final path = _categoryPathFor(transaction);

      final canonicalParent = CategoryVisuals.canonicalCategory(path.category);

      totals[canonicalParent] =
          (totals[canonicalParent] ?? 0) + transaction.amount.abs();
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <_CategorySummary>[];

    for (var i = 0; i < sorted.length && i < 3; i++) {
      final entry = sorted[i];

      result.add(
        _CategorySummary(
          label: entry.key.toLowerCase(),
          amount: entry.value,
          icon: CategoryVisuals.iconFor(category: entry.key),
          color: CategoryVisuals.colorFor(
            category: entry.key,
            brightness: brightness,
          ),
        ),
      );
    }

    const fallbackNames = ['Alimentação', 'Moradia', 'Transporte'];

    for (final fallbackName in fallbackNames) {
      if (result.length >= 3) {
        break;
      }

      final alreadyExists = result.any(
        (item) => item.label.toLowerCase() == fallbackName.toLowerCase(),
      );

      if (alreadyExists) {
        continue;
      }

      result.add(
        _CategorySummary(
          label: fallbackName.toLowerCase(),
          amount: 0,
          icon: CategoryVisuals.iconFor(category: fallbackName),
          color: CategoryVisuals.colorFor(
            category: fallbackName,
            brightness: brightness,
          ),
        ),
      );
    }

    while (result.length < 3) {
      result.add(
        _CategorySummary(
          label: 'a classificar',
          amount: 0,
          icon: CategoryVisuals.iconFor(category: 'A classificar'),
          color: CategoryVisuals.colorFor(
            category: 'A classificar',
            brightness: brightness,
          ),
        ),
      );
    }

    return result.take(3).toList();
  }

  _CategoryPath _categoryPathFor(TransactionItem transaction) {
    final rawCategory = transaction.categoryName?.trim();

    if (rawCategory == null || rawCategory.isEmpty) {
      return const _CategoryPath(category: 'A classificar');
    }

    final parentId = transaction.categoryParentId;

    if (parentId != null) {
      final parent = _categoryById[parentId];

      if (parent != null) {
        return _CategoryPath(category: parent.name, subcategory: rawCategory);
      }
    }

    return _CategoryPath(category: rawCategory);
  }

  bool _isExpense(String type) {
    return type == 'expense' ||
        type == 'card_purchase' ||
        type == 'benefit_expense' ||
        type == 'debt_payment';
  }

  TransactionItem? _latestTransaction() {
    for (final transaction in _transactions) {
      if (transaction.eventType != 'opening_balance') {
        return transaction;
      }
    }

    if (_transactions.isNotEmpty) {
      return _transactions.first;
    }

    return null;
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final transactionDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(transactionDay).inDays;

    if (difference == 0) {
      return 'hoje';
    }

    if (difference == 1) {
      return 'ontem';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'income':
        return 'receita';

      case 'expense':
        return 'gasto';

      case 'card_purchase':
        return 'cartão';

      case 'transfer':
        return 'transferência';

      case 'opening_balance':
        return 'saldo inicial';

      default:
        return 'movimento';
    }
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: borderColor == null
                  ? BorderSide.none
                  : BorderSide(color: borderColor!),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Center(child: Icon(icon, color: foreground, size: 27)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: AppTypography.label(
              context,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.summary,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
  });

  final _CategorySummary summary;

  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CategoryIconBadge(
            icon: summary.icon,
            color: summary.color,
            size: 40,
            iconSize: 21,
            radius: 13,
          ),
          const SizedBox(height: 12),
          Text(
            summary.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.label(
              context,
              fontSize: 11,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Formatters.money(summary.amount),
              style: AppTypography.money(
                context,
                fontSize: 14,
                color: primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySummary {
  const _CategorySummary({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;
}

class _CategoryPath {
  const _CategoryPath({required this.category, this.subcategory});

  final String category;
  final String? subcategory;
}
