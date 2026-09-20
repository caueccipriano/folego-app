import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/layout/app_scroll_gutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/models/home_expense_summary.dart';
import '../../data/models/monthly_money_summary.dart';
import '../../data/models/projection_model.dart';
import '../../data/models/transaction_item.dart';
import '../../data/models/upcoming_events.dart';
import '../../data/repositories/folego_repository.dart';
import '../../shared/widgets/category_icon_badge.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_section_header.dart';
import '../diary/diary_screen.dart';
import '../goals/goals_screen.dart';
import 'home_monthly_money_card.dart';
import 'home_projection_insight_card.dart';
import 'home_financial_hero.dart';
import 'quick_register_sheet.dart';
import 'upcoming_events_screen.dart';
import '../plan/projection_navigation_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.space, required this.repository});

  final FinancialSpace space;
  final FolegoRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FolegoSnapshot? _snapshot;

  MonthlyMoneySummary? _monthlyMoney;
  ProjectionResult? _projection;
  List<TransactionItem> _recentTransactions = const [];
  List<CategoryItem> _categories = const [];
  List<UpcomingEvent> _upcomingEvents = const [];

  String _name = 'você';

  bool _loading = true;
  String? _error;
  bool _monthlyMoneyUnavailable = false;
  bool _projectionUnavailable = false;
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


  Future<T?> _optionalCall<T>(
    Future<T> Function() call,
    String label,
  ) async {
    try {
      return await call();
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
        _optional(widget.repository.getSnapshot(widget.space.id), 'snapshot'),
        _optional(widget.repository.getProfileName(), 'profile'),
        _optional(
          widget.repository.getMonthlyMoneySummary(spaceId: widget.space.id),
          'monthly money',
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
        _optionalCall(
          () => widget.repository.getProjection(
            spaceId: widget.space.id,
            horizonMonths: 3,
          ),
          'projection',
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

      final snapshot = values[0] as FolegoSnapshot?;

      setState(() {
        _snapshot = snapshot;
        _error = snapshot == null
            ? 'não consegui carregar seu resumo financeiro'
            : null;
        _name = (values[1] as String?)?.trim().isNotEmpty == true
            ? (values[1] as String).trim()
            : 'você';

        final monthlyMoney = values[2] as MonthlyMoneySummary?;
        final recentTransactions = values[3] as List<TransactionItem>?;
        final upcomingEvents = values[6] as List<UpcomingEvent>?;
        final projection = values[7] as ProjectionResult?;

        _monthlyMoney = monthlyMoney;
        _projection = projection;
        _recentTransactions = recentTransactions ?? const [];
        _upcomingEvents = upcomingEvents ?? const [];
        _categories = categoriesById.values.toList(growable: false);

        _monthlyMoneyUnavailable = monthlyMoney == null;
        _projectionUnavailable = projection == null;
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
      return ColoredBox(
        color: AppColors.background(Theme.of(context).brightness),
        child: const SafeArea(
          child: AppLoadingState(label: 'organizando seu resumo'),
        ),
      );
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

    final latest = _latestTransaction();

    final bottomListPadding = MediaQuery.paddingOf(context).bottom + 120;

    final header = _buildHeader(primaryText: primaryText);
    final hero = _buildHero(snapshot: snapshot);
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
    final monthlyMoney = HomeMonthlyMoneyCard(
      summary: _monthlyMoney,
      unavailable: _monthlyMoneyUnavailable,
    );
    final projectionInsight = HomeProjectionInsightCard(
      projection: _projection,
      unavailable: _projectionUnavailable,
      onOpen: () => ProjectionNavigationScope.maybeOf(context)?.open(),
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
              padding: AppScrollGutter.padding(
                context,
                top: 16,
                bottom: bottomListPadding,
              ),
              children: [
                header,
                const SizedBox(height: 14),
                if (layout == AppLayoutSize.compact) ...[
                  hero,
                  const SizedBox(height: 14),
                  quickActions,
                  const SizedBox(height: 16),
                  upcoming,
                  const SizedBox(height: 12),
                  monthlyMoney,
                  const SizedBox(height: 12),
                  projectionInsight,
                  const SizedBox(height: 20),
                  latestSection,
                ] else if (layout == AppLayoutSize.medium) ...[
                  hero,
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: quickActions),
                      const SizedBox(width: 20),
                      Expanded(flex: 4, child: upcoming),
                    ],
                  ),
                  const SizedBox(height: 22),
                  monthlyMoney,
                  const SizedBox(height: 14),
                  projectionInsight,
                  const SizedBox(height: 24),
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
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            monthlyMoney,
                            const SizedBox(height: 16),
                            projectionInsight,
                          ],
                        ),
                      ),
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
          child: AppErrorState(
            title: 'não consegui carregar seu resumo financeiro',
            description: _error,
            onRetry: _load,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required Color primaryText}) {
    return Text(
      'e aí, ${_name.toLowerCase()}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.display(
        context,
        fontSize: AppBreakpoints.of(context) == AppLayoutSize.compact ? 28 : 30,
        color: primaryText,
      ),
    );
  }

  Widget _buildHero({required FolegoSnapshot snapshot}) {
    return HomeFinancialHero(snapshot: snapshot);
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
            semanticLabel: 'registrar gasto',
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
            semanticLabel: 'registrar receita',
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
            semanticLabel: 'abrir metas',
            icon: AppIcons.goals,
            background: surface,
            foreground: AppColors.primaryPurple(brightness),
            borderColor: border,
            onTap: _openGoals,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            label: 'diário',
            semanticLabel: 'abrir diário',
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
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              CategoryIconBadge(
                icon: AppIcons.calendar,
                color: primaryPurple,
                size: 42,
                iconSize: 20,
                radius: AppRadii.control,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'próximo movimento',
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
  }) {
    return AppSectionHeader(
      title: title,
      subtitle: subtitle,
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
        borderRadius: BorderRadius.circular(AppRadii.card),
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
        borderRadius: BorderRadius.circular(AppRadii.card),
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
    this.semanticLabel,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.borderColor,
  });

  final String label;
  final String? semanticLabel;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.compactCard),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return foreground.withValues(alpha: .10);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return foreground.withValues(alpha: .06);
            }
            return null;
          }),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.compactCard),
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: 21),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppTypography.label(
                      context,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
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

class _CategoryPath {
  const _CategoryPath({required this.category, this.subcategory});

  final String category;
  final String? subcategory;
}
