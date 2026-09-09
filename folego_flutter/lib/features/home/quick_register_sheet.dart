import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';

class QuickRegisterSheet extends StatefulWidget {
  const QuickRegisterSheet({
    super.key,
    required this.space,
    required this.repository,
  });

  final FinancialSpace space;
  final FolegoRepository repository;

  @override
  State<QuickRegisterSheet> createState() => _QuickRegisterSheetState();
}

class _QuickRegisterSheetState extends State<QuickRegisterSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();

  List<AccountItem> _accounts = const [];
  List<CategoryItem> _categories = const [];
  String? _accountId;
  String? _categoryId;
  String _type = 'expense';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.repository.listAccounts(widget.space.id),
        widget.repository.listExpenseCategories(widget.space.id),
      ]);
      if (!mounted) return;
      final accounts = values[0] as List<AccountItem>;
      final categories = values[1] as List<CategoryItem>;
      setState(() {
        _accounts = accounts;
        _categories = categories;
        _accountId = accounts.isEmpty ? null : accounts.first.id;
        _categoryId = categories.isEmpty ? null : categories.first.id;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _save() async {
    final amount = Formatters.parseMoney(_amount.text);
    if (_accountId == null || amount <= 0 || _description.text.trim().isEmpty) {
      setState(() => _error = 'Informe descrição, valor e conta.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_type == 'expense') {
        await widget.repository.registerExpense(
          spaceId: widget.space.id,
          accountId: _accountId!,
          amount: amount,
          description: _description.text.trim(),
          categoryId: _categoryId,
        );
      } else {
        await widget.repository.registerIncome(
          spaceId: widget.space.id,
          accountId: _accountId!,
          amount: amount,
          description: _description.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: _loading
            ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Registrar agora', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Despesa'),
                        selected: _type == 'expense',
                        onSelected: (_) => setState(() => _type = 'expense'),
                      ),
                      ChoiceChip(
                        label: const Text('Receita'),
                        selected: _type == 'income',
                        onSelected: (_) => setState(() => _type = 'income'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _description,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: Restaurante'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _accountId,
                    decoration: const InputDecoration(labelText: 'Conta'),
                    items: _accounts.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                    onChanged: (value) => setState(() => _accountId = value),
                  ),
                  if (_type == 'expense') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _categoryId,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: _categories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                      onChanged: (value) => setState(() => _categoryId = value),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Registrar'),
                  ),
                ],
              ),
      ),
    );
  }
}
