import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/transaction_detail.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../data/repositories/folego_repository_payment_instruments.dart';
import '../../data/repositories/folego_repository_transaction_actions.dart';
import '../../shared/widgets/category_search_picker.dart';
import '../../shared/widgets/app_loading_state.dart';

class CardPurchaseEditSheet extends StatefulWidget {
  const CardPurchaseEditSheet({super.key, required this.repository, required this.detail});
  final FolegoRepository repository;
  final TransactionDetail detail;

  @override
  State<CardPurchaseEditSheet> createState() => _CardPurchaseEditSheetState();
}

class _CardPurchaseEditSheetState extends State<CardPurchaseEditSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _merchant;
  List<CategoryItem> _categories = const [];
  String? _categoryId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _financialEditable => widget.detail.cardPurchaseFinancialEditable;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.detail.amount.toStringAsFixed(2).replaceAll('.', ','));
    _description = TextEditingController(text: widget.detail.description);
    _merchant = TextEditingController(text: widget.detail.cardMerchant ?? '');
    _categoryId = widget.detail.categoryId;
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _merchant.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.listExpenseCategoryCatalog(widget.detail.spaceId);
      if (!mounted) return;
      setState(() {
        _categories = items.where((e) => e.isSelectable).toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = _friendly(error); });
    }
  }

  Future<void> _pickCategory() async {
    if (!_financialEditable || _categories.isEmpty) return;
    final dialog = AppBreakpoints.of(context) != AppLayoutSize.compact;
    final selected = dialog
        ? await showDialog<CategoryItem>(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: AppContentWidths.form,
                height: MediaQuery.sizeOf(context).height * .8,
                child: CategorySearchPicker(categories: _categories, selectedId: _categoryId, eventType: 'expense', dialogMode: true),
              ),
            ),
          )
        : await showModalBottomSheet<CategoryItem>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => FractionallySizedBox(
              heightFactor: .84,
              child: CategorySearchPicker(categories: _categories, selectedId: _categoryId, eventType: 'expense'),
            ),
          );
    if (selected != null && mounted) setState(() => _categoryId = selected.id);
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = _money(_amount.text);
    if (amount == null || amount <= 0 || _description.text.trim().isEmpty) {
      setState(() => _error = 'preencha valor e descrição corretamente.');
      return;
    }
    final cardId = widget.detail.cardId;
    final purchaseAt = widget.detail.cardPurchaseAt;
    if (cardId == null || purchaseAt == null) {
      setState(() => _error = 'o backing desta compra está incompleto.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.repository.updateCardPurchase(
        spaceId: widget.detail.spaceId,
        eventId: widget.detail.id,
        totalAmount: amount,
        description: _description.text.trim(),
        categoryId: _categoryId,
        merchant: _merchant.text,
        cardId: cardId,
        purchaseAt: purchaseAt,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() { _saving = false; _error = _friendly(error); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final restriction = widget.detail.cardPurchaseRestriction;
    return _ActionSheetFrame(
      title: 'editar compra no cartão',
      saving: _saving,
      error: _error,
      onSave: _loading ? null : _save,
      children: [
        if (_loading) const AppLoadingState(label: 'carregando dados') else ...[
          TextField(
            controller: _amount,
            enabled: _financialEditable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'valor', prefixText: 'R\$ '),
          ),
          const SizedBox(height: 12),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'descrição')),
          const SizedBox(height: 12),
          TextField(controller: _merchant, decoration: const InputDecoration(labelText: 'estabelecimento', hintText: 'opcional')),
          const SizedBox(height: 12),
          InkWell(
            onTap: _financialEditable ? _pickCategory : null,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'categoria'),
              child: Text(_categoryLabel()),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'cartão'),
            child: Text(widget.detail.cardName ?? 'cartão não identificado'),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'data da compra'),
            child: Text(_date(widget.detail.cardPurchaseAt)),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'parcelas'),
            child: Text('${widget.detail.cardInstallmentsCount ?? 1}x · estrutura preservada'),
          ),
          if (!_financialEditable && restriction != null) ...[
            const SizedBox(height: 12),
            _InfoBox(restriction),
          ] else ...[
            const SizedBox(height: 12),
            const _InfoBox('cartão, data e quantidade de parcelas ficam protegidos para não reescrever faturas já estruturadas.'),
          ],
        ],
      ],
    );
  }

  String _categoryLabel() {
    for (final item in _categories) {
      if (item.id == _categoryId) return item.breadcrumb;
    }
    return widget.detail.categoryName ?? 'sem categoria';
  }
}

class BenefitExpenseEditSheet extends StatefulWidget {
  const BenefitExpenseEditSheet({super.key, required this.repository, required this.detail});
  final FolegoRepository repository;
  final TransactionDetail detail;

  @override
  State<BenefitExpenseEditSheet> createState() => _BenefitExpenseEditSheetState();
}

class _BenefitExpenseEditSheetState extends State<BenefitExpenseEditSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _description;
  List<AccountItem> _benefits = const [];
  List<CategoryItem> _categories = const [];
  String? _benefitId;
  String? _categoryId;
  late DateTime _dateValue;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.detail.amount.toStringAsFixed(2).replaceAll('.', ','));
    _description = TextEditingController(text: widget.detail.description);
    _benefitId = widget.detail.benefitAccountId;
    _categoryId = widget.detail.categoryId;
    _dateValue = widget.detail.occurredAt;
    _load();
  }

  @override
  void dispose() { _amount.dispose(); _description.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final values = await Future.wait<dynamic>([
        widget.repository.listBenefitAccounts(widget.detail.spaceId),
        widget.repository.listExpenseCategoryCatalog(widget.detail.spaceId),
      ]);
      if (!mounted) return;
      setState(() {
        _benefits = values[0] as List<AccountItem>;
        _categories = (values[1] as List<CategoryItem>).where((e) => e.isSelectable).toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = _friendly(error); });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(context: context, initialDate: _dateValue, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (selected == null || !mounted) return;
    setState(() => _dateValue = DateTime(selected.year, selected.month, selected.day, _dateValue.hour, _dateValue.minute));
  }

  Future<void> _pickCategory() async {
    final dialog = AppBreakpoints.of(context) != AppLayoutSize.compact;
    final selected = dialog
        ? await showDialog<CategoryItem>(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: SizedBox(width: AppContentWidths.form, height: MediaQuery.sizeOf(context).height*.8, child: CategorySearchPicker(categories: _categories, selectedId: _categoryId, eventType: 'expense', dialogMode: true))))
        : await showModalBottomSheet<CategoryItem>(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: (_) => FractionallySizedBox(heightFactor: .84, child: CategorySearchPicker(categories: _categories, selectedId: _categoryId, eventType: 'expense')));
    if (selected != null && mounted) setState(() => _categoryId = selected.id);
  }

  Future<void> _save() async {
    final value = _money(_amount.text);
    if (_saving || value == null || value <= 0 || _benefitId == null || _description.text.trim().isEmpty) {
      if (!_saving) setState(() => _error = 'preencha os campos obrigatórios.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.repository.updateBenefitExpense(
        spaceId: widget.detail.spaceId,
        eventId: widget.detail.id,
        accountId: _benefitId!,
        amount: value,
        description: _description.text.trim(),
        categoryId: _categoryId,
        occurredAt: _dateValue,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() { _saving = false; _error = _friendly(error); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ActionSheetFrame(
      title: 'editar gasto com benefício', saving: _saving, error: _error, onSave: _loading ? null : _save,
      children: [
        if (_loading) const AppLoadingState(label: 'carregando dados') else ...[
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'valor', prefixText: 'R\$ ')),
          const SizedBox(height: 12),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'descrição')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _benefits.any((e) => e.id == _benefitId) ? _benefitId : null,
            decoration: const InputDecoration(labelText: 'benefício'),
            items: _benefits.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
            onChanged: (value) => setState(() => _benefitId = value),
          ),
          const SizedBox(height: 12),
          InkWell(onTap: _pickCategory, child: InputDecorator(decoration: const InputDecoration(labelText: 'categoria'), child: Text(_benefitCategoryLabel()))),
          const SizedBox(height: 12),
          InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'data'), child: Text(_date(_dateValue)))),
          const SizedBox(height: 12),
          const _InfoBox('benefício, resultado econômico e orçamento são atualizados juntos. caixa continua em zero.'),
        ],
      ],
    );
  }

  String _benefitCategoryLabel() {
    for (final item in _categories) { if (item.id == _categoryId) return item.breadcrumb; }
    return widget.detail.categoryName ?? 'sem categoria';
  }
}

class TransferEditSheet extends StatefulWidget {
  const TransferEditSheet({super.key, required this.repository, required this.detail});
  final FolegoRepository repository;
  final TransactionDetail detail;

  @override
  State<TransferEditSheet> createState() => _TransferEditSheetState();
}

class _TransferEditSheetState extends State<TransferEditSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _description;
  List<AccountItem> _accounts = const [];
  String? _sourceId;
  String? _destinationId;
  late DateTime _dateValue;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.detail.amount.toStringAsFixed(2).replaceAll('.', ','));
    _description = TextEditingController(text: widget.detail.description);
    _sourceId = widget.detail.sourceAccountId;
    _destinationId = widget.detail.destinationAccountId;
    _dateValue = widget.detail.occurredAt;
    _load();
  }

  @override
  void dispose() { _amount.dispose(); _description.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final values = await widget.repository.listPaymentAccounts(widget.detail.spaceId);
      if (!mounted) return;
      setState(() { _accounts = values; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = _friendly(error); });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(context: context, initialDate: _dateValue, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (selected == null || !mounted) return;
    setState(() => _dateValue = DateTime(selected.year, selected.month, selected.day, _dateValue.hour, _dateValue.minute));
  }

  Future<void> _save() async {
    final value = _money(_amount.text);
    if (_saving || value == null || value <= 0 || _sourceId == null || _destinationId == null || _description.text.trim().isEmpty) {
      if (!_saving) setState(() => _error = 'preencha os campos obrigatórios.');
      return;
    }
    if (_sourceId == _destinationId) {
      setState(() => _error = 'origem e destino precisam ser contas diferentes.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.repository.updateTransferTransaction(
        spaceId: widget.detail.spaceId,
        eventId: widget.detail.id,
        sourceAccountId: _sourceId!,
        destinationAccountId: _destinationId!,
        amount: value,
        description: _description.text.trim(),
        occurredAt: _dateValue,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() { _saving = false; _error = _friendly(error); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ActionSheetFrame(
      title: 'editar transferência', saving: _saving, error: _error, onSave: _loading ? null : _save,
      children: [
        if (_loading) const AppLoadingState(label: 'carregando dados') else ...[
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'valor', prefixText: 'R\$ ')),
          const SizedBox(height: 12),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'descrição')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _accounts.any((e) => e.id == _sourceId) ? _sourceId : null,
            decoration: const InputDecoration(labelText: 'conta de origem'),
            items: _accounts.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
            onChanged: (value) => setState(() => _sourceId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _accounts.any((e) => e.id == _destinationId) ? _destinationId : null,
            decoration: const InputDecoration(labelText: 'conta de destino'),
            items: _accounts.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
            onChanged: (value) => setState(() => _destinationId = value),
          ),
          const SizedBox(height: 12),
          InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'data'), child: Text(_date(_dateValue)))),
          const SizedBox(height: 12),
          const _InfoBox('a transferência continua neutra: sai de uma conta e entra na outra, sem impacto econômico ou de orçamento.'),
        ],
      ],
    );
  }
}

class _ActionSheetFrame extends StatelessWidget {
  const _ActionSheetFrame({required this.title, required this.saving, required this.error, required this.onSave, required this.children});
  final String title;
  final bool saving;
  final String? error;
  final VoidCallback? onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppContentWidths.form),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTypography.section(context, fontSize: 20, color: AppColors.primaryText(brightness))),
                const SizedBox(height: 20),
                ...children,
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: AppTypography.body(context, fontSize: 11, color: AppColors.expenseText(brightness))),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('salvar alterações'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background(brightness),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Text(text, style: AppTypography.body(context, fontSize: 10, color: AppColors.secondaryText(brightness))),
    );
  }
}

double? _money(String value) {
  var normalized = value.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (normalized.contains(',')) normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalized);
}

String _date(DateTime? value) {
  if (value == null) return 'não disponível';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _friendly(Object error) => error.toString().replaceFirst('Exception: ', '').replaceFirst('PostgrestException(message: ', '');
