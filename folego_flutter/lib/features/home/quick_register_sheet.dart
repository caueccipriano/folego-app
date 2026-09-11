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
  final String initialType;

  @override
  State<QuickRegisterSheet> createState() =>
      _QuickRegisterSheetState();
}

class _QuickRegisterSheetState extends State<QuickRegisterSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();

  List<AccountItem> _accounts = const [];
  List<CategoryItem> _expenseCategories = const [];
  List<CategoryItem> _incomeCategories = const [];

  String? _accountId;
  String? _categoryId;

  String _repeat = 'once';

  DateTime _date = DateTime.now();

  int _dayOfMonth = DateTime.now().day;
  int _monthOfYear = DateTime.now().month;
  int _weekday = DateTime.now().weekday % 7;

  final Set<int> _monthlyDays = {};
  bool _monthlyLastDay = false;

  bool _loading = true;
  bool _saving = false;

  String? _error;

  bool get _isExpense =>
      widget.initialType == 'expense';

  bool get _isRecurring =>
      _repeat != 'once';

  List<CategoryItem> get _availableCategories =>
      _isExpense
          ? _expenseCategories
          : _incomeCategories;

  String get _title =>
      _isExpense
          ? 'novo gasto'
          : 'nova receita';

  String get _subtitle =>
      _isExpense
          ? 'registre uma saída'
          : 'registre uma entrada';

  String get _descriptionHint =>
      _isExpense
          ? 'Ex.: Restaurante'
          : 'Ex.: Salário';

  String get _buttonLabel {
    if (_isRecurring) {
      return _isExpense
          ? 'Salvar gasto recorrente'
          : 'Salvar receita recorrente';
    }

    return _isExpense
        ? 'Registrar gasto'
        : 'Registrar receita';
  }

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _date = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _dayOfMonth = _date.day;
    _monthOfYear = _date.month;
    _weekday = _postgresWeekday(_date);

    _monthlyDays.add(_date.day);

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
        widget.repository.listAccounts(
          widget.space.id,
        ),
        widget.repository.listExpenseCategories(
          widget.space.id,
        ),
        widget.repository.listIncomeCategories(
          widget.space.id,
        ),
      ]);

      if (!mounted) {
        return;
      }

      final accounts =
          values[0] as List<AccountItem>;

      final expenseCategories =
          values[1] as List<CategoryItem>;

      final incomeCategories =
          values[2] as List<CategoryItem>;

      _sortCategories(
        expenseCategories,
      );

      _sortCategories(
        incomeCategories,
      );

      final categories =
          _isExpense
              ? expenseCategories
              : incomeCategories;

      setState(() {
        _accounts = accounts;

        _expenseCategories =
            expenseCategories;

        _incomeCategories =
            incomeCategories;

        _accountId =
            accounts.isEmpty
                ? null
                : accounts.first.id;

        _categoryId =
            categories.isEmpty
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
        _error = _friendlyError(
          error,
        );
      });
    }
  }

  Future<void> _pickMonthlyDay() async {
    final selectedDay =
        await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            24,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Qual dia?',
                style:
                    Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w900,
                        ),
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                'Você pode adicionar mais de um dia.',
                style:
                    Theme.of(context)
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
              const SizedBox(
                height: 18,
              ),
              GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount: 31,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemBuilder:
                    (context, index) {
                  final day =
                      index + 1;

                  final selected =
                      _monthlyDays
                          .contains(day);

                  return InkWell(
                    onTap:
                        selected
                            ? null
                            : () {
                                Navigator.of(
                                  context,
                                ).pop(day);
                              },
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    child: Container(
                      alignment:
                          Alignment.center,
                      decoration:
                          BoxDecoration(
                        color:
                            selected
                                ? Theme.of(
                                    context,
                                  )
                                    .colorScheme
                                    .surfaceContainerHighest
                                : null,
                        border:
                            Border.all(
                          color:
                              selected
                                  ? AppPalette
                                      .purple
                                  : Theme.of(
                                      context,
                                    )
                                      .dividerColor,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Text(
                        '$day',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.w700,
                          color:
                              selected
                                  ? AppPalette
                                      .purple
                                  : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (selectedDay == null ||
        !mounted) {
      return;
    }

    setState(() {
      _monthlyDays.add(
        selectedDay,
      );

      final sorted =
          _monthlyDays.toList()
            ..sort();

      _dayOfMonth =
          sorted.first;
    });
  }

  Future<void> _pickDate() async {
    final selected =
        await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText:
          _isRecurring
              ? 'Quando começa?'
              : 'Data do lançamento',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _date = selected;

      if (_repeat == 'weekly' ||
          _repeat == 'biweekly') {
        _weekday =
            _postgresWeekday(
          selected,
        );
      }

      if (_repeat == 'monthly' &&
          _monthlyDays.isEmpty) {
        _monthlyDays.add(
          selected.day,
        );

        _dayOfMonth =
            selected.day;
      }

      if (_repeat == 'yearly') {
        _dayOfMonth =
            selected.day;

        _monthOfYear =
            selected.month;
      }
    });
  }

  void _changeRepeat(
    String value,
  ) {
    setState(() {
      _repeat = value;

      switch (value) {
        case 'weekly':
          _weekday =
              _postgresWeekday(
            _date,
          );

          break;

        case 'biweekly':
          _weekday =
              _postgresWeekday(
            _date,
          );

          break;

        case 'monthly':
          _dayOfMonth =
              _date.day;

          if (_monthlyDays.isEmpty) {
            _monthlyDays.add(
              _date.day,
            );
          }

          break;

        case 'yearly':
          _dayOfMonth =
              _date.day;

          _monthOfYear =
              _date.month;

          break;
      }

      _error = null;
    });
  }

  Future<void> _save() async {
    final amount =
        Formatters.parseMoney(
      _amount.text,
    );

    if (_description.text
        .trim()
        .isEmpty) {
      setState(() {
        _error =
            'Informe uma descrição.';
      });

      return;
    }

    if (amount <= 0) {
      setState(() {
        _error =
            'Informe um valor maior que zero.';
      });

      return;
    }

    if (_accountId == null) {
      setState(() {
        _error =
            'Selecione uma conta.';
      });

      return;
    }

    if (_categoryId == null) {
      setState(() {
        _error =
            _isExpense
                ? 'Selecione uma categoria de gasto.'
                : 'Selecione uma categoria de receita.';
      });

      return;
    }

    if (_repeat == 'monthly' &&
        _monthlyDays.isEmpty &&
        !_monthlyLastDay) {
      setState(() {
        _error =
            'Escolha pelo menos um dia do mês.';
      });

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (!_isRecurring) {
        await _registerOnce(
          amount,
        );
      } else {
        await _registerRecurring(
          amount,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(
          error,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _registerOnce(
    num amount,
  ) async {
    if (_isExpense) {
      await widget.repository
          .registerExpense(
        spaceId:
            widget.space.id,
        accountId:
            _accountId!,
        amount:
            amount,
        description:
            _description.text
                .trim(),
        categoryId:
            _categoryId,
        occurredAt:
            _date,
      );

      return;
    }

    await widget.repository
        .registerIncome(
      spaceId:
          widget.space.id,
      accountId:
          _accountId!,
      amount:
          amount,
      description:
          _description.text
              .trim(),
      categoryId:
          _categoryId,
      occurredAt:
          _date,
    );
  }

  Future<void> _registerRecurring(
    num amount,
  ) async {
    final dayOfMonth =
        _repeat == 'monthly' ||
                _repeat == 'yearly'
            ? _dayOfMonth
            : null;

    final weekday =
        _repeat == 'weekly' ||
                _repeat == 'biweekly'
            ? _weekday
            : null;

    final monthOfYear =
        _repeat == 'yearly'
            ? _monthOfYear
            : null;

    final monthlyDays =
        _repeat == 'monthly'
            ? (_monthlyDays.toList()
              ..sort())
            : null;

    await widget.repository
        .createRecurringItem(
      spaceId:
          widget.space.id,
      name:
          _description.text
              .trim(),
      itemType:
          widget.initialType,
      amount:
          amount,
      frequency:
          _repeat,
      accountId:
          _accountId!,
      categoryId:
          _categoryId,
      dayOfMonth:
          dayOfMonth,
      monthlyDays:
          monthlyDays,
      monthlyLastDay:
          _repeat == 'monthly'
              ? _monthlyLastDay
              : false,
      weekday:
          weekday,
      monthOfYear:
          monthOfYear,
      startsOn:
          _date,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final isDark =
        Theme.of(context)
                .brightness ==
            Brightness.dark;

    final iconBackground =
        _isExpense
            ? AppPalette.lime
            : isDark
                ? const Color(
                    0xFFF3F1EC,
                  )
                : const Color(
                    0xFF111111,
                  );

    final iconForeground =
        _isExpense
            ? const Color(
                0xFF111111,
              )
            : isDark
                ? const Color(
                    0xFF111111,
                  )
                : AppPalette.lime;

    final buttonBackground =
        _isExpense
            ? AppPalette.lime
            : isDark
                ? const Color(
                    0xFFF3F1EC,
                  )
                : const Color(
                    0xFF111111,
                  );

    final buttonForeground =
        _isExpense
            ? const Color(
                0xFF111111,
              )
            : isDark
                ? const Color(
                    0xFF111111,
                  )
                : AppPalette.lime;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(
                    context,
                  ).height *
                  .90,
        ),
        child: Padding(
          padding:
              EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom:
                MediaQuery.viewInsetsOf(
                      context,
                    ).bottom +
                    14,
          ),
          child:
              _loading
                  ? const SizedBox(
                      height: 300,
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
                                color:
                                    Theme.of(
                                  context,
                                )
                                        .colorScheme
                                        .outlineVariant,
                                borderRadius:
                                    BorderRadius.circular(
                                  99,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

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
                                      BorderRadius.circular(
                                    17,
                                  ),
                                ),
                                child:
                                    Icon(
                                  _isExpense
                                      ? Icons
                                          .receipt_long_rounded
                                      : Icons
                                          .payments_rounded,
                                  color:
                                      iconForeground,
                                  size: 27,
                                ),
                              ),

                              const SizedBox(
                                width: 14,
                              ),

                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      _title,
                                      style:
                                          Theme.of(
                                        context,
                                      )
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w900,
                                              ),
                                    ),
                                    const SizedBox(
                                      height: 2,
                                    ),
                                    Text(
                                      _subtitle,
                                      style:
                                          Theme.of(
                                        context,
                                      )
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color:
                                                    Theme.of(
                                                  context,
                                                )
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: .58,
                                                        ),
                                              ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          TextField(
                            controller:
                                _description,
                            textInputAction:
                                TextInputAction
                                    .next,
                            decoration:
                                InputDecoration(
                              labelText:
                                  'Descrição',
                              hintText:
                                  _descriptionHint,
                            ),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          TextField(
                            controller:
                                _amount,
                            keyboardType:
                                const TextInputType
                                    .numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction:
                                TextInputAction
                                    .next,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Valor',
                              prefixText:
                                  'R\$ ',
                            ),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          DropdownButtonFormField<
                              String>(
                            initialValue:
                                _accountId,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Conta',
                            ),
                            items:
                                _accounts
                                    .map(
                                      (
                                        account,
                                      ) =>
                                          DropdownMenuItem<
                                              String>(
                                        value:
                                            account.id,
                                        child:
                                            Text(
                                          account.name,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) {
                              setState(() {
                                _accountId =
                                    value;
                              });
                            },
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          DropdownButtonFormField<
                              String>(
                            initialValue:
                                _categoryId,
                            decoration:
                                InputDecoration(
                              labelText:
                                  _isExpense
                                      ? 'Categoria'
                                      : 'Categoria da receita',
                            ),
                            items:
                                _availableCategories
                                    .map(
                                      (
                                        category,
                                      ) =>
                                          DropdownMenuItem<
                                              String>(
                                        value:
                                            category.id,
                                        child:
                                            Text(
                                          category.name,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) {
                              setState(() {
                                _categoryId =
                                    value;
                              });
                            },
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          DropdownButtonFormField<
                              String>(
                            initialValue:
                                _repeat,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Repete?',
                            ),
                            items:
                                const [
                              DropdownMenuItem(
                                value:
                                    'once',
                                child:
                                    Text(
                                  'Uma vez',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'weekly',
                                child:
                                    Text(
                                  'Toda semana',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'biweekly',
                                child:
                                    Text(
                                  'A cada 2 semanas',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'monthly',
                                child:
                                    Text(
                                  'Todo mês',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'yearly',
                                child:
                                    Text(
                                  'Todo ano',
                                ),
                              ),
                            ],
                            onChanged:
                                (value) {
                              if (value ==
                                  null) {
                                return;
                              }

                              _changeRepeat(
                                value,
                              );
                            },
                          ),

                          if (_repeat ==
                              'weekly') ...[
                            const SizedBox(
                              height: 10,
                            ),
                            DropdownButtonFormField<
                                int>(
                              initialValue:
                                  _weekday,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Dia da semana',
                              ),
                              items:
                                  const [
                                DropdownMenuItem(
                                  value: 0,
                                  child:
                                      Text(
                                    'Domingo',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 1,
                                  child:
                                      Text(
                                    'Segunda-feira',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child:
                                      Text(
                                    'Terça-feira',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child:
                                      Text(
                                    'Quarta-feira',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 4,
                                  child:
                                      Text(
                                    'Quinta-feira',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 5,
                                  child:
                                      Text(
                                    'Sexta-feira',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 6,
                                  child:
                                      Text(
                                    'Sábado',
                                  ),
                                ),
                              ],
                              onChanged:
                                  (value) {
                                if (value !=
                                    null) {
                                  setState(
                                    () {
                                      _weekday =
                                          value;
                                    },
                                  );
                                }
                              },
                            ),
                          ],

                          if (_repeat ==
                              'biweekly') ...[
                            const SizedBox(
                              height: 10,
                            ),
                            _InfoBox(
                              icon:
                                  Icons
                                      .event_repeat_rounded,
                              text:
                                  'Repete a cada 14 dias a partir de ${_formatDate(_date)}.',
                            ),
                          ],

                          if (_repeat ==
                              'monthly') ...[
                            const SizedBox(
                              height: 14,
                            ),

                            Text(
                              'Dias do mês',
                              style:
                                  Theme.of(
                                context,
                              )
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...(
                                  _monthlyDays
                                      .toList()
                                    ..sort()
                                ).map(
                                  (
                                    day,
                                  ) =>
                                      InputChip(
                                    label:
                                        Text(
                                      'Dia $day',
                                    ),
                                    onDeleted:
                                        () {
                                      setState(
                                        () {
                                          _monthlyDays
                                              .remove(
                                            day,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),

                                FilterChip(
                                  label:
                                      const Text(
                                    'Último dia',
                                  ),
                                  selected:
                                      _monthlyLastDay,
                                  onSelected:
                                      (selected) {
                                    setState(
                                      () {
                                        _monthlyLastDay =
                                            selected;
                                      },
                                    );
                                  },
                                ),

                                ActionChip(
                                  avatar:
                                      const Icon(
                                    Icons
                                        .add_rounded,
                                    size: 18,
                                  ),
                                  label:
                                      const Text(
                                    'Outro dia',
                                  ),
                                  onPressed:
                                      _pickMonthlyDay,
                                ),
                              ],
                            ),

                            if (_monthlyDays
                                        .length +
                                    (_monthlyLastDay
                                        ? 1
                                        : 0) >
                                1) ...[
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                'O valor informado será considerado em cada uma dessas datas.',
                                style:
                                    Theme.of(
                                  context,
                                )
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              Theme.of(
                                            context,
                                          )
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(
                                                    alpha: .58,
                                                  ),
                                        ),
                              ),
                            ],
                          ],

                          if (_repeat ==
                              'yearly') ...[
                            const SizedBox(
                              height: 10,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                      DropdownButtonFormField<
                                          int>(
                                    initialValue:
                                        _dayOfMonth,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Dia',
                                    ),
                                    items:
                                        List.generate(
                                      31,
                                      (
                                        index,
                                      ) =>
                                          DropdownMenuItem<
                                              int>(
                                        value:
                                            index + 1,
                                        child:
                                            Text(
                                          '${index + 1}',
                                        ),
                                      ),
                                    ),
                                    onChanged:
                                        (value) {
                                      if (value !=
                                          null) {
                                        setState(
                                          () {
                                            _dayOfMonth =
                                                value;
                                          },
                                        );
                                      }
                                    },
                                  ),
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                Expanded(
                                  child:
                                      DropdownButtonFormField<
                                          int>(
                                    initialValue:
                                        _monthOfYear,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Mês',
                                    ),
                                    items:
                                        const [
                                      DropdownMenuItem(
                                        value:
                                            1,
                                        child:
                                            Text(
                                          'Janeiro',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            2,
                                        child:
                                            Text(
                                          'Fevereiro',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            3,
                                        child:
                                            Text(
                                          'Março',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            4,
                                        child:
                                            Text(
                                          'Abril',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            5,
                                        child:
                                            Text(
                                          'Maio',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            6,
                                        child:
                                            Text(
                                          'Junho',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            7,
                                        child:
                                            Text(
                                          'Julho',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            8,
                                        child:
                                            Text(
                                          'Agosto',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            9,
                                        child:
                                            Text(
                                          'Setembro',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            10,
                                        child:
                                            Text(
                                          'Outubro',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            11,
                                        child:
                                            Text(
                                          'Novembro',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value:
                                            12,
                                        child:
                                            Text(
                                          'Dezembro',
                                        ),
                                      ),
                                    ],
                                    onChanged:
                                        (value) {
                                      if (value !=
                                          null) {
                                        setState(
                                          () {
                                            _monthOfYear =
                                                value;
                                          },
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(
                            height: 10,
                          ),

                          _DateTile(
                            title:
                                _isRecurring
                                    ? 'Começa em'
                                    : 'Data',
                            value:
                                _formatDate(
                              _date,
                            ),
                            onTap:
                                _pickDate,
                          ),

                          if (_isRecurring) ...[
                            const SizedBox(
                              height: 10,
                            ),
                            _InfoBox(
                              icon:
                                  Icons
                                      .auto_awesome_rounded,
                              text:
                                  'O Fôlego considera as próximas ocorrências automaticamente.',
                            ),
                          ],

                          if (_error !=
                              null) ...[
                            const SizedBox(
                              height: 12,
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.all(
                                13,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Theme.of(
                                  context,
                                )
                                        .colorScheme
                                        .errorContainer
                                        .withValues(
                                          alpha:
                                              isDark
                                                  ? .25
                                                  : .65,
                                        ),
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                              ),
                              child:
                                  Text(
                                _error!,
                                style:
                                    TextStyle(
                                  color:
                                      Theme.of(
                                    context,
                                  )
                                          .colorScheme
                                          .error,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(
                            height: 18,
                          ),

                          FilledButton(
                            onPressed:
                                _saving
                                    ? null
                                    : _save,
                            style:
                                FilledButton.styleFrom(
                              backgroundColor:
                                  buttonBackground,
                              foregroundColor:
                                  buttonForeground,
                            ),
                            child:
                                _saving
                                    ? SizedBox(
                                        width:
                                            22,
                                        height:
                                            22,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                          color:
                                              buttonForeground,
                                        ),
                                      )
                                    : Text(
                                        _buttonLabel,
                                      ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  int _postgresWeekday(
    DateTime date,
  ) {
    return date.weekday % 7;
  }

  void _sortCategories(
    List<CategoryItem> categories,
  ) {
    categories.sort(
      (
        a,
        b,
      ) =>
          _sortKey(
        a.name,
      ).compareTo(
        _sortKey(
          b.name,
        ),
      ),
    );
  }

  String _sortKey(
    String value,
  ) {
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

  String _formatDate(
    DateTime date,
  ) {
    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year}';
  }

  String _friendlyError(
    Object error,
  ) {
    final text =
        error.toString();

    if (text.contains(
      'write_access_denied',
    )) {
      return 'Você não tem permissão para alterar esse espaço financeiro.';
    }

    if (text.contains(
      'amount_must_be_positive',
    )) {
      return 'O valor precisa ser maior que zero.';
    }

    return text
        .replaceFirst(
          'Invalid argument(s): ',
          '',
        )
        .replaceFirst(
          'Exception: ',
          '',
        );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Theme.of(context)
              .colorScheme
              .surface,
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          decoration:
              BoxDecoration(
            border: Border.all(
              color:
                  Theme.of(context)
                      .dividerColor,
            ),
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons
                    .calendar_today_outlined,
                size: 21,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          Theme.of(
                        context,
                      )
                              .textTheme
                              .bodySmall,
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      value,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons
                    .chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(
                  alpha: .42,
                ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
          ),
          const SizedBox(
            width: 11,
          ),
          Expanded(
            child: Text(
              text,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        height: 1.35,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}