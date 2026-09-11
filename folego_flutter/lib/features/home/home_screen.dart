import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import 'quick_register_sheet.dart';
import 'upcoming_events_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.space,
    required this.repository,
  });

  final FinancialSpace space;
  final FolegoRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FolegoSnapshot? _snapshot;
  List<TransactionItem> _transactions = [];

  String _name = 'você';
  bool _loading = true;
  String? _error;

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
        widget.repository.getSnapshot(
          widget.space.id,
        ),
        widget.repository.getTransactions(
          widget.space.id,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _name = values[0] as String;
        _snapshot = values[1] as FolegoSnapshot;
        _transactions = values[2] as List<TransactionItem>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  Future<void> _openRegister(
    String type,
  ) async {
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
      SnackBar(
        content: Text(
          '$feature entra na próxima etapa do Fôlego.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _snapshot == null) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null && _snapshot == null) {
      return _buildError();
    }

    final snapshot = _snapshot!;

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final primaryPurple = AppColors.primaryPurple(brightness);

    final categories = _topCategories(brightness);
    final latest = _latestTransaction();

    return ColoredBox(
      color: background,
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
                  20,
                  26,
                  20,
                  120,
                ),
                children: [
                  _buildHeader(
                    snapshot: snapshot,
                    isDark: isDark,
                    surface: surface,
                    border: border,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 26),
                  _buildHero(
                    snapshot: snapshot,
                    primaryPurple: primaryPurple,
                  ),
                  const SizedBox(height: 26),
                  _buildQuickActions(
                    surface: surface,
                    border: border,
                    primaryText: primaryText,
                    brightness: brightness,
                  ),
                  const SizedBox(height: 24),
                  _buildUpcomingCard(
                    surface: surface,
                    border: border,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    primaryPurple: primaryPurple,
                  ),
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
              const Icon(
                AppIcons.warning,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _load,
                child: const Text(
                  'Tentar novamente',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required FolegoSnapshot snapshot,
    required bool isDark,
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color secondaryText,
  }) {
    final themeButton = IconButton(
      onPressed: () => AppThemeController.toggle(
        context,
      ),
      tooltip: isDark ? 'Tema claro' : 'Tema escuro',
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 42),
        backgroundColor: surface,
        foregroundColor: secondaryText,
        side: BorderSide(
          color: border,
        ),
      ),
      icon: Icon(
        isDark ? AppIcons.lightTheme : AppIcons.darkTheme,
        size: 19,
      ),
    );

    final daysChip = snapshot.daysUntilIncome == null
        ? null
        : Container(
            height: 42,
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
            ),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  AppIcons.flame,
                  size: 18,
                  color: AppColors.lime,
                ),
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

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final compact = constraints.maxWidth < 390;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'e aí, ${_name.toLowerCase()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        context,
                        fontSize: 28,
                        color: primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  themeButton,
                ],
              ),
              if (daysChip != null) ...[
                const SizedBox(height: 12),
                daysChip,
              ],
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
            const SizedBox(width: 12),
            themeButton,
            if (daysChip != null) ...[
              const SizedBox(width: 8),
              daysChip,
            ],
          ],
        );
      },
    );
  }

  Widget _buildHero({
    required FolegoSnapshot snapshot,
    required Color primaryPurple,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        24,
        22,
        24,
      ),
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
              color: Colors.white.withValues(
                alpha: .78,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.money(
                snapshot.spendablePool,
              ),
              style: AppTypography.money(
                context,
                fontSize: 52,
                color: AppColors.lime,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: .12,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.calendar,
                  size: 17,
                  color: Colors.white.withValues(
                    alpha: .85,
                  ),
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
                      color: Colors.white.withValues(
                        alpha: .82,
                      ),
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
    final positive = AppColors.positiveText(
      brightness,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _QuickAction(
            label: 'gasto',
            icon: AppIcons.expense,
            background: AppColors.lime,
            foreground: AppColors.iconOnLime,
            onTap: () => _openRegister(
              'expense',
            ),
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
            onTap: () => _openRegister(
              'income',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            label: 'metas',
            icon: AppIcons.goals,
            background: AppColors.primaryPurple(
              brightness,
            ),
            foreground: Colors.white,
            onTap: () => _comingSoon(
              'Metas',
            ),
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
            onTap: () => _comingSoon(
              'Diário',
            ),
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
            border: Border.all(
              color: border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryPurple.withValues(
                    alpha: .12,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  AppIcons.calendar,
                  color: primaryPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Próximos dias',
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Veja o que entra e sai '
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
              Icon(
                AppIcons.chevronRight,
                size: 20,
                color: secondaryText,
              ),
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
    final amountColor = latest.isIncome
        ? AppColors.positiveText(
            brightness,
          )
        : latest.isExpense
            ? AppColors.expenseText(
                brightness,
              )
            : AppColors.primaryPurple(
                brightness,
              );

    final rawCategory = latest.categoryName?.trim();

    final visualCategory = rawCategory == null || rawCategory.isEmpty
        ? _typeLabel(latest.eventType)
        : rawCategory;

    final categoryColor = latest.isIncome
        ? AppColors.positiveText(
            brightness,
          )
        : CategoryVisuals.colorFor(
            category: visualCategory,
            brightness: brightness,
          );

    final categoryIcon = latest.isIncome
        ? AppIcons.income
        : latest.eventType == 'transfer'
            ? AppIcons.transfer
            : CategoryVisuals.iconFor(
                category: visualCategory,
              );

    final sign = latest.isIncome
        ? '+'
        : latest.isExpense
            ? '-'
            : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: categoryColor.withValues(
                alpha: .12,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              categoryIcon,
              color: categoryColor,
              size: 22,
            ),
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
                        rawCategory == null || rawCategory.isEmpty
                            ? _typeLabel(
                                latest.eventType,
                              )
                            : rawCategory,
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

  List<_CategorySummary> _topCategories(
    Brightness brightness,
  ) {
    final totals = <String, double>{};

    for (final transaction in _transactions) {
      if (!_isExpense(
        transaction.eventType,
      )) {
        continue;
      }

      final rawCategory = transaction.categoryName?.trim();

      final originalName = rawCategory == null || rawCategory.isEmpty
          ? 'A classificar'
          : rawCategory;

      final canonicalName = CategoryVisuals.canonicalCategory(
        originalName,
      );

      totals[canonicalName] = (totals[canonicalName] ?? 0) +
          transaction.amount.abs();
    }

    final sorted = totals.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(
          a.value,
        ),
      );

    final result = <_CategorySummary>[];

    for (var i = 0; i < sorted.length && i < 3; i++) {
      final entry = sorted[i];

      result.add(
        _CategorySummary(
          label: entry.key.toLowerCase(),
          amount: entry.value,
          icon: CategoryVisuals.iconFor(
            category: entry.key,
          ),
          color: CategoryVisuals.colorFor(
            category: entry.key,
            brightness: brightness,
          ),
        ),
      );
    }

    const fallbackNames = [
      'Alimentação',
      'Moradia',
      'Transporte',
    ];

    for (final fallbackName in fallbackNames) {
      if (result.length >= 3) {
        break;
      }

      final alreadyExists = result.any(
        (item) =>
            item.label.toLowerCase() ==
            fallbackName.toLowerCase(),
      );

      if (alreadyExists) {
        continue;
      }

      result.add(
        _CategorySummary(
          label: fallbackName.toLowerCase(),
          amount: 0,
          icon: CategoryVisuals.iconFor(
            category: fallbackName,
          ),
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
          icon: CategoryVisuals.iconFor(
            category: 'A classificar',
          ),
          color: CategoryVisuals.colorFor(
            category: 'A classificar',
            brightness: brightness,
          ),
        ),
      );
    }

    return result.take(3).toList();
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

  String _relativeDate(
    DateTime date,
  ) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final transactionDay = DateTime(
      date.year,
      date.month,
      date.day,
    );

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
                  : BorderSide(
                      color: borderColor!,
                    ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Icon(
                  icon,
                  color: foreground,
                  size: 27,
                ),
              ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: summary.color.withValues(
                alpha: .12,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              summary.icon,
              color: summary.color,
              size: 21,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summary.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
              Formatters.money(
                summary.amount,
              ),
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