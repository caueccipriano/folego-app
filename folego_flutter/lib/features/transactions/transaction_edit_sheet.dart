import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../data/repositories/folego_repository_payment_instruments.dart';
import '../../shared/widgets/category_icon_badge.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/category_search_picker.dart';

class TransactionEditSheet extends StatefulWidget {
  const TransactionEditSheet({
    super.key,
    required this.space,
    required this.repository,
    required this.transaction,
  });

  final FinancialSpace space;
  final FolegoRepository repository;
  final TransactionItem transaction;

  @override
  State<TransactionEditSheet> createState() => _TransactionEditSheetState();
}

class _TransactionEditSheetState extends State<TransactionEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  List<AccountItem> _accounts = const [];
  List<CategoryItem> _categories = const [];
  String? _selectedAccountId;
  String? _selectedCategoryId;
  late DateTime _occurredAt;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isIncome => widget.transaction.eventType == 'income';

  CategoryItem? get _selectedCategory {
    final id = _selectedCategoryId;
    if (id == null) return null;
    for (final item in _categories) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.abs().toStringAsFixed(2).replaceAll('.', ','),
    );
    _descriptionController = TextEditingController(
      text: widget.transaction.description,
    );
    _occurredAt = widget.transaction.occurredAt;
    _loadChoices();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadChoices() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.repository.listPaymentAccounts(widget.space.id),
        _isIncome
            ? widget.repository.listIncomeCategoryCatalog(widget.space.id)
            : widget.repository.listExpenseCategoryCatalog(widget.space.id),
      ]);
      if (!mounted) return;

      final accounts = results[0] as List<AccountItem>;
      final categories = (results[1] as List<CategoryItem>)
          .where((category) => category.isSelectable)
          .toList();

      var accountId = widget.transaction.accountId;
      if (accountId != null && !accounts.any((item) => item.id == accountId)) {
        accountId = null;
      }

      var categoryId = widget.transaction.categoryId;
      if (categoryId != null && !categories.any((item) => item.id == categoryId)) {
        categoryId = null;
      }

      setState(() {
        _accounts = accounts;
        _categories = categories;
        _selectedAccountId = accountId;
        _selectedCategoryId = categoryId;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _pickCategory() async {
    if (_categories.isEmpty) return;
    final dialogMode = AppBreakpoints.of(context) != AppLayoutSize.compact;
    final selected = dialogMode
        ? await showDialog<CategoryItem>(
            context: context,
            builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: AppContentWidths.form,
                height: MediaQuery.sizeOf(dialogContext).height * .80,
                child: CategorySearchPicker(
                  categories: _categories,
                  selectedId: _selectedCategoryId,
                  eventType: _isIncome ? 'income' : 'expense',
                  dialogMode: true,
                ),
              ),
            ),
          )
        : await showModalBottomSheet<CategoryItem>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => FractionallySizedBox(
              heightFactor: .84,
              child: CategorySearchPicker(
                categories: _categories,
                selectedId: _selectedCategoryId,
                eventType: _isIncome ? 'income' : 'expense',
              ),
            ),
          );

    if (selected != null && mounted) {
      setState(() => _selectedCategoryId = selected.id);
    }
  }

  double? _parseMoney(String text) {
    var normalized = text.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (normalized.isEmpty) return null;
    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'data do lançamento',
      cancelText: 'cancelar',
      confirmText: 'selecionar',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _occurredAt.hour,
        _occurredAt.minute,
        _occurredAt.second,
        _occurredAt.millisecond,
        _occurredAt.microsecond,
      );
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final accountId = _selectedAccountId;
    final amount = _parseMoney(_amountController.text);
    if (accountId == null || amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      await widget.repository.updateSimpleTransaction(
        spaceId: widget.space.id,
        eventId: widget.transaction.id,
        accountId: accountId,
        amount: amount.abs(),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        occurredAt: _occurredAt,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final category = _selectedCategory;
    final visual = CategoryVisuals.resolve(
      brightness: brightness,
      category: category?.parentName ?? category?.name,
      subcategory: category?.parentName == null ? null : category?.name,
      eventType: _isIncome ? 'income' : 'expense',
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppContentWidths.form),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'editar lançamento',
                    style: AppTypography.section(
                      context,
                      fontSize: 20,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isIncome ? 'ajuste os dados desta receita' : 'ajuste os dados deste gasto',
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const AppLoadingState(label: 'carregando dados do lançamento')
                  else if (_error != null)
                    AppErrorState(
                      title: 'não consegui carregar os dados para edição',
                      description: _error,
                      onRetry: () async {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        await _loadChoices();
                      },
                    )
                  else ...[
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'valor', prefixText: 'R\$ '),
                      validator: (value) {
                        final amount = _parseMoney(value ?? '');
                        return amount == null || amount <= 0 ? 'digite um valor válido' : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'descrição'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'digite uma descrição'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAccountId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'conta'),
                      items: _accounts
                          .map(
                            (account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(account.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _selectedAccountId = value),
                      validator: (value) => value == null ? 'escolha uma conta' : null,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickCategory,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'categoria'),
                        child: Row(
                          children: [
                            CategoryIconBadge(
                              icon: visual.icon,
                              color: visual.color,
                              size: 34,
                              iconSize: 17,
                              radius: 10,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                category?.breadcrumb ?? 'sem categoria',
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(context, fontSize: 13),
                              ),
                            ),
                            Icon(AppIcons.search, size: 17, color: secondaryText),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'data'),
                        child: Text(
                          _formatDate(_occurredAt),
                          style: AppTypography.body(context, fontSize: 14, color: primaryText),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: AppColors.iconOnLime,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('salvar alterações'),
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


  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
