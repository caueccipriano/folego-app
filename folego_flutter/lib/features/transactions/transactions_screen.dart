import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/recurring_item.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import 'recurring_form_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.repository,
  });

  final FolegoRepository repository;

  @override
  State<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  FinancialSpace? _space;

  List<TransactionItem> _transactions = const [];
  List<RecurringItem> _recurringItems = const [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

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
      final space =
          await widget.repository.getPrimarySpace();

      final results = await Future.wait([
        widget.repository.getTransactions(
          space.id,
        ),
        widget.repository.listRecurringItems(
          space.id,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _space = space;

        _transactions =
            results[0] as List<TransactionItem>;

        _recurringItems =
            results[1] as List<RecurringItem>;

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

  Future<void> _editRecurring(
    RecurringItem item,
  ) async {
    final space = _space;

    if (space == null) {
      return;
    }

    final saved =
        await showModalBottomSheet<bool>(
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

  Future<void> _toggleRecurring(
    RecurringItem item,
  ) async {
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
            item.active
                ? 'Recorrência pausada.'
                : 'Recorrência reativada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(error),
          ),
        ),
      );
    }
  }

  Future<void> _deleteRecurring(
    RecurringItem item,
  ) async {
    final space = _space;

    if (space == null) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Excluir recorrência?',
          ),
          content: Text(
            '"${item.name}" deixará de ser considerado nos próximos períodos.\n\n'
            'Os lançamentos que já aconteceram continuarão no histórico.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Excluir',
              ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recorrência excluída.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(error),
          ),
        ),
      );
    }
  }

  Future<void> _realizeRecurring(
    RecurringItem item,
  ) async {
    final space = _space;

    if (space == null) {
      return;
    }

    if (!item.active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reative essa recorrência antes de realizá-la.',
          ),
        ),
      );

      return;
    }

    var initialDate =
        _suggestOccurrenceDate(item);

    if (initialDate.isBefore(item.startsOn)) {
      initialDate = item.startsOn;
    }

    if (item.endsOn != null &&
        initialDate.isAfter(item.endsOn!)) {
      initialDate = item.endsOn!;
    }

    final dueDate =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: item.startsOn,
      lastDate:
          item.endsOn ??
          DateTime(2100, 12, 31),
      helpText: item.isIncome
          ? 'Qual recebimento aconteceu?'
          : 'Qual pagamento aconteceu?',
      cancelText: 'Cancelar',
      confirmText: 'Continuar',
    );

    if (dueDate == null ||
        !mounted) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            item.isIncome
                ? 'Marcar como recebido?'
                : 'Marcar como pago?',
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
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(
                item.isIncome
                    ? 'Recebido'
                    : 'Pago',
              ),
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
            item.isIncome
                ? 'Receita registrada.'
                : 'Gasto registrado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(error),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lançamentos',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'Transações',
            ),
            Tab(
              text: 'Recorrências',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _error != null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _load,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _TransactionsTab(
                      transactions:
                          _transactions,
                      onRefresh: _load,
                    ),
                    _RecurringTab(
                      items:
                          _recurringItems,
                      isDark: isDark,
                      onRefresh: _load,
                      onEdit:
                          _editRecurring,
                      onRealize:
                          _realizeRecurring,
                      onToggle:
                          _toggleRecurring,
                      onDelete:
                          _deleteRecurring,
                    ),
                  ],
                ),
    );
  }

  DateTime _suggestOccurrenceDate(
    RecurringItem item,
  ) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    switch (item.frequency) {
      case 'monthly':
        final day =
            item.dayOfMonth ??
                item.startsOn.day;

        final lastDay = DateTime(
          today.year,
          today.month + 1,
          0,
        ).day;

        return DateTime(
          today.year,
          today.month,
          day > lastDay
              ? lastDay
              : day,
        );

      case 'weekly':
        final target =
            item.weekday ??
                item.startsOn.weekday % 7;

        for (var i = 0; i < 7; i++) {
          final candidate =
              today.subtract(
            Duration(days: i),
          );

          if (candidate.weekday % 7 ==
              target) {
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

        final difference =
            today.difference(start).inDays;

        if (difference <= 0) {
          return start;
        }

        final periods =
            difference ~/ 14;

        return start.add(
          Duration(
            days: periods * 14,
          ),
        );

      case 'yearly':
        final month =
            item.monthOfYear ??
                item.startsOn.month;

        final day =
            item.dayOfMonth ??
                item.startsOn.day;

        final lastDay = DateTime(
          today.year,
          month + 1,
          0,
        ).day;

        return DateTime(
          today.year,
          month,
          day > lastDay
              ? lastDay
              : day,
        );

      default:
        return today;
    }
  }

  String _friendlyError(
    Object error,
  ) {
    final text =
        error.toString();

    if (text.contains(
      'invalid_occurrence',
    )) {
      return 'Essa data não corresponde a uma ocorrência prevista.';
    }

    if (text.contains(
      'invalid_recurring_item',
    )) {
      return 'Essa recorrência não está ativa.';
    }

    if (text.contains(
      'write_access_denied',
    )) {
      return 'Você não tem permissão para alterar esse espaço.';
    }

    return text
        .replaceFirst(
          'Exception: ',
          '',
        )
        .replaceFirst(
          'Invalid argument(s): ',
          '',
        );
  }
}

class _TransactionsTab
    extends StatelessWidget {
  const _TransactionsTab({
    required this.transactions,
    required this.onRefresh,
  });

  final List<TransactionItem> transactions;

  final Future<void> Function()
      onRefresh;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
            ),
            SizedBox(height: 14),
            Text(
              'Nenhum lançamento ainda.',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          120,
        ),
        itemCount:
            transactions.length,
        separatorBuilder:
            (context, index) =>
                const Divider(
          height: 1,
        ),
        itemBuilder:
            (context, index) {
          final transaction =
              transactions[index];

          final income =
              transaction.eventType ==
                  'income';

          final expense =
              _isExpense(
            transaction.eventType,
          );

          final amountColor =
              income
                  ? AppPalette.green
                  : expense
                      ? AppPalette.pink
                      : Theme.of(context)
                          .colorScheme
                          .onSurface;

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            leading: CircleAvatar(
              child: Icon(
                _iconForType(
                  transaction.eventType,
                ),
              ),
            ),
            title: Text(
              transaction.description,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            subtitle: Text(
              [
                if (transaction
                        .categoryName !=
                    null)
                  transaction
                      .categoryName!,
                _formatDate(
                  transaction.occurredAt,
                ),
              ].join(' • '),
            ),
            trailing: Text(
              Formatters.money(
                transaction.amount.abs(),
              ),
              style: TextStyle(
                color: amountColor,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          );
        },
      ),
    );
  }

  static bool _isExpense(
    String type,
  ) {
    return type == 'expense' ||
        type == 'card_purchase' ||
        type == 'benefit_expense' ||
        type == 'debt_payment';
  }

  static IconData _iconForType(
    String type,
  ) {
    switch (type) {
      case 'income':
        return Icons
            .south_west_rounded;

      case 'expense':
        return Icons
            .north_east_rounded;

      case 'transfer':
        return Icons
            .swap_horiz_rounded;

      case 'card_purchase':
        return Icons
            .credit_card_rounded;

      case 'card_payment':
        return Icons
            .receipt_long_rounded;

      case 'opening_balance':
        return Icons
            .account_balance_wallet_outlined;

      default:
        return Icons
            .payments_outlined;
    }
  }
}

class _RecurringTab
    extends StatelessWidget {
  const _RecurringTab({
    required this.items,
    required this.isDark,
    required this.onRefresh,
    required this.onEdit,
    required this.onRealize,
    required this.onToggle,
    required this.onDelete,
  });

  final List<RecurringItem> items;

  final bool isDark;

  final Future<void> Function()
      onRefresh;

  final Future<void> Function(
    RecurringItem,
  ) onEdit;

  final Future<void> Function(
    RecurringItem,
  ) onRealize;

  final Future<void> Function(
    RecurringItem,
  ) onToggle;

  final Future<void> Function(
    RecurringItem,
  ) onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            22,
            90,
            22,
            120,
          ),
          children: [
            const Icon(
              Icons.autorenew_rounded,
              size: 50,
              color:
                  AppPalette.purple,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma recorrência',
              textAlign:
                  TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Para criar uma, volte para a Home e registre um Gasto ou Receita escolhendo uma repetição.',
              textAlign:
                  TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    height: 1.4,
                    color:
                        Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(
                              alpha: .58,
                            ),
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          120,
        ),
        children: [
          Text(
            'suas recorrências',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            'Edite ou pause o que se repete no seu mês.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color:
                      Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(
                            alpha: .58,
                          ),
                ),
          ),
          const SizedBox(height: 20),
          ...items.map(
            (item) =>
                _RecurringCard(
              item: item,
              isDark: isDark,
              onEdit: () =>
                  onEdit(item),
              onRealize: () =>
                  onRealize(item),
              onToggle: () =>
                  onToggle(item),
              onDelete: () =>
                  onDelete(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringCard
    extends StatelessWidget {
  const _RecurringCard({
    required this.item,
    required this.isDark,
    required this.onEdit,
    required this.onRealize,
    required this.onToggle,
    required this.onDelete,
  });

  final RecurringItem item;

  final bool isDark;

  final VoidCallback onEdit;
  final VoidCallback onRealize;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amountColor =
        item.isIncome
            ? isDark
                ? AppPalette.lime
                : AppPalette.green
            : Theme.of(context)
                .colorScheme
                .onSurface;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.fromLTRB(
        16,
        15,
        8,
        15,
      ),
      decoration: BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color:
              Theme.of(context)
                  .dividerColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.isIncome
                  ? AppPalette.purple
                      .withValues(
                        alpha: .13,
                      )
                  : AppPalette.lime,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Icon(
              item.isIncome
                  ? Icons
                      .payments_rounded
                  : Icons
                      .receipt_long_rounded,
              color: item.isIncome
                  ? AppPalette.purple
                  : const Color(
                      0xFF111111,
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      Formatters.money(
                        item.amount,
                      ),
                      style: TextStyle(
                        color:
                            amountColor,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.scheduleLabel,
                  style:
                      Theme.of(context)
                          .textTheme
                          .bodyMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    item.typeLabel,
                    if (item.categoryName !=
                        null)
                      item.categoryName!,
                    if (item.accountName !=
                        null)
                      item.accountName!,
                  ].join(' • '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color:
                            Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(
                                  alpha: .58,
                                ),
                      ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color: item.active
                        ? AppPalette.green
                            .withValues(
                              alpha: .13,
                            )
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(
                              alpha: .08,
                            ),
                    borderRadius:
                        BorderRadius
                            .circular(99),
                  ),
                  child: Text(
                    item.active
                        ? 'Ativa'
                        : 'Pausada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w700,
                      color: item.active
                          ? AppPalette.green
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(
                                alpha: .55,
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções',
            onSelected: (value) {
              switch (value) {
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
            },
            itemBuilder:
                (context) => [
              if (item.active)
                PopupMenuItem(
                  value:
                      'realize',
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .check_circle_outline_rounded,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Text(
                        item.isIncome
                            ? 'Marcar como recebido'
                            : 'Marcar como pago',
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .edit_outlined,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text(
                      'Editar recorrência',
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      item.active
                          ? Icons
                              .pause_circle_outline_rounded
                          : Icons
                              .play_circle_outline_rounded,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Text(
                      item.active
                          ? 'Pausar'
                          : 'Reativar',
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .delete_outline_rounded,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text(
                      'Excluir recorrência',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState
    extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;

  final Future<void> Function()
      onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              'Não foi possível carregar os lançamentos.',
              textAlign:
                  TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              child: const Text(
                'Tentar novamente',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(
  DateTime date,
) {
  final day =
      date.day.toString().padLeft(
            2,
            '0',
          );

  final month =
      date.month.toString().padLeft(
            2,
            '0',
          );

  return '$day/$month/${date.year}';
}