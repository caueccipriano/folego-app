import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
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
        widget.repository.getSnapshot(widget.space.id),
        widget.repository.getTransactions(widget.space.id),
      ]);

      if (!mounted) return;

      setState(() {
        _name = values[0] as String;
        _snapshot = values[1] as FolegoSnapshot;
        _transactions = values[2] as List<TransactionItem>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

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
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 44),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = _topCategories();
    final latest = _latestTransaction();

    final background = isDark
        ? const Color(0xFF0D0D0F)
        : const Color(0xFFF5F1E7);

    final surface = isDark ? const Color(0xFF1D1B22) : Colors.white;

    final border = isDark ? const Color(0xFF302E37) : const Color(0xFFE0DCD2);

    final primaryText = isDark
        ? const Color(0xFFF9F9FA)
        : const Color(0xFF111111);

    final secondaryText = isDark
        ? const Color(0xFF96939E)
        : const Color(0xFF77737A);

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'e aí, ${_name.toLowerCase()}',
                          style: AppTypography.display(
                            context,
                            fontSize: 31,
                            color: primaryText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => AppThemeController.toggle(context),
                        tooltip: isDark ? 'Tema claro' : 'Tema escuro',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(42, 42),
                          backgroundColor: surface,
                          foregroundColor: primaryText,
                          side: BorderSide(color: border),
                        ),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (snapshot.daysUntilIncome != null)
                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1D1B22)
                                : const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                size: 17,
                                color: AppPalette.lime,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${snapshot.daysUntilIncome} '
                                'dia${snapshot.daysUntilIncome == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1D1B22)
                          : const Color(0xFF6C3BF0),
                      borderRadius: BorderRadius.circular(28),
                      border: isDark
                          ? Border.all(color: const Color(0xFF312F38))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'te sobra pra gastar',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFAAA6B0)
                                : Colors.white.withValues(alpha: .76),
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
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
                              fontSize: 58,
                              color: isDark ? AppPalette.lime : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'depois dos compromissos até o próximo recebimento',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFAAA6B0)
                                : Colors.white.withValues(alpha: .76),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _QuickAction(
                          label: 'gasto',
                          icon: Icons.receipt_long_rounded,
                          background: AppPalette.lime,
                          foreground: const Color(0xFF111111),
                          onTap: () => _openRegister('expense'),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: _QuickAction(
                          label: 'receita',
                          icon: Icons.add_rounded,
                          background: isDark
                              ? const Color(0xFFF3F1EC)
                              : const Color(0xFF111111),
                          foreground: isDark
                              ? const Color(0xFF111111)
                              : AppPalette.lime,
                          onTap: () => _openRegister('income'),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: _QuickAction(
                          label: 'metas',
                          icon: Icons.track_changes_rounded,
                          background: AppPalette.purple,
                          foreground: Colors.white,
                          onTap: () => _comingSoon('Metas'),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: _QuickAction(
                          label: 'diário',
                          icon: Icons.menu_book_rounded,
                          background: surface,
                          foreground: primaryText,
                          borderColor: border,
                          onTap: () => _comingSoon('Diário'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openUpcomingEvents,
                      borderRadius: BorderRadius.circular(22),
                      child: Ink(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: .35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Próximos dias',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Veja o que entra e sai nos próximos 30 dias',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Text(
                    'seus gastos',
                    style: AppTypography.section(
                      context,
                      fontSize: 25,
                      color: primaryText,
                    ),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CategoryCard(
                          summary: categories[1],
                          surface: surface,
                          border: border,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                        ),
                      ),
                      const SizedBox(width: 12),
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

                  const SizedBox(height: 28),

                  if (latest != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${latest.description} · ${_relativeDate(latest.occurredAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: primaryText,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                Formatters.money(latest.amount.abs()),
                                style: TextStyle(
                                  color: isDark
                                      ? AppPalette.lime
                                      : AppPalette.green,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.pink.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              latest.categoryName ??
                                  _typeLabel(latest.eventType),
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFF19ABA)
                                    : const Color(0xFFB84071),
                                fontWeight: FontWeight.w600,
                              ),
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
      ),
    );
  }

  List<_CategorySummary> _topCategories() {
    final totals = <String, double>{};

    for (final transaction in _transactions) {
      if (!_isExpense(transaction.eventType)) {
        continue;
      }

      final category = transaction.categoryName?.trim();

      final name = category == null || category.isEmpty ? 'outros' : category;

      totals[name] = (totals[name] ?? 0) + transaction.amount.abs();
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
          icon: _categoryIcon(entry.key),
          color: _categoryColor(entry.key, i),
        ),
      );
    }

    const fallbacks = [
      _CategorySummary(
        label: 'comida',
        amount: 0,
        icon: Icons.restaurant_rounded,
        color: AppPalette.purpleLight,
      ),
      _CategorySummary(
        label: 'casa',
        amount: 0,
        icon: Icons.home_outlined,
        color: AppPalette.pink,
      ),
      _CategorySummary(
        label: 'transporte',
        amount: 0,
        icon: Icons.directions_bus_rounded,
        color: AppPalette.green,
      ),
    ];

    while (result.length < 3) {
      final fallback = fallbacks[result.length];

      if (!result.any((item) => item.label == fallback.label)) {
        result.add(fallback);
      } else {
        result.add(
          _CategorySummary(
            label: 'outros',
            amount: 0,
            icon: Icons.category_outlined,
            color: _categoryColor('outros', result.length),
          ),
        );
      }
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

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();

    if (value.contains('alimenta') ||
        value.contains('comida') ||
        value.contains('restaurante')) {
      return Icons.restaurant_rounded;
    }

    if (value.contains('moradia') ||
        value.contains('casa') ||
        value.contains('aluguel')) {
      return Icons.home_outlined;
    }

    if (value.contains('transport') ||
        value.contains('uber') ||
        value.contains('combust')) {
      return Icons.directions_bus_rounded;
    }

    if (value.contains('saúde') || value.contains('saude')) {
      return Icons.favorite_border_rounded;
    }

    return Icons.category_outlined;
  }

  Color _categoryColor(String category, int index) {
    final value = category.toLowerCase();

    if (value.contains('alimenta') ||
        value.contains('comida') ||
        value.contains('restaurante')) {
      return AppPalette.purpleLight;
    }

    if (value.contains('moradia') ||
        value.contains('casa') ||
        value.contains('aluguel')) {
      return AppPalette.pink;
    }

    if (value.contains('transport') ||
        value.contains('uber') ||
        value.contains('combust')) {
      return AppPalette.green;
    }

    const colors = [AppPalette.purpleLight, AppPalette.pink, AppPalette.green];

    return colors[index % colors.length];
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
                  : BorderSide(color: borderColor!, width: 1.4),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Center(child: Icon(icon, color: foreground, size: 31)),
            ),
          ),
        ),
        const SizedBox(height: 9),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
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
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(summary.icon, color: summary.color, size: 27),
          const SizedBox(height: 15),
          Text(
            summary.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryText, fontSize: 14),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Formatters.money(summary.amount),
              style: TextStyle(
                color: primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
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
