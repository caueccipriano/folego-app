import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';

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
  State<TransactionEditSheet> createState() =>
      _TransactionEditSheetState();
}

class _TransactionEditSheetState
    extends State<TransactionEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  List<AccountItem> _accounts = const [];
  List<CategoryItem> _categories = const [];

  String? _selectedAccountId;
  String _selectedParentCategoryId = '';
  String? _selectedSubcategoryId;

  late DateTime _occurredAt;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isIncome =>
      widget.transaction.eventType == 'income';

  List<CategoryItem> get _parentCategories {
    final result = _categories
        .where(
          (category) => category.parentId == null,
        )
        .toList();

    result.sort(
      (a, b) => _sortKey(a.name).compareTo(
        _sortKey(b.name),
      ),
    );

    return result;
  }

  List<CategoryItem> get _subcategories {
    if (_selectedParentCategoryId.isEmpty) {
      return const [];
    }

    final result = _categories
        .where(
          (category) =>
              category.parentId ==
              _selectedParentCategoryId,
        )
        .toList();

    result.sort(
      (a, b) => _sortKey(a.name).compareTo(
        _sortKey(b.name),
      ),
    );

    return result;
  }

  String? get _effectiveCategoryId {
    if (_selectedSubcategoryId != null) {
      return _selectedSubcategoryId;
    }

    if (_selectedParentCategoryId.isEmpty) {
      return null;
    }

    return _selectedParentCategoryId;
  }

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(
      text: widget.transaction.amount
          .abs()
          .toStringAsFixed(2)
          .replaceAll('.', ','),
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
      final results = await Future.wait([
        widget.repository.listAccounts(
          widget.space.id,
        ),
        _isIncome
            ? widget.repository.listIncomeCategories(
                widget.space.id,
              )
            : widget.repository.listExpenseCategories(
                widget.space.id,
              ),
      ]);

      if (!mounted) {
        return;
      }

      final accounts =
          results[0] as List<AccountItem>;

      final categories =
          results[1] as List<CategoryItem>;

      var selectedAccountId =
          widget.transaction.accountId;

      if (selectedAccountId != null &&
          !accounts.any(
            (account) =>
                account.id == selectedAccountId,
          )) {
        selectedAccountId = null;
      }

      var parentId = '';
      String? subcategoryId;

      final transactionCategoryId =
          widget.transaction.categoryId;

      if (transactionCategoryId != null) {
        final current = _findCategory(
          categories,
          transactionCategoryId,
        );

        if (current != null) {
          if (current.parentId == null) {
            parentId = current.id;
          } else {
            parentId = current.parentId!;
            subcategoryId = current.id;
          }
        } else if (widget
                .transaction.categoryParentId !=
            null) {
          parentId =
              widget.transaction.categoryParentId!;
          subcategoryId = transactionCategoryId;
        }
      }

      setState(() {
        _accounts = accounts;
        _categories = categories;
        _selectedAccountId = selectedAccountId;
        _selectedParentCategoryId = parentId;
        _selectedSubcategoryId = subcategoryId;
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

  CategoryItem? _findCategory(
    List<CategoryItem> categories,
    String id,
  ) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }

    return null;
  }

  double? _parseMoney(String text) {
    var normalized = text
        .trim()
        .replaceAll(
          RegExp(r'[^0-9,.\-]'),
          '',
        );

    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains(',')) {
      normalized = normalized
          .replaceAll('.', '')
          .replaceAll(',', '.');
    }

    return double.tryParse(normalized);
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Data do lançamento',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (selected == null || !mounted) {
      return;
    }

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
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final accountId = _selectedAccountId;

    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Escolha a conta do lançamento.',
          ),
        ),
      );

      return;
    }

    final amount = _parseMoney(
      _amountController.text,
    );

    if (amount == null || amount <= 0) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.updateSimpleTransaction(
        spaceId: widget.space.id,
        eventId: widget.transaction.id,
        accountId: accountId,
        amount: amount.abs(),
        description:
            _descriptionController.text.trim(),
        categoryId: _effectiveCategoryId,
        occurredAt: _occurredAt,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

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
    final brightness =
        Theme.of(context).brightness;

    final primaryText =
        AppColors.primaryText(brightness);

    final secondaryText =
        AppColors.secondaryText(brightness);

    final border = AppColors.border(brightness);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom +
              24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 560,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius:
                            BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Editar lançamento',
                    style: AppTypography.section(
                      context,
                      fontSize: 20,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isIncome
                        ? 'Ajuste os dados desta receita.'
                        : 'Ajuste os dados deste gasto.',
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 44,
                      ),
                      child: Center(
                        child:
                            CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    _buildError(
                      primaryText,
                      secondaryText,
                    )
                  else ...[
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText: 'Valor',
                        prefixText: 'R\$ ',
                      ),
                      validator: (value) {
                        final amount = _parseMoney(
                          value ?? '',
                        );

                        if (amount == null ||
                            amount <= 0) {
                          return 'Digite um valor válido.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller:
                          _descriptionController,
                      textCapitalization:
                          TextCapitalization.sentences,
                      decoration:
                          const InputDecoration(
                        labelText: 'Descrição',
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Digite uma descrição.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _selectedAccountId,
                      decoration:
                          const InputDecoration(
                        labelText: 'Conta',
                      ),
                      items: _accounts
                          .map(
                            (account) =>
                                DropdownMenuItem(
                              value: account.id,
                              child: Text(
                                account.name,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountId =
                              value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Escolha uma conta.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'parent-$_selectedParentCategoryId',
                      ),
                      initialValue:
                          _selectedParentCategoryId,
                      decoration:
                          const InputDecoration(
                        labelText: 'Categoria',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text(
                            'Sem categoria',
                          ),
                        ),
                        ..._parentCategories.map(
                          (category) =>
                              DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              category.name,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedParentCategoryId =
                              value ?? '';
                          _selectedSubcategoryId =
                              null;
                        });
                      },
                    ),
                    if (_subcategories.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        key: ValueKey(
                          'sub-$_selectedParentCategoryId-$_selectedSubcategoryId',
                        ),
                        initialValue:
                            _selectedSubcategoryId,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Subcategoria',
                        ),
                        items: [
                          const DropdownMenuItem<
                              String?>(
                            value: null,
                            child: Text(
                              'Sem subcategoria',
                            ),
                          ),
                          ..._subcategories.map(
                            (category) =>
                                DropdownMenuItem<
                                    String?>(
                              value: category.id,
                              child: Text(
                                category.name,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSubcategoryId =
                                value;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius:
                          BorderRadius.circular(16),
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(
                          labelText: 'Data',
                        ),
                        child: Text(
                          _formatDate(_occurredAt),
                          style: AppTypography.body(
                            context,
                            fontSize: 14,
                            color: primaryText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed:
                          _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            AppColors.lime,
                        foregroundColor:
                            AppColors.iconOnLime,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Salvar alterações',
                            ),
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

  Widget _buildError(
    Color primaryText,
    Color secondaryText,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Não consegui carregar os dados para edição.',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });

              _loadChoices();
            },
            child: const Text(
              'Tentar novamente',
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst(
          'Invalid argument(s): ',
          '',
        );
  }

  String _formatDate(DateTime date) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _sortKey(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }
}
