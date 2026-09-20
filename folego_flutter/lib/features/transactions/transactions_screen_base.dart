import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/financial_display_text.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/recurring_item.dart';
import '../../data/models/transaction_filters.dart';
import '../../data/models/transaction_item.dart';
import '../../data/models/transaction_page.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_subscriptions.dart';
import '../../data/repositories/folego_repository_transaction_actions.dart';
import '../../data/repositories/folego_repository_transaction_filters.dart';
import '../../shared/widgets/category_icon_badge.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import 'recurring_form_sheet.dart';
import 'recurring_occurrence.dart';
import 'subscriptions_tab.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_edit_sheet.dart';
import 'transaction_filter_sheet.dart';

part 'transactions_recurring_widgets_v3.dart';

const Duration transactionSearchDebounce = Duration(milliseconds: 350);

typedef TransactionPageLoader = Future<TransactionPage> Function({
  required String spaceId,
  required TransactionFilters filters,
  required TransactionCursor? cursor,
  required int pageSize,
});

typedef TransactionFilterOptionsLoader = Future<TransactionFilterOptions>
    Function(String spaceId);

class TransactionsScreenV3 extends StatefulWidget {
  const TransactionsScreenV3({
    super.key,
    required this.repository,
    this.space,
    this.pageLoader,
    this.optionsLoader,
    this.initialFilters,
  });

  final FolegoRepository repository;
  final FinancialSpace? space;
  final TransactionPageLoader? pageLoader;
  final TransactionFilterOptionsLoader? optionsLoader;
  final TransactionFilters? initialFilters;

  @override
  State<TransactionsScreenV3> createState() => _TransactionsScreenV3State();
}

class _TransactionsScreenV3State extends State<TransactionsScreenV3>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;

  RealtimeRefreshBinding? _realtimeBinding;
  RealtimeRefreshBinding? _categoryRealtimeBinding;
  Timer? _searchTimer;

  FinancialSpace? _space;
  TransactionFilters _filters = TransactionFilters.empty();
  TransactionFilterOptions _filterOptions = TransactionFilterOptions.empty();
  List<TransactionItem> _transactions = const [];
  List<RecurringItem> _recurringItems = const [];
  Set<String> _subscriptionIds = const <String>{};
  Map<String, String> _recurringCardNames = const <String, String>{};
  List<CategoryItem> _categories = const [];

  TransactionCursor? _nextTransactionCursor;
  bool _loading = true;
  bool _loadingTransactions = false;
  bool _loadingMore = false;
  bool _hasMoreTransactions = true;
  String? _error;
  String? _loadMoreError;
  int _transactionLoadGeneration = 0;

  Map<String, CategoryItem> get _categoryById => {
    for (final category in _categories) category.id: category,
  };

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters ?? TransactionFilters.empty();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController(text: _filters.search);
    _bindRealtime();
    _loadInitial();
  }

  void _bindRealtime() {
    final coordinator = AppRealtimeRegistry.coordinator;
    if (coordinator == null) return;
    _realtimeBinding = coordinator.bind(
      domain: AppRealtimeDomain.transactions,
      onRefresh: _handleRealtimeRefresh,
    );
    _categoryRealtimeBinding = coordinator.bind(
      domain: AppRealtimeDomain.categories,
      onRefresh: _refreshFilterOptions,
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _realtimeBinding?.dispose();
    _categoryRealtimeBinding?.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final generation = ++_transactionLoadGeneration;
    try {
      final space = widget.space ?? await widget.repository.getPrimarySpace();
      final results = await Future.wait<dynamic>([
        _fetchPage(space.id, cursor: null, filters: _filters),
        widget.repository.listRecurringItems(space.id),
        _loadFilterOptions(space.id),
        widget.repository.listSubscriptionRecurringIds(space.id),
        widget.repository.listRecurringCardNames(space.id),
      ]);
      if (!mounted || generation != _transactionLoadGeneration) return;

      final page = results[0] as TransactionPage;
      final options = results[2] as TransactionFilterOptions;
      setState(() {
        _space = space;
        _transactions = page.items;
        _recurringItems = results[1] as List<RecurringItem>;
        _filterOptions = options;
        _subscriptionIds = results[3] as Set<String>;
        _recurringCardNames = results[4] as Map<String, String>;
        _categories = options.categories;
        _nextTransactionCursor = page.nextCursor;
        _hasMoreTransactions = page.hasMore && page.nextCursor != null;
        _loading = false;
        _loadingTransactions = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _transactionLoadGeneration) return;
      setState(() {
        _loading = false;
        _loadingTransactions = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<TransactionFilterOptions> _loadFilterOptions(String spaceId) {
    final loader = widget.optionsLoader;
    if (loader != null) return loader(spaceId);
    return widget.repository.getTransactionFilterOptions(spaceId);
  }

  Future<void> _refreshFilterOptions() async {
    final space = _space;
    if (space == null) return;
    try {
      final options = await _loadFilterOptions(space.id);
      if (!mounted || _space?.id != space.id) return;
      setState(() {
        _filterOptions = options;
        _categories = options.categories;
      });
    } catch (_) {
      // A taxonomia pode ser atualizada sem interromper a lista paginada.
    }
  }

  Future<TransactionPage> _fetchPage(
    String spaceId, {
    required TransactionCursor? cursor,
    required TransactionFilters filters,
  }) {
    final loader = widget.pageLoader;
    if (loader != null) {
      return loader(
        spaceId: spaceId,
        filters: filters,
        cursor: cursor,
        pageSize: transactionPageSize,
      );
    }
    return widget.repository.getTransactionsFilteredPage(
      spaceId,
      filters: filters,
      cursor: cursor,
      pageSize: transactionPageSize,
    );
  }

  Future<void> _refreshTransactions({required bool clearVisible}) async {
    final space = _space;
    if (space == null) return;
    final generation = ++_transactionLoadGeneration;
    final filters = _filters;

    if (mounted) {
      setState(() {
        _loadingTransactions = true;
        _loadingMore = false;
        _loadMoreError = null;
        _nextTransactionCursor = null;
        _hasMoreTransactions = false;
        if (clearVisible) _transactions = const [];
      });
    }

    try {
      final page = await _fetchPage(space.id, cursor: null, filters: filters);
      if (!mounted || generation != _transactionLoadGeneration) return;
      setState(() {
        _transactions = page.items;
        _nextTransactionCursor = page.nextCursor;
        _hasMoreTransactions = page.hasMore && page.nextCursor != null;
        _loadingTransactions = false;
      });
    } catch (error) {
      if (!mounted || generation != _transactionLoadGeneration) return;
      setState(() => _loadingTransactions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  Future<void> _refreshRecurring() async {
    final space = _space;
    if (space == null) return;
    try {
      final values = await Future.wait<dynamic>([
        widget.repository.listRecurringItems(space.id),
        widget.repository.listSubscriptionRecurringIds(space.id),
        widget.repository.listRecurringCardNames(space.id),
      ]);
      if (!mounted || _space?.id != space.id) return;
      setState(() {
        _recurringItems = values[0] as List<RecurringItem>;
        _subscriptionIds = values[1] as Set<String>;
        _recurringCardNames = values[2] as Map<String, String>;
      });
    } catch (_) {
      // A lista de transações continua utilizável se recorrências falharem.
    }
  }

  Future<void> _handleRealtimeRefresh() async {
    if (!mounted || _space == null) return;
    await Future.wait<void>([
      _refreshTransactions(clearVisible: false),
      _refreshRecurring(),
    ]);
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _refreshTransactions(clearVisible: false),
      _refreshRecurring(),
    ]);
  }

  Future<void> _retryInitialLoad() => _loadInitial();

  Future<void> _loadMoreTransactions() async {
    final space = _space;
    final cursor = _nextTransactionCursor;
    if (space == null ||
        cursor == null ||
        _loadingMore ||
        !_hasMoreTransactions ||
        _loadingTransactions) {
      return;
    }

    final generation = _transactionLoadGeneration;
    final filters = _filters;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await _fetchPage(space.id, cursor: cursor, filters: filters);
      if (!mounted || generation != _transactionLoadGeneration) return;
      setState(() {
        _transactions = mergeTransactionPages(
          existing: _transactions,
          incoming: page.items,
        );
        _nextTransactionCursor = page.nextCursor;
        _hasMoreTransactions = page.hasMore && page.nextCursor != null;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _transactionLoadGeneration) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = _friendlyError(error);
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(transactionSearchDebounce, () {
      if (!mounted) return;
      _applyFilters(_filters.copyWith(search: value), syncSearchField: false);
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    _applyFilters(_filters.copyWith(search: ''), syncSearchField: false);
  }

  Future<void> _openFilters() async {
    final result = await showTransactionFilters(
      context: context,
      initial: _filters,
      options: _filterOptions,
    );
    if (result == null || !mounted) return;
    _applyFilters(result, syncSearchField: true);
  }

  void _applyFilters(
    TransactionFilters next, {
    required bool syncSearchField,
  }) {
    _searchTimer?.cancel();
    if (syncSearchField && _searchController.text != next.search) {
      _searchController.text = next.search;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    }
    if (_filters == next) return;
    setState(() => _filters = next);
    unawaited(_refreshTransactions(clearVisible: true));
  }

  void _removePeriodFilter() {
    _applyFilters(
      _filters.copyWith(startDate: null, endDate: null),
      syncSearchField: false,
    );
  }

  void _removeTypeFilter() {
    _applyFilters(
      _filters.copyWith(eventTypes: const <String>{}),
      syncSearchField: false,
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    _applyFilters(TransactionFilters.empty(), syncSearchField: false);
  }

  Future<void> _openTransactionDetail(TransactionItem item) async {
    final space = _space;
    if (space == null) return;
    final changed = await showTransactionDetail(
      context: context,
      space: space,
      repository: widget.repository,
      eventId: item.id,
    );
    if (changed == true && mounted) {
      await _refreshTransactions(clearVisible: false);
    }
  }

  Future<void> _editTransaction(TransactionItem item) async {
    final space = _space;
    if (space == null || !item.canEditAsSimple) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => TransactionEditSheet(
        space: space,
        repository: widget.repository,
        transaction: item,
      ),
    );
    if (saved == true && mounted) {
      await _refreshTransactions(clearVisible: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('lançamento atualizado')),
      );
    }
  }

  Future<void> _deleteTransaction(TransactionItem item) async {
    final space = _space;
    if (space == null || !item.canEditAsSimple) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'excluir lançamento?',
          style: AppTypography.section(dialogContext, fontSize: 18),
        ),
        content: Text(
          '${financialDisplayDescription(item.description)}\n\n'
          '${Formatters.money(item.amount.abs())} • ${_formatDate(item.occurredAt)}',
          style: AppTypography.body(dialogContext, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.repository.cancelSimpleTransaction(
        spaceId: space.id,
        eventId: item.id,
      );
      if (!mounted) return;
      await _refreshTransactions(clearVisible: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('lançamento excluído')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  Future<void> _editRecurring(RecurringItem item) async {
    final space = _space;
    if (space == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => RecurringFormSheet(
        space: space,
        repository: widget.repository,
        item: item,
      ),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _toggleRecurring(RecurringItem item) async {
    final space = _space;
    if (space == null) return;
    try {
      await widget.repository.setRecurringActive(
        spaceId: space.id,
        itemId: item.id,
        active: !item.active,
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.active ? 'recorrência pausada' : 'recorrência reativada',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  Future<void> _setSubscriptionKind(
    RecurringItem item, {
    required bool subscription,
  }) async {
    final space = _space;
    if (space == null) return;
    try {
      await widget.repository.setRecurringSubscriptionKind(
        spaceId: space.id,
        itemId: item.id,
        subscription: subscription,
      );
      await _refreshRecurring();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subscription
                ? 'recorrência movida para assinaturas'
                : 'assinatura movida para recorrências',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  Future<void> _endSubscription(RecurringItem item) async {
    final space = _space;
    if (space == null || !item.active) return;
    try {
      await widget.repository.setRecurringActive(
        spaceId: space.id,
        itemId: item.id,
        active: false,
      );
      await _refreshRecurring();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('acompanhamento encerrado')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  Future<void> _deleteRecurring(RecurringItem item) async {
    final space = _space;
    if (space == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'excluir recorrência?',
          style: AppTypography.section(dialogContext, fontSize: 18),
        ),
        content: Text(
          '"${item.name}" deixará de ser considerado nos próximos períodos.\n\n'
          'os lançamentos que já aconteceram continuarão no histórico',
          style: AppTypography.body(dialogContext, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteRecurringItem(
        spaceId: space.id,
        itemId: item.id,
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('recorrência excluída')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  Future<void> _realizeRecurring(RecurringItem item) async {
    final space = _space;
    if (space == null) return;
    if (!item.active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('reative essa recorrência antes de realizá-la'),
        ),
      );
      return;
    }

    var initialDate = _suggestOccurrenceDate(item);
    if (initialDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'não há uma ocorrência válida para realizar no período desta recorrência',
          ),
        ),
      );
      return;
    }
    if (initialDate.isBefore(item.startsOn)) initialDate = item.startsOn;
    if (item.endsOn != null && initialDate.isAfter(item.endsOn!)) {
      initialDate = item.endsOn!;
    }

    final dueDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: item.startsOn,
      lastDate: item.endsOn ?? DateTime(2100, 12, 31),
      helpText: item.isIncome
          ? 'qual recebimento aconteceu?'
          : 'qual pagamento aconteceu?',
      cancelText: 'cancelar',
      confirmText: 'continuar',
    );
    if (dueDate == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          item.isIncome ? 'marcar como recebido?' : 'marcar como pago?',
        ),
        content: Text(
          '${item.name}\n\n${Formatters.money(item.amount)}\n'
          '${_formatDate(dueDate)}\n\n'
          'o Fôlego trocará a previsão pelo lançamento real',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(item.isIncome ? 'recebido' : 'pago'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.realizeRecurring(
        spaceId: space.id,
        itemId: item.id,
        dueDate: dueDate,
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.isIncome ? 'receita registrada' : 'gasto registrado',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final accent = AppColors.primaryPurple(brightness);
    final subscriptions = _recurringItems
        .where((item) => _subscriptionIds.contains(item.id))
        .toList(growable: false);
    final regularRecurring = _recurringItems
        .where((item) => !_subscriptionIds.contains(item.id))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: SafeArea(
        child: Column(
          children: [
            AppContentContainer.dashboard(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppPageHeader(
                      title: 'lançamentos',
                      subtitle: 'movimentações, assinaturas e recorrências',
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(AppRadii.compactCard),
                        border: Border.all(color: border),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: accent.withValues(
                            alpha: isDark ? .18 : .10,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        labelColor: primary,
                        unselectedLabelColor: secondary,
                        labelStyle: AppTypography.label(
                          context,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                        unselectedLabelStyle: AppTypography.label(
                          context,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: secondary,
                        ),
                        tabs: const [
                          Tab(text: 'transações'),
                          Tab(text: 'assinaturas'),
                          Tab(text: 'recorrências'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const AppLoadingState(label: 'organizando seus lançamentos')
                  : _error != null
                      ? _ErrorState(
                          message: _error!,
                          onRetry: _retryInitialLoad,
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _TransactionsTabV3(
                              transactions: _transactions,
                              categoryById: _categoryById,
                              filters: _filters,
                              filterOptions: _filterOptions,
                              searchController: _searchController,
                              loading: _loadingTransactions,
                              loadingMore: _loadingMore,
                              hasMore: _hasMoreTransactions,
                              loadMoreError: _loadMoreError,
                              onSearchChanged: _onSearchChanged,
                              onClearSearch: _clearSearch,
                              onOpenFilters: _openFilters,
                              onClearFilters: _clearAllFilters,
                              onRemovePeriod: _removePeriodFilter,
                              onRemoveTypes: _removeTypeFilter,
                              onFiltersChanged: (filters) => _applyFilters(
                                filters,
                                syncSearchField: false,
                              ),
                              onRefresh: _refresh,
                              onLoadMore: _loadMoreTransactions,
                              onOpen: _openTransactionDetail,
                              onEdit: _editTransaction,
                              onDelete: _deleteTransaction,
                            ),
                            SubscriptionsTab(
                              items: subscriptions,
                              recurringCandidates: regularRecurring,
                              cardNames: _recurringCardNames,
                              onRefresh: _refreshRecurring,
                              onEdit: _editRecurring,
                              onEnd: _endSubscription,
                              onClassify: (item) => _setSubscriptionKind(
                                item,
                                subscription: true,
                              ),
                              onMoveToRecurring: (item) => _setSubscriptionKind(
                                item,
                                subscription: false,
                              ),
                            ),
                            _RecurringTab(
                              items: regularRecurring,
                              categories: _categories,
                              isDark: isDark,
                              onRefresh: _refresh,
                              onEdit: _editRecurring,
                              onRealize: _realizeRecurring,
                              onToggle: _toggleRecurring,
                              onDelete: _deleteRecurring,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _suggestOccurrenceDate(RecurringItem item) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (item.frequency) {
      case 'monthly':
        return suggestMonthlyOccurrenceDate(
          referenceDate: today,
          startsOn: item.startsOn,
          endsOn: item.endsOn,
          monthlyDays: item.monthlyDays,
          monthlyLastDay: item.monthlyLastDay,
          dayOfMonth: item.dayOfMonth,
        );
      case 'weekly':
        final target = item.weekday ?? item.startsOn.weekday % 7;
        for (var i = 0; i < 7; i++) {
          final candidate = today.subtract(Duration(days: i));
          if (candidate.weekday % 7 == target) return candidate;
        }
        return today;
      case 'biweekly':
        final start = DateTime(
          item.startsOn.year,
          item.startsOn.month,
          item.startsOn.day,
        );
        final difference = today.difference(start).inDays;
        if (difference <= 0) return start;
        return start.add(Duration(days: (difference ~/ 14) * 14));
      case 'yearly':
        final month = item.monthOfYear ?? item.startsOn.month;
        final day = item.dayOfMonth ?? item.startsOn.day;
        final lastDay = DateTime(today.year, month + 1, 0).day;
        return DateTime(today.year, month, day > lastDay ? lastDay : day);
      default:
        return today;
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('invalid_occurrence')) {
      return 'essa data não corresponde a uma ocorrência prevista';
    }
    if (text.contains('invalid_recurring_item')) {
      return 'essa recorrência não está ativa';
    }
    if (text.contains('space_access_denied') ||
        text.contains('write_access_denied')) {
      return 'você não tem permissão para alterar esse espaço';
    }
    if (text.contains('transaction_type_not_deletable')) {
      return 'esse tipo de lançamento não pode ser excluído por aqui';
    }
    if (text.contains('transaction_not_confirmed')) {
      return 'esse lançamento não está disponível para exclusão';
    }
    if (text.contains('invalid_transaction')) {
      return 'não encontrei esse lançamento';
    }
    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }
}

class _TransactionsTabV3 extends StatelessWidget {
  const _TransactionsTabV3({
    required this.transactions,
    required this.categoryById,
    required this.filters,
    required this.filterOptions,
    required this.searchController,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.loadMoreError,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onOpenFilters,
    required this.onClearFilters,
    required this.onRemovePeriod,
    required this.onRemoveTypes,
    required this.onFiltersChanged,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TransactionItem> transactions;
  final Map<String, CategoryItem> categoryById;
  final TransactionFilters filters;
  final TransactionFilterOptions filterOptions;
  final TextEditingController searchController;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? loadMoreError;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onRemovePeriod;
  final VoidCallback onRemoveTypes;
  final ValueChanged<TransactionFilters> onFiltersChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(TransactionItem) onOpen;
  final Future<void> Function(TransactionItem) onEdit;
  final Future<void> Function(TransactionItem) onDelete;

  @override
  Widget build(BuildContext context) {
    final chips = _activeChips();
    return AppContentContainer.list(
      fillHeight: true,
      child: Column(
        children: [
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final filterCount = filters.activeFilterCount;

              final filterButton = compact
                  ? Tooltip(
                      message: filterCount == 0
                          ? 'filtros'
                          : 'filtros · $filterCount',
                      child: OutlinedButton(
                        key: const ValueKey('transaction-filter-button'),
                        onPressed: onOpenFilters,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(50, 54),
                          padding: EdgeInsets.zero,
                        ),
                        child: Badge(
                          isLabelVisible: filterCount > 0,
                          label: Text('$filterCount'),
                          child: const Icon(AppIcons.filter, size: 19),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      key: const ValueKey('transaction-filter-button'),
                      onPressed: onOpenFilters,
                      icon: const Icon(AppIcons.filter, size: 18),
                      label: Text(
                        filterCount == 0
                            ? 'filtros'
                            : 'filtros · $filterCount',
                      ),
                    );

              return Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController,
                      builder: (context, value, _) {
                        return TextField(
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'buscar lançamento',
                            prefixIcon: const Icon(AppIcons.search, size: 19),
                            suffixIcon: value.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'limpar busca',
                                    onPressed: onClearSearch,
                                    icon: const Icon(AppIcons.close, size: 18),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  filterButton,
                ],
              );
            },
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  ...chips.map(
                    (chip) => InputChip(
                      label: Text(chip.label),
                      onDeleted: chip.onRemove,
                    ),
                  ),
                  TextButton(
                    onPressed: onClearFilters,
                    child: const Text('limpar filtros'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (loading && transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (transactions.isEmpty) {
      final filtered = filters.hasQuery;
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 70, 0, 120),
          children: [
            AppEmptyState(
              icon: filtered ? AppIcons.search : AppIcons.transactions,
              title: filtered
                  ? 'nenhum lançamento por aqui'
                  : 'nenhum lançamento ainda',
              description: filtered
                  ? 'tente ajustar os filtros ou a busca'
                  : 'seus gastos, receitas e movimentações aparecerão aqui',
            ),
          ],
        ),
      );
    }

    final showFooter = loadingMore || loadMoreError != null;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasMore &&
            !loadingMore &&
            !loading &&
            notification.metrics.extentAfter < 360) {
          onLoadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
          itemCount: transactions.length + (showFooter ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index >= transactions.length) {
              return _TransactionLoadMoreFooterV3(
                loading: loadingMore,
                error: loadMoreError,
                onRetry: onLoadMore,
              );
            }
            final item = transactions[index];
            return _TransactionCardV3(
              item: item,
              visual: _visualFor(item, context),
              onOpen: () => onOpen(item),
              onEdit: item.canEditAsSimple ? () => onEdit(item) : null,
              onDelete: item.canEditAsSimple ? () => onDelete(item) : null,
            );
          },
        ),
      ),
    );
  }

  List<_ActiveFilterChip> _activeChips() {
    final chips = <_ActiveFilterChip>[];
    if (filters.hasPeriod) {
      chips.add(
        _ActiveFilterChip(
          _periodChipLabel(filters),
          onRemovePeriod,
        ),
      );
    }
    if (filters.eventTypes.isNotEmpty) {
      final label = filters.eventTypes.length == 1
          ? transactionEventTypeLabel(filters.eventTypes.first)
          : '${filters.eventTypes.length} tipos';
      chips.add(_ActiveFilterChip(label, onRemoveTypes));
    }
    if (filters.categoryId != null) {
      chips.add(
        _ActiveFilterChip(
          _categoryLabel(filters.categoryId!),
          () => onFiltersChanged(filters.copyWith(categoryId: null)),
        ),
      );
    }
    if (filters.accountId != null) {
      chips.add(
        _ActiveFilterChip(
          _accountLabel(filters.accountId!),
          () => onFiltersChanged(filters.copyWith(accountId: null)),
        ),
      );
    }
    if (filters.cardId != null) {
      chips.add(
        _ActiveFilterChip(
          _cardLabel(filters.cardId!),
          () => onFiltersChanged(filters.copyWith(cardId: null)),
        ),
      );
    }
    if (filters.benefitAccountId != null) {
      chips.add(
        _ActiveFilterChip(
          _benefitLabel(filters.benefitAccountId!),
          () => onFiltersChanged(filters.copyWith(benefitAccountId: null)),
        ),
      );
    }
    return chips;
  }

  String _categoryLabel(String id) {
    for (final item in filterOptions.categories) {
      if (item.id == id) return item.breadcrumb;
    }
    return 'categoria';
  }

  String _accountLabel(String id) {
    for (final item in filterOptions.accounts) {
      if (item.id == id) return item.name;
    }
    return 'conta';
  }

  String _cardLabel(String id) {
    for (final item in filterOptions.cards) {
      if (item.id == id) return item.name;
    }
    return 'cartão';
  }

  String _benefitLabel(String id) {
    for (final item in filterOptions.benefits) {
      if (item.id == id) return item.name;
    }
    return 'benefício';
  }

  _TransactionVisual _visualFor(TransactionItem item, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (item.eventType == 'transfer' || item.eventType == 'reserve_transfer') {
      return _TransactionVisual(
        icon: AppIcons.transfer,
        color: AppColors.primaryPurple(brightness),
      );
    }
    if (item.eventType == 'card_payment') {
      return _TransactionVisual(
        icon: AppIcons.creditCard,
        color: AppColors.primaryPurple(brightness),
      );
    }
    if (item.isIncome || item.eventType == 'benefit_credit') {
      return _TransactionVisual(
        icon: CategoryVisuals.iconFor(category: 'Receitas'),
        color: CategoryVisuals.colorFor(
          category: 'Receitas',
          brightness: brightness,
        ),
      );
    }

    var categoryName = item.categoryName ?? 'A classificar';
    String? subcategory;
    if (item.categoryParentId != null) {
      final parent = categoryById[item.categoryParentId!];
      if (parent != null) {
        subcategory = categoryName;
        categoryName = parent.name;
      }
    }
    return _TransactionVisual(
      icon: CategoryVisuals.iconFor(
        category: categoryName,
        subcategory: subcategory,
      ),
      color: CategoryVisuals.colorFor(
        category: categoryName,
        brightness: brightness,
      ),
    );
  }
}

class _TransactionCardV3 extends StatelessWidget {
  const _TransactionCardV3({
    required this.item,
    required this.visual,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
  });

  final TransactionItem item;
  final _TransactionVisual visual;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final amountColor = item.isIncome
        ? AppColors.positiveText(brightness)
        : item.isExpense
            ? AppColors.expenseText(brightness)
            : primary;
    final categoryLabel = item.categoryName?.trim().isNotEmpty == true
        ? item.categoryName!.trim()
        : transactionEventTypeLabel(item.eventType);
    final hasDetailActions = onEdit != null || onDelete != null;

    return Semantics(
      button: true,
      label:
          '${financialDisplayDescription(item.description)}, ${Formatters.money(item.amount.abs())}',
      hint: hasDetailActions
          ? 'abrir detalhe e ações do lançamento'
          : 'abrir detalhe do lançamento',
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              children: [
                CategoryIconBadge(
                  icon: visual.icon,
                  color: visual.color,
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
                        financialDisplayDescription(item.description),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          categoryLabel,
                          _formatDate(item.occurredAt),
                          if (item.accountName != null) item.accountName!,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          context,
                          fontSize: 11,
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${item.isIncome ? '+' : item.isExpense ? '−' : ''}${Formatters.money(item.amount.abs())}',
                  style: AppTypography.money(
                    context,
                    fontSize: 13,
                    color: amountColor,
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

class _TransactionLoadMoreFooterV3 extends StatelessWidget {
  const _TransactionLoadMoreFooterV3({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            'não consegui carregar mais lançamentos',
            style: AppTypography.body(context, fontSize: 12),
          ),
          TextButton(onPressed: onRetry, child: const Text('tentar de novo')),
        ],
      ),
    );
  }
}

class _ActiveFilterChip {
  const _ActiveFilterChip(this.label, this.onRemove);
  final String label;
  final VoidCallback onRemove;
}

class _TransactionVisual {
  const _TransactionVisual({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}

String _periodChipLabel(TransactionFilters filters) {
  if (filters.startDate != null && filters.endDate != null) {
    return '${_formatDate(filters.startDate!)} — ${_formatDate(filters.endDate!)}';
  }
  if (filters.startDate != null) {
    return 'desde ${_formatDate(filters.startDate!)}';
  }
  return 'até ${_formatDate(filters.endDate!)}';
}
