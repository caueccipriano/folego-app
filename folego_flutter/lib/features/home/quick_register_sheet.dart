import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
    this.initialType = 'expense',
  }) : assert(
          initialType == 'expense' || initialType == 'income',
          'initialType deve ser expense ou income',
        );

  final FinancialSpace space;
  final FolegoRepository repository;

  /// Tipo já definido pela ação que abriu o formulário.
  ///
  /// expense = gasto
  /// income = receita
  final String initialType;

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

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isExpense => widget.initialType == 'expense';
  bool get _isIncome => widget.initialType == 'income';

  String get _title {
    if (_isExpense) {
      return 'novo gasto';
    }

    return 'nova receita';
  }

  String get _descriptionHint {
    if (_isExpense) {
      return 'Ex.: Restaurante';
    }

    return 'Ex.: Salário';
  }

  String get _buttonLabel {
    if (_isExpense) {
      return 'Registrar gasto';
    }

    return 'Registrar receita';
  }

  IconData get _headerIcon {
    if (_isExpense) {
      return Icons.receipt_long_rounded;
    }

    return Icons.add_rounded;
  }

  Color _accentColor(BuildContext context) {
    if (_isExpense) {
      return AppPalette.lime;
    }

    return AppPalette.purple;
  }

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

      if (!mounted) {
        return;
      }

      final accounts = values[0] as List<AccountItem>;
      final categories = values[1] as List<CategoryItem>;

      setState(() {
        _accounts = accounts;
        _categories = categories;

        _accountId = accounts.isEmpty
            ? null
            : accounts.first.id;

        _categoryId = categories.isEmpty
            ? null
            : categories.first.id;

        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    final amount =
        Formatters.parseMoney(_amount.text);

    if (_accountId == null ||
        amount <= 0 ||
        _description.text.trim().isEmpty) {
      setState(() {
        _error =
            'Informe descrição, valor e conta.';
      });

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isExpense) {
        await widget.repository.registerExpense(
          spaceId: widget.space.id,
          accountId: _accountId!,
          amount: amount,
          description:
              _description.text.trim(),
          categoryId: _categoryId,
        );
      } else if (_isIncome) {
        await widget.repository.registerIncome(
          spaceId: widget.space.id,
          accountId: _accountId!,
          amount: amount,
          description:
              _description.text.trim(),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final accent =
        _accentColor(context);

    final iconBackground = _isExpense
        ? AppPalette.lime
        : AppPalette.purple;

    final iconForeground = _isExpense
        ? const Color(0xFF111111)
        : Colors.white;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom:
              MediaQuery.viewInsetsOf(context)
                      .bottom +
                  20,
        ),
        child: _loading
            ? const SizedBox(
                height: 220,
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration:
                            BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                          borderRadius:
                              BorderRadius
                                  .circular(99),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration:
                              BoxDecoration(
                            color:
                                iconBackground,
                            borderRadius:
                                BorderRadius
                                    .circular(17),
                          ),
                          child: Icon(
                            _headerIcon,
                            color:
                                iconForeground,
                            size: 27,
                          ),
                        ),

                        const SizedBox(
                          width: 14,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                _title,
                                style: Theme.of(
                                  context,
                                )
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              Text(
                                _isExpense
                                    ? 'registre uma saída'
                                    : 'registre uma entrada',
                                style: Theme.of(
                                  context,
                                )
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      )
                                          .colorScheme
                                          .onSurface
                                          .withValues(
                                            alpha:
                                                .58,
                                          ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    TextField(
                      controller: _description,
                      autofocus: false,
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          InputDecoration(
                        labelText: 'Descrição',
                        hintText:
                            _descriptionHint,
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction:
                          TextInputAction.next,
                      decoration:
                          const InputDecoration(
                        labelText: 'Valor',
                        prefixText: 'R\$ ',
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<
                        String>(
                      initialValue: _accountId,
                      decoration:
                          const InputDecoration(
                        labelText: 'Conta',
                      ),
                      items: _accounts
                          .map(
                            (item) =>
                                DropdownMenuItem<
                                    String>(
                              value: item.id,
                              child:
                                  Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _accountId = value;
                        });
                      },
                    ),

                    if (_isExpense) ...[
                      const SizedBox(height: 12),

                      DropdownButtonFormField<
                          String>(
                        initialValue:
                            _categoryId,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Categoria',
                        ),
                        items: _categories
                            .map(
                              (item) =>
                                  DropdownMenuItem<
                                      String>(
                                value: item.id,
                                child: Text(
                                  item.name,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _categoryId =
                                value;
                          });
                        },
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 12),

                      Container(
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(
                                alpha: isDark
                                    ? .24
                                    : .65,
                              ),
                          borderRadius:
                              BorderRadius
                                  .circular(14),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .error,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    FilledButton(
                      onPressed:
                          _saving ? null : _save,
                      style:
                          FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor:
                            _isExpense
                                ? const Color(
                                    0xFF111111,
                                  )
                                : Colors.white,
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _isExpense
                                    ? const Color(
                                        0xFF111111,
                                      )
                                    : Colors
                                        .white,
                              ),
                            )
                          : Text(_buttonLabel),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}