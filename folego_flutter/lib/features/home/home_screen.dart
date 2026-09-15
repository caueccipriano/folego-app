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
import '../../data/models/home_expense_summary.dart';
import '../../data/models/transaction_item.dart';
import '../../data/models/upcoming_events.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_home.dart';
import '../../shared/widgets/category_icon_badge.dart';
import '../diary/diary_screen.dart';
import '../goals/goals_screen.dart';
import 'home_expense_card.dart';
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

  List<TransactionItem> _expenseTransactions = const [];
  List<TransactionItem> _recentTransactions = const [];
  List<CategoryItem> _categories = const [];
  List<UpcomingEvent> _upcomingEvents = const [];

  String _name = 'você';

  bool _loading = true;
  String? _error;
  bool _expensesUnavailable = false;
  bool _recentUnavailable = false;
  bool _upcomingUnavailable = false;

  Map<String, CategoryItem> get _categoryById {
    return {for (final category in _categories) category.id: category};
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T?> _optional<T>(Future<T> future, String label) async {
    try {
      return await future;
    } catch (error) {
      debugPrint('Home optional section failed ($label): $error');
      return null;
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final values = await Future.wait<dynamic>([
        widget.repository.getSnapshot(widget.space.id),
        _optional(widget.repository.getProfileName(), 'profile'),
        _optional(
          widget.repository.getHomeExpenseTransactions(widget.space.id),
          'expenses',
        ),
        _optional(
          widget.repository
              .getTransactionsPage(widget.space.id, pageSize: 12)
              .then((page) => page.items),
          'recent transactions',
        ),
        _optional(
          widget.repository.listExpenseCategories(widget.space.id),
          'expense categories',
        ),
        _optional(
          widget.repository.listIncomeCategories(widget.space.id),
          'income categories',
        ),
        _optional(
          widget.repository.getUpcomingEvents(widget.space.id, days: 30),
          'upcoming events',
        ),
      ]);

      if (!mounted) {
        return;
      }

      final expenseCategories =
          values[4] as List<CategoryItem>? ?? const <CategoryItem>[];
      final incomeCategories =
          values[5] as List<CategoryItem>? ?? const <CategoryItem>[];
      final categoriesById = <String, CategoryItem>{};

      for (final category in [...expenseCategories, ...incomeCategories]) {
        categoriesById[category.id] = category;
      }

      setState(() {
        _snapshot = values[0] as FolegoSnapshot;
        _name = (values[1] as String?)?.trim().isNotEmpty == true
            ? (values[1] as String).trim()
            : 'você';

        final expenseTransactions = values[2] as List<TransactionItem>?;
        final recentTransactions = values[3] as List<TransactionItem>?;
        final upcomingEvents = values[6] as List<UpcomingEvent>?;

        _expenseTransactions = expenseTransactions ?? const [];
        _recentTransactions = recentTransactions ?? const [];
        _upcomingEvents = upcomingEvents ?? const [];
        _categories = categoriesById.values.toList(growable: false);

        _expensesUnavailable = expenseTransactions == null;
        _recentUnavailable = recentTransactions == null;
        _upcomingUnavailable = upcomingEvents == null;
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

  Future<void> _openGoals() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalsScreen(
          repository: widget.repository,
          spaceId: widget.space.id,
        ),
      ),
    );
  }

  Future<void> _openDiary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiaryScreen(
          repository: widget.repository,
          spaceId: widget.space.id,
        ),
      ),
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
    final layout = AppBreakpoints.of(context);

    final breakdown = buildHomeExpenseBreakdown(
      _expenseTransactions,
      categoryFor: (transaction) {
        final path = _categoryPathFor(transaction);
        return CategoryVisuals.canonicalCategory(path.category);
      },
    );
    final latest = _latestTransaction();

    final bottomListPadding = MediaQuery.paddingOf(context).bottom + 180;

    final header = _buildHeader(
      snapshot: snapshot,
      surface: surface,
      border: border,
      primaryText: primaryText,
    );
    final hero = _buildHero(
      snapshot: snapshot,
      brightness: brightness,
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
    final expenses = _buildExpensesSection(
      breakdown: breakdown,
      primaryText: primaryText,
      secondaryText: secondaryText,
    );
    final latestSection = _buildLatestSection(
      latest: latest,
      brightness: brightness,
      surface: surface,
      border: border,
      primaryText: primaryText,
      secondaryText: secondaryText,
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
                header,
                const SizedBox(height: 26),
                if (layout == AppLayoutSize.compact) ...[
                  hero,
                  const SizedBox(height: 24),
                  quickActions,
                  const SizedBox(height: 24),
                  upcoming,
                  const SizedBox(height: 30),
                  expenses,
                  const SizedBox(height: 30),
                  latestSection,
                ] else if (layout == AppLayoutSize.medium) ...[
                  hero,
                  const SizedBox(height: 26),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: quickActions),
                      const SizedBox(width: 24),
                      Expanded(flex: 4, child: upcoming),
                    ],
                  ),
                  const SizedBox(height: 30),
                  expenses,
                  const SizedBox(height: 30),
                  latestSection,
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: hero),
                      const SizedBox(width: 28),
                      Expanded(flex: 5, child: quickActions),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: expenses),
                      const SizedBox(width: 28),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            upcoming,
                            const SizedBox(height: 28),
                            latestSection,
                          ],
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
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
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
                Flexible(
                  child: Text(
                    '${snapshot.daysUntilIncome} '
                    'dia${snapshot.daysUntilIncome == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
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
    required Brightness brightness,
    required Color primaryPurple,
  }) {
    final onPurple = brightness == Brightness.dark
        ? AppColors.iconOnPurpleDark
        : AppColors.iconOnPurpleLight;

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
              color: onPurple.withValues(alpha: .80),
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
              color: AppColors.darkBackground.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.calendar,
                  size: 17,
                  color: onPurple.withValues(alpha: .88),
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
                      color: onPurple.withValues(alpha: .84),
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
    final onPurple = brightness == Brightness.dark
        ? AppColors.iconOnPurpleDark
        : AppColors.iconOnPurpleLight;

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
            foreground: onPurple,
            onTap: _openGoals,
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
            onTap: _openDiary,
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
    final sorted = [..._upcomingEvents]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final next = sorted.isEmpty ? null : sorted.first;

    final detail = _upcomingUnavailable
        ? 'veja o que entra e sai nos próximos 30 dias'
        : next == null
        ? 'nada previsto nos próximos 30 dias'
        : '${next.name} · ${next.isIncome ? '+' : '-'}${Formatters.money(next.amount.abs())} · ${_futureDate(next.dueDate)}';

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
                      'veja o que entra e sai nos próximos 30 dias',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        context,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
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

  Widget _buildExpensesSection({
    required HomeExpenseBreakdown breakdown,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'seus gastos',
          subtitle: 'como seus gastos se distribuem neste mês',
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        const SizedBox(height: 16),
        HomeExpenseCard(
          breakdown: breakdown,
          unavailable: _expensesUnavailable,
        ),
      ],
    );
  }

  Widget _buildLatestSection({
    required TransactionItem? latest,
    required Brightness brightness,
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'último movimento',
          subtitle: 'o que aconteceu por último',
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        const SizedBox(height: 14),
        if (_recentUnavailable)
          _buildCompactEmptyCard(
            message: 'não foi possível carregar o último movimento',
            surface: surface,
            border: border,
            primaryText: primaryText,
            secondaryText: secondaryText,
          )
        else if (latest == null)
          _buildCompactEmptyCard(
            message: 'nenhum movimento recente',
            surface: surface,
            border: border,
            primaryText: primaryText,
            secondaryText: secondaryText,
          )
        else
          _buildLatestCard(
            latest: latest,
            brightness: brightness,
            surface: surface,
            border: border,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
      ],
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

  Widget _buildCompactEmptyCard({
    required String message,
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color secondaryText,
  }) {
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
          Icon(AppIcons.transactions, size: 21, color: secondaryText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
          ),
        ],
      ),
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
    final isNegative = latest.isExpense ||
        latest.eventType == 'card_payment' ||
        latest.amount < 0;
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
    final cleanedDescription = homeDisplayDescription(latest.description);
    final description = cleanedDescription.isEmpty
        ? _typeLabel(latest.eventType)
        : cleanedDescription;
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
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$categoryLabel · ${_relativeDate(latest.occurredAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(
                    context,
                    fontSize: 11,
                    color: secondaryText,
                  ),
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

  TransactionItem? _latestTransaction() {
    for (final transaction in _recentTransactions) {
      if (transaction.eventType != 'opening_balance') {
        return transaction;
      }
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

  String _futureDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final difference = eventDay.difference(today).inDays;

    if (difference == 0) {
      return 'hoje';
    }
    if (difference == 1) {
      return 'amanhã';
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
      case 'card_payment':
        return 'pagamento de fatura';
      case 'benefit_expense':
        return 'benefício';
      case 'debt_payment':
        return 'dívida';
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

class _CategoryPath {
  const _CategoryPath({required this.category, this.subcategory});

  final String category;
  final String? subcategory;
}
