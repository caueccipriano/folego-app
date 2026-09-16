import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/financial_display_text.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category_item.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../../shared/widgets/category_search_picker.dart';

class TransactionClassificationInbox extends StatefulWidget {
  const TransactionClassificationInbox({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.initialItems,
  });

  final FolegoRepository repository;
  final String spaceId;
  final List<TransactionItem> initialItems;

  @override
  State<TransactionClassificationInbox> createState() =>
      _TransactionClassificationInboxState();
}

class _TransactionClassificationInboxState
    extends State<TransactionClassificationInbox> {
  late List<TransactionItem> _items;
  List<CategoryItem> _expenseCategories = const [];
  List<CategoryItem> _incomeCategories = const [];
  String? _savingEventId;
  bool _loading = true;
  bool _refreshing = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = List<TransactionItem>.from(widget.initialItems);
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    try {
      final values = await Future.wait<dynamic>([
        widget.repository.listExpenseCategoryCatalog(widget.spaceId),
        widget.repository.listIncomeCategoryCatalog(widget.spaceId),
      ]);
      if (!mounted) return;
      setState(() {
        _expenseCategories = _selectable(values[0] as List<CategoryItem>);
        _incomeCategories = _selectable(values[1] as List<CategoryItem>);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(error);
      });
    }
  }

  List<CategoryItem> _selectable(List<CategoryItem> values) {
    return values
        .where(
          (item) =>
              item.active &&
              item.isSelectable &&
              (item.categoryRole == null || item.categoryRole == 'economic'),
        )
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final items = await widget.repository.listPendingTransactionClassifications(
        widget.spaceId,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _refreshing = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = _friendly(error);
      });
    }
  }

  Future<void> _chooseCategory(TransactionItem item) async {
    if (_savingEventId != null || _loading) return;
    final kind = transactionClassificationKind(item.eventType);
    if (kind == null) return;

    final categories = kind == 'income'
        ? _incomeCategories
        : _expenseCategories;
    if (categories.isEmpty) {
      setState(() => _error = 'Nenhuma categoria disponível para este lançamento.');
      return;
    }

    final selected = await _showCategoryPicker(
      categories: categories,
      selectedId: item.categoryId,
      eventType: kind,
    );
    if (selected == null || !mounted) return;

    setState(() {
      _savingEventId = item.id;
      _error = null;
    });

    try {
      await widget.repository.classifyFinancialEvent(
        spaceId: widget.spaceId,
        eventId: item.id,
        categoryId: selected.id,
      );
      if (!mounted) return;
      setState(() {
        _items.removeWhere((candidate) => candidate.id == item.id);
        _savingEventId = null;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Classificado em ${selected.breadcrumb}.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingEventId = null;
        _error = _friendly(error);
      });
    }
  }

  Future<CategoryItem?> _showCategoryPicker({
    required List<CategoryItem> categories,
    required String? selectedId,
    required String eventType,
  }) {
    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
    if (!compact) {
      return showDialog<CategoryItem>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: AppContentWidths.form,
            height: MediaQuery.sizeOf(context).height * .8,
            child: CategorySearchPicker(
              categories: categories,
              selectedId: selectedId,
              eventType: eventType,
              dialogMode: true,
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<CategoryItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .86,
        child: CategorySearchPicker(
          categories: categories,
          selectedId: selectedId,
          eventType: eventType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Material(
      color: background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Classificar lançamentos',
                          style: AppTypography.section(
                            context,
                            fontSize: 21,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _items.isEmpty
                              ? 'Tudo em dia por aqui.'
                              : '${_items.length} pendente${_items.length == 1 ? '' : 's'} • escolha categoria e subcategoria',
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(AppIcons.refresh, color: secondaryText),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(_changed),
                    icon: Icon(AppIcons.close, color: secondaryText),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: purple.withValues(alpha: .25)),
                ),
                child: Text(
                  _error!,
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: primaryText,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? _EmptyClassificationState(
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      purple: purple,
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _ClassificationCard(
                            item: item,
                            saving: _savingEventId == item.id,
                            onTap: () => _chooseCategory(item),
                          );
                        },
                      ),
                    ),
            ),
            if (_items.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Text(
                  'Classificar não altera valor, data, saldo ou parcela. A planilha recebe a categoria no próximo ciclo de sincronização.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('classification_failed')) {
      return 'Não foi possível concluir a classificação.';
    }
    if (text.contains('event_not_classifiable')) {
      return 'Esse tipo de lançamento não usa categoria econômica.';
    }
    if (text.contains('category_kind_mismatch')) {
      return 'Essa categoria não corresponde ao tipo do lançamento.';
    }
    if (text.contains('category_not_selectable')) {
      return 'Escolha uma categoria ativa e selecionável.';
    }
    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }
}

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({
    required this.item,
    required this.saving,
    required this.onTap,
  });

  final TransactionItem item;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final kind = transactionClassificationKind(item.eventType);
    final positive = kind == 'income';
    final amountColor = positive
        ? AppColors.positiveText(brightness)
        : AppColors.expenseText(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  AppIcons.categoryUnclassified,
                  size: 21,
                  color: purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            financialDisplayDescription(item.description),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              context,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${positive ? '+' : '−'} ${Formatters.money(item.amount.abs())}',
                          style: AppTypography.body(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _MetaText(_eventLabel(item.eventType)),
                        _MetaText(_date(item.occurredAt)),
                        if (item.accountName != null &&
                            item.accountName!.trim().isNotEmpty)
                          _MetaText(item.accountName!),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          'Escolher categoria',
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: purple,
                          ),
                        ),
                        const Spacer(),
                        if (saving)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            AppIcons.chevronRight,
                            size: 17,
                            color: secondaryText,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _eventLabel(String eventType) {
    switch (eventType) {
      case 'income':
        return 'Entrada';
      case 'benefit_credit':
        return 'Crédito de benefício';
      case 'reimbursement':
        return 'Reembolso';
      case 'card_purchase':
        return 'Cartão';
      case 'benefit_expense':
        return 'Benefício';
      case 'refund':
        return 'Estorno';
      case 'debt_payment':
        return 'Dívida';
      default:
        return 'Saída';
    }
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.secondaryText(Theme.of(context).brightness);
    return Text(
      text,
      style: AppTypography.label(context, fontSize: 9, color: color),
    );
  }
}

class _EmptyClassificationState extends StatelessWidget {
  const _EmptyClassificationState({
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.purple,
  });

  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color purple;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(AppIcons.check, color: purple, size: 25),
              ),
              const SizedBox(height: 14),
              Text(
                'Tudo classificado',
                style: AppTypography.section(
                  context,
                  fontSize: 18,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Quando a planilha enviar um lançamento sem categoria, ele aparece aqui para você decidir.',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
