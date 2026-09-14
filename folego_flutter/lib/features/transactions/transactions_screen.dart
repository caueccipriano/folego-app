import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/recurring_item.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_actions.dart';
import '../../shared/widgets/category_icon_badge.dart';
import 'recurring_form_sheet.dart';
import 'transaction_edit_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, required this.repository});

  final FolegoRepository repository;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  FinancialSpace? _space;

  List<TransactionItem> _transactions = const [];
  List<RecurringItem> _recurringItems = const [];
  List<CategoryItem> _categories = const [];

  final Map<String, _PendingTransactionDeletion> _pendingDeletions = {};
  final Set<String> _hiddenTransactionIds = <String>{};

  bool _loading = true;
  String? _error;

  Map<String, CategoryItem> get _categoryById {
    return {for (final category in _categories) category.id: category};
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final space = await widget.repository.getPrimarySpace();

      final results = await Future.wait([
        widget.repository.getTransactions(space.id),
        widget.repository.listRecurringItems(space.id),
        widget.repository.listExpenseCategories(space.id),
        widget.repository.listIncomeCategories(space.id),
      ]);

      if (!mounted) {
        return;
      }

      final rawTransactions = results[0] as List<TransactionItem>;

      final visibleTransactions = rawTransactions
          .where(
            (transaction) => !_hiddenTransactionIds.contains(transaction.id),
          )
          .toList();

      final rawTransactionIds = rawTransactions
          .map((transaction) => transaction.id)
          .toSet();

      final expenseCategories = results[2] as List<CategoryItem>;

      final incomeCategories = results[3] as List<CategoryItem>;

      final categoriesById = <String, CategoryItem>{};

      for (final category in [...expenseCategories, ...incomeCategories]) {
        categoriesById[category.id] = category;
      }

      setState(() {
        _space = space;

        _transactions = visibleTransactions;

        _recurringItems = results[1] as List<RecurringItem>;

        _categories = categoriesById.values.toList();

        _hiddenTransactionIds.removeWhere(
          (eventId) =>
              !_pendingDeletions.containsKey(eventId) &&
              !rawTransactionIds.contains(eventId),
        );

        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _editTransaction(TransactionItem item) async {
    final space = _space;

    if (space == null) {
      return;
    }

    if (!item.canEditAsSimple) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esse tipo de lançamento possui um fluxo próprio e ainda não pode ser editado por aqui.',
          ),
        ),
      );

      return;
    }

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

    if (saved == true) {
      await _load();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lançamento atualizado.')));
    }
  }

  Future<void> _deleteTransaction(TransactionItem item) async {
    final space = _space;

    if (space == null) {
      return;
    }

    if (!item.canEditAsSimple) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esse tipo de lançamento possui um fluxo próprio e não pode ser excluído por aqui.',
          ),
        ),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final brightness = Theme.of(dialogContext).brightness;

        final secondaryText = AppColors.secondaryText(brightness);

        return AlertDialog(
          title: Text(
            'Excluir lançamento?',
            style: AppTypography.section(dialogContext, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.description,
                style: AppTypography.body(
                  dialogContext,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${Formatters.money(item.amount.abs())} • ${_formatDate(item.occurredAt)}',
                style: AppTypography.body(
                  dialogContext,
                  fontSize: 12,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'O impacto deste lançamento será removido do saldo, do orçamento e do Fôlego.',
                style: AppTypography.body(
                  dialogContext,
                  fontSize: 12,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Se ele estiver ligado a uma recorrência, a previsão voltará a ficar pendente.',
                style: AppTypography.body(
                  dialogContext,
                  fontSize: 12,
                  color: secondaryText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    if (_pendingDeletions.containsKey(item.id)) {
      return;
    }

    final originalIndex = _transactions.indexWhere(
      (transaction) => transaction.id == item.id,
    );

    if (originalIndex < 0) {
      return;
    }

    final pending = _PendingTransactionDeletion(
      eventId: item.id,
      item: item,
      originalIndex: originalIndex,
      spaceId: space.id,
    );

    setState(() {
      _pendingDeletions[item.id] = pending;
      _hiddenTransactionIds.add(item.id);
      _transactions = _transactions
          .where((transaction) => transaction.id != item.id)
          .toList();
    });

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lançamento excluído.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () {
            _undoPendingDeletion(item.id);
          },
        ),
      ),
    );

    await controller.closed;
    await _commitPendingDeletion(item.id);
  }

  void _undoPendingDeletion(String eventId) {
    final pending = _pendingDeletions[eventId];

    if (pending == null || pending.committing) {
      return;
    }

    _pendingDeletions.remove(eventId);
    _hiddenTransactionIds.remove(eventId);

    _restorePendingDeletion(pending);
  }

  Future<void> _commitPendingDeletion(String eventId) async {
    final pending = _pendingDeletions[eventId];

    if (pending == null || pending.committing) {
      return;
    }

    pending.committing = true;

    try {
      await widget.repository.cancelSimpleTransaction(
        spaceId: pending.spaceId,
        eventId: pending.eventId,
      );

      if (identical(_pendingDeletions[eventId], pending)) {
        _pendingDeletions.remove(eventId);
      }
    } catch (error) {
      if (identical(_pendingDeletions[eventId], pending)) {
        _pendingDeletions.remove(eventId);
      }

      _hiddenTransactionIds.remove(eventId);

      if (!mounted) {
        return;
      }

      _restorePendingDeletion(pending);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível excluir o lançamento. ${_friendlyError(error)}',
          ),
        ),
      );
    }
  }

  void _restorePendingDeletion(_PendingTransactionDeletion pending) {
    if (!mounted) {
      return;
    }

    setState(() {
      if (_transactions.any(
        (transaction) => transaction.id == pending.eventId,
      )) {
        return;
      }

      var insertIndex = pending.originalIndex;

      for (final other in _pendingDeletions.values) {
        if (other.eventId != pending.eventId &&
            other.originalIndex < pending.originalIndex) {
          insertIndex -= 1;
        }
      }

      if (insertIndex < 0) {
        insertIndex = 0;
      }

      if (insertIndex > _transactions.length) {
        insertIndex = _transactions.length;
      }

      final restored = [..._transactions]
        ..insert(insertIndex, pending.item);

      _transactions = restored;
    });
  }

  Future<void> _editRecurring(RecurringItem item) async {
    final space = _space;

    if (space == null) {
      return;
    }

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

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _toggleRecurring(RecurringItem item) async {
    final space = _space;

    if (space == null) {
      return;
    }

    try {
      await widget.repository.setRecurringActive(
        spaceId: space.id,
        itemId: item.id,
        active: !item.active,
      );

      await _load();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.active ? 'Recorrência pausada.' : 'Recorrência reativada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _deleteRecurring(RecurringItem item) async {
    final space = _space;

    if (space == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Excluir recorrência?',
            style: AppTypography.section(dialogContext, fontSize: 18),
          ),
          content: Text(
            '"${item.name}" deixará de ser considerado nos próximos períodos.\n\n'
            'Os lançamentos que já aconteceram continuarão no histórico.',
            style: AppTypography.body(dialogContext, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.repository.deleteRecurringItem(
        spaceId: space.id,
        itemId: item.id,
      );

      await _load();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recorrência excluída.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _realizeRecurring(RecurringItem item) async {
    final space = _space;

    if (space == null) {
      return;
    }

    if (!item.active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reative essa recorrência antes de realizá-la.'),
        ),
      );

      return;
    }

    var initialDate = _suggestOccurrenceDate(item);

    if (initialDate.isBefore(item.startsOn)) {
      initialDate = item.startsOn;
    }

    if (item.endsOn != null && initialDate.isAfter(item.endsOn!)) {
      initialDate = item.endsOn!;
    }

    final dueDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: item.startsOn,
      lastDate: item.endsOn ?? DateTime(2100, 12, 31),
      helpText: item.isIncome
          ? 'Qual recebimento aconteceu?'
          : 'Qual pagamento aconteceu?',
      cancelText: 'Cancelar',
      confirmText: 'Continuar',
    );

    if (dueDate == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            item.isIncome ? 'Marcar como recebido?' : 'Marcar como pago?',
          ),
          content: Text(
            '${item.name}\n\n'
            '${Formatters.money(item.amount)}\n'
            '${_formatDate(dueDate)}\n\n'
            'O Fôlego trocará a previsão pelo lançamento real.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(item.isIncome ? 'Recebido' : 'Pago'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.repository.realizeRecurring(
        spaceId: space.id,
        itemId: item.id,
        dueDate: dueDate,
      );

      await _load();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.isIncome ? 'Receita registrada.' : 'Gasto registrado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lançamentos',
          style: AppTypography.section(context, fontSize: 21),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Transações'),
            Tab(text: 'Recorrências'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : TabBarView(
              controller: _tabController,
              children: [
                _TransactionsTab(
                  transactions: _transactions,
                  categoryById: _categoryById,
                  onRefresh: _load,
                  onEdit: _editTransaction,
                  onDelete: _deleteTransaction,
                ),
                _RecurringTab(
                  items: _recurringItems,
                  categories: _categories,
                  isDark: isDark,
                  onRefresh: _load,
                  onEdit: _editRecurring,
                  onRealize: _realizeRecurring,
                  onToggle: _toggleRecurring,
                  onDelete: _deleteRecurring,
                ),
              ],
            ),
    );
  }

  DateTime _suggestOccurrenceDate(RecurringItem item) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    switch (item.frequency) {
      case 'monthly':
        final day = item.dayOfMonth ?? item.startsOn.day;

        final lastDay = DateTime(today.year, today.month + 1, 0).day;

        return DateTime(today.year, today.month, day > lastDay ? lastDay : day);

      case 'weekly':
        final target = item.weekday ?? item.startsOn.weekday % 7;

        for (var i = 0; i < 7; i++) {
          final candidate = today.subtract(Duration(days: i));

          if (candidate.weekday % 7 == target) {
            return candidate;
          }
        }

        return today;

      case 'biweekly':
        final start = DateTime(
          item.startsOn.year,
          item.startsOn.month,
          item.startsOn.day,
        );

        final difference = today.difference(start).inDays;

        if (difference <= 0) {
          return start;
        }

        final periods = difference ~/ 14;

        return start.add(Duration(days: periods * 14));

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
      return 'Essa data não corresponde a uma ocorrência prevista.';
    }

    if (text.contains('invalid_recurring_item')) {
      return 'Essa recorrência não está ativa.';
    }

    if (text.contains('write_access_denied')) {
      return 'Você não tem permissão para alterar esse espaço.';
    }

    if (text.contains('transaction_type_not_deletable')) {
      return 'Esse tipo de lançamento não pode ser excluído por aqui.';
    }

    if (text.contains('transaction_not_confirmed')) {
      return 'Esse lançamento não está disponível para exclusão.';
    }

    if (text.contains('invalid_transaction')) {
      return 'Não encontrei esse lançamento.';
    }

    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }
}

class _PendingTransactionDeletion {
  _PendingTransactionDeletion({
    required this.eventId,
    required this.item,
    required this.originalIndex,
    required this.spaceId,
  });

  final String eventId;
  final TransactionItem item;
  final int originalIndex;
  final String spaceId;

  bool committing = false;
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.transactions,
    required this.categoryById,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TransactionItem> transactions;
  final Map<String, CategoryItem> categoryById;

  final Future<void> Function() onRefresh;

  final Future<void> Function(TransactionItem) onEdit;

  final Future<void> Function(TransactionItem) onDelete;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 110),
                Icon(
                  CategoryVisuals.iconFor(category: 'A classificar'),
                  size: 46,
                  color: CategoryVisuals.colorFor(
                    category: 'A classificar',
                    brightness: Theme.of(context).brightness,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Nenhum lançamento ainda.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final transaction = transactions[index];

              return _TransactionCard(
                transaction: transaction,
                categoryById: categoryById,
                onEdit: () => onEdit(transaction),
                onDelete: () => onDelete(transaction),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.categoryById,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionItem transaction;
  final Map<String, CategoryItem> categoryById;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final isDark = brightness == Brightness.dark;

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final border = AppColors.border(brightness);

    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final visual = _visualForTransaction(context);

    final amountColor = transaction.isIncome
        ? isDark
              ? AppPalette.lime
              : AppPalette.green
        : transaction.isExpense
        ? AppPalette.pink
        : primaryText;

    final typeLabel = transaction.isIncome
        ? 'Receita'
        : transaction.isExpense
        ? 'Gasto'
        : _typeLabel(transaction.eventType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: transaction.canEditAsSimple ? onEdit : null,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryIconBadge(
                icon: visual.icon,
                color: visual.color,
                size: 48,
                iconSize: 24,
                radius: 15,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaPill(
                          label: typeLabel,
                          foreground: visual.color,
                          background: visual.color.withValues(alpha: .11),
                        ),
                        if (transaction.categoryName != null)
                          _MetaPill(
                            label: transaction.categoryName!,
                            foreground: secondaryText,
                            background: secondaryText.withValues(alpha: .08),
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      [
                        if (transaction.accountName != null)
                          transaction.accountName!,
                        _formatDate(transaction.occurredAt),
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.money(transaction.amount.abs()),
                    style: AppTypography.money(
                      context,
                      fontSize: 14,
                      color: amountColor,
                    ),
                  ),
                  if (transaction.canEditAsSimple) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        _showTransactionActions(context);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: secondaryText.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          '⋮',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 22,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransactionActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _FolegoActionSheet(
          title: transaction.description,
          actions: const [
            _SheetAction(value: 'edit', label: 'Editar'),
            _SheetAction(value: 'delete', label: 'Excluir', destructive: true),
          ],
        );
      },
    );

    switch (action) {
      case 'edit':
        onEdit();
        break;

      case 'delete':
        onDelete();
        break;
    }
  }

  _TransactionVisual _visualForTransaction(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final categoryName = transaction.categoryName;

    final parentId = transaction.categoryParentId;

    String? category = categoryName;

    String? subcategory;

    if (parentId != null) {
      final parent = categoryById[parentId];

      if (parent != null) {
        category = parent.name;
        subcategory = categoryName;
      }
    }

    if (transaction.isIncome && categoryName == null) {
      return _TransactionVisual(
        icon: CategoryVisuals.iconFor(category: 'Receitas'),
        color: CategoryVisuals.colorFor(
          category: 'Receitas',
          brightness: brightness,
        ),
      );
    }

    if (category != null && category.trim().isNotEmpty) {
      return _TransactionVisual(
        icon: CategoryVisuals.iconFor(
          category: category,
          subcategory: subcategory,
        ),
        color: CategoryVisuals.colorFor(
          category: category,
          brightness: brightness,
        ),
      );
    }

    return _TransactionVisual(
      icon: CategoryVisuals.iconFor(category: 'A classificar'),
      color: CategoryVisuals.colorFor(
        category: 'A classificar',
        brightness: brightness,
      ),
    );
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'transfer':
        return 'Transferência';

      case 'card_purchase':
        return 'Cartão';

      case 'card_payment':
        return 'Pagamento';

      case 'opening_balance':
        return 'Saldo inicial';

      case 'benefit_expense':
        return 'Benefício';

      case 'debt_payment':
        return 'Dívida';

      default:
        return 'Lançamento';
    }
  }
}

class _TransactionVisual {
  const _TransactionVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: AppTypography.label(
          context,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _RecurringTab extends StatelessWidget {
  const _RecurringTab({
    required this.items,
    required this.categories,
    required this.isDark,
    required this.onRefresh,
    required this.onEdit,
    required this.onRealize,
    required this.onToggle,
    required this.onDelete,
  });

  final List<RecurringItem> items;
  final List<CategoryItem> categories;

  final bool isDark;

  final Future<void> Function() onRefresh;

  final Future<void> Function(RecurringItem) onEdit;

  final Future<void> Function(RecurringItem) onRealize;

  final Future<void> Function(RecurringItem) onToggle;

  final Future<void> Function(RecurringItem) onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 90, 22, 120),
              children: [
                CategoryIconBadge(
                  icon: CategoryVisuals.iconFor(category: 'A classificar'),
                  color: CategoryVisuals.colorFor(
                    category: 'A classificar',
                    brightness: Theme.of(context).brightness,
                  ),
                  size: 50,
                  iconSize: 25,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma recorrência',
                  textAlign: TextAlign.center,
                  style: AppTypography.section(context, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Para criar uma, volte para a Home e registre um Gasto ou Receita escolhendo uma repetição.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .58),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
            children: [
              Text(
                'Suas recorrências',
                style: AppTypography.section(context, fontSize: 18),
              ),
              const SizedBox(height: 5),
              Text(
                'Edite ou pause o que se repete no seu mês.',
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .58),
                ),
              ),
              const SizedBox(height: 20),
              ...items.map(
                (item) => _RecurringCard(
                  item: item,
                  categories: categories,
                  isDark: isDark,
                  onEdit: () => onEdit(item),
                  onRealize: () => onRealize(item),
                  onToggle: () => onToggle(item),
                  onDelete: () => onDelete(item),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    required this.item,
    required this.categories,
    required this.isDark,
    required this.onEdit,
    required this.onRealize,
    required this.onToggle,
    required this.onDelete,
  });

  final RecurringItem item;
  final List<CategoryItem> categories;

  final bool isDark;

  final VoidCallback onEdit;
  final VoidCallback onRealize;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final border = AppColors.border(brightness);

    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final visual = _visualForRecurring(context);

    final amountColor = item.isIncome
        ? isDark
              ? AppPalette.lime
              : AppPalette.green
        : primaryText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          CategoryIconBadge(
            icon: visual.icon,
            color: visual.color,
            size: 46,
            iconSize: 23,
            radius: 15,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTypography.body(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.money(item.amount),
                      style: AppTypography.money(
                        context,
                        fontSize: 14,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.scheduleLabel,
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    item.typeLabel,
                    if (item.categoryName != null) item.categoryName!,
                    if (item.accountName != null) item.accountName!,
                  ].join(' • '),
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.active
                        ? AppPalette.green.withValues(alpha: .13)
                        : secondaryText.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    item.active ? 'Ativa' : 'Pausada',
                    style: AppTypography.label(
                      context,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: item.active ? AppPalette.green : secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              _showRecurringActions(context);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: secondaryText.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Text(
                '⋮',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TransactionVisual _visualForRecurring(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (item.isIncome) {
      return _TransactionVisual(
        icon: CategoryVisuals.iconFor(category: 'Receitas'),
        color: CategoryVisuals.colorFor(
          category: 'Receitas',
          brightness: brightness,
        ),
      );
    }

    final name = item.categoryName;

    if (name == null || name.trim().isEmpty) {
      return _TransactionVisual(
        icon: CategoryVisuals.iconFor(category: 'A classificar'),
        color: CategoryVisuals.colorFor(
          category: 'A classificar',
          brightness: brightness,
        ),
      );
    }

    CategoryItem? matched;

    for (final category in categories) {
      if (category.name == name) {
        matched = category;
        break;
      }
    }

    String categoryName = name;

    String? subcategory;

    if (matched?.parentId != null) {
      for (final parent in categories) {
        if (parent.id == matched!.parentId) {
          categoryName = parent.name;

          subcategory = matched.name;

          break;
        }
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

  Future<void> _showRecurringActions(BuildContext context) async {
    final actions = <_SheetAction>[
      if (item.active)
        _SheetAction(
          value: 'realize',
          label: item.isIncome ? 'Marcar como recebido' : 'Marcar como pago',
        ),
      const _SheetAction(value: 'edit', label: 'Editar recorrência'),
      _SheetAction(value: 'toggle', label: item.active ? 'Pausar' : 'Reativar'),
      const _SheetAction(
        value: 'delete',
        label: 'Excluir recorrência',
        destructive: true,
      ),
    ];

    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _FolegoActionSheet(title: item.name, actions: actions);
      },
    );

    switch (action) {
      case 'realize':
        onRealize();
        break;

      case 'edit':
        onEdit();
        break;

      case 'toggle':
        onToggle();
        break;

      case 'delete':
        onDelete();
        break;
    }
  }
}

class _FolegoActionSheet extends StatelessWidget {
  const _FolegoActionSheet({required this.title, required this.actions});

  final String title;
  final List<_SheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final isDark = brightness == Brightness.dark;

    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final border = AppColors.border(brightness);

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 14),
              ...actions.map((action) {
                final foreground = action.destructive
                    ? AppPalette.pink
                    : primaryText;

                final background = action.destructive
                    ? AppPalette.pink.withValues(alpha: .09)
                    : secondaryText.withValues(alpha: .07);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop(action.value);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        action.label,
                        textAlign: TextAlign.center,
                        style: AppTypography.body(
                          context,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction {
  const _SheetAction({
    required this.value,
    required this.label,
    this.destructive = false,
  });

  final String value;
  final String label;
  final bool destructive;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 46),
            const SizedBox(height: 14),
            Text(
              'Não foi possível carregar os lançamentos.',
              textAlign: TextAlign.center,
              style: AppTypography.section(context, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body(context, fontSize: 12),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');

  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}
