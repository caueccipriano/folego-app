import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
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
  State<QuickRegisterSheet> createState() => _QuickRegisterSheetState();
}

class _QuickRegisterSheetState extends State<QuickRegisterSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();

  List<AccountItem> _accounts = const [];

  List<CategoryItem> _expenseCategories = const [];
  List<CategoryItem> _incomeCategories = const [];

  String? _accountId;

  String? _expenseParentCategoryId;
  String? _expenseSubcategoryId;

  String? _incomeCategoryId;

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

  bool get _isExpense => widget.initialType == 'expense';

  bool get _isRecurring => _repeat != 'once';

  String get _title => _isExpense ? 'novo gasto' : 'nova receita';

  String get _subtitle =>
      _isExpense ? 'registre uma saída' : 'registre uma entrada';

  String get _descriptionHint =>
      _isExpense ? 'Ex.: Jantar com amigos' : 'Ex.: Salário';

  String get _buttonLabel {
    if (_isRecurring) {
      return _isExpense
          ? 'Salvar gasto recorrente'
          : 'Salvar receita recorrente';
    }

    return _isExpense ? 'Registrar gasto' : 'Registrar receita';
  }

  String? get _effectiveCategoryId {
    if (_isExpense) {
      return _expenseSubcategoryId ?? _expenseParentCategoryId;
    }

    return _incomeCategoryId;
  }

  List<CategoryItem> get _expenseParentCategories {
    final result = _expenseCategories
        .where((category) => category.isParent)
        .toList();

    _sortCategories(result);

    return result;
  }

  List<CategoryItem> get _selectedExpenseSubcategories {
    final parentId = _expenseParentCategoryId;

    if (parentId == null) {
      return const [];
    }

    final result = _expenseCategories
        .where((category) => category.parentId == parentId)
        .toList();

    _sortCategories(result);

    return result;
  }

  CategoryItem? get _selectedExpenseParent {
    return _findCategory(_expenseCategories, _expenseParentCategoryId);
  }

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _date = DateTime(now.year, now.month, now.day);

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
        widget.repository.listAccounts(widget.space.id),
        widget.repository.listExpenseCategories(widget.space.id),
        widget.repository.listIncomeCategories(widget.space.id),
      ]);

      if (!mounted) {
        return;
      }

      final accounts = values[0] as List<AccountItem>;

      final expenseCategories = values[1] as List<CategoryItem>;

      final incomeCategories = values[2] as List<CategoryItem>;

      _sortCategories(expenseCategories);
      _sortCategories(incomeCategories);

      final expenseParents = expenseCategories
          .where((category) => category.isParent)
          .toList();

      _sortCategories(expenseParents);

      setState(() {
        _accounts = accounts;

        _expenseCategories = expenseCategories;
        _incomeCategories = incomeCategories;

        _accountId = accounts.isEmpty ? null : accounts.first.id;

        _expenseParentCategoryId = expenseParents.isEmpty
            ? null
            : expenseParents.first.id;

        _expenseSubcategoryId = null;

        _incomeCategoryId = incomeCategories.isEmpty
            ? null
            : incomeCategories.first.id;

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

  Future<void> _pickMonthlyDay() async {
    final selectedDay = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        final primaryText = AppColors.primaryText(Theme.of(context).brightness);

        final secondaryText = AppColors.secondaryText(
          Theme.of(context).brightness,
        );

        final border = AppColors.border(Theme.of(context).brightness);

        final purple = AppColors.primaryPurple(Theme.of(context).brightness);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qual dia?',
                style: AppTypography.section(
                  context,
                  fontSize: 20,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Você pode adicionar mais de um dia.',
                style: AppTypography.body(
                  context,
                  fontSize: 13,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 31,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  final day = index + 1;

                  final selected = _monthlyDays.contains(day);

                  return InkWell(
                    onTap: selected
                        ? null
                        : () {
                            Navigator.of(context).pop(day);
                          },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? purple.withValues(alpha: .12) : null,
                        border: Border.all(color: selected ? purple : border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '$day',
                        style: AppTypography.label(
                          context,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? purple : primaryText,
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

    if (selectedDay == null || !mounted) {
      return;
    }

    setState(() {
      _monthlyDays.add(selectedDay);

      final sorted = _monthlyDays.toList()..sort();

      _dayOfMonth = sorted.first;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: _isRecurring ? 'Quando começa?' : 'Data do lançamento',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _date = selected;

      if (_repeat == 'weekly' || _repeat == 'biweekly') {
        _weekday = _postgresWeekday(selected);
      }

      if (_repeat == 'monthly' && _monthlyDays.isEmpty) {
        _monthlyDays.add(selected.day);

        _dayOfMonth = selected.day;
      }

      if (_repeat == 'yearly') {
        _dayOfMonth = selected.day;
        _monthOfYear = selected.month;
      }
    });
  }

  void _changeRepeat(String value) {
    setState(() {
      _repeat = value;

      switch (value) {
        case 'weekly':
        case 'biweekly':
          _weekday = _postgresWeekday(_date);

          break;

        case 'monthly':
          _dayOfMonth = _date.day;

          if (_monthlyDays.isEmpty) {
            _monthlyDays.add(_date.day);
          }

          break;

        case 'yearly':
          _dayOfMonth = _date.day;
          _monthOfYear = _date.month;

          break;
      }

      _error = null;
    });
  }

  Future<void> _save() async {
    final amount = Formatters.parseMoney(_amount.text);

    if (_description.text.trim().isEmpty) {
      setState(() {
        _error = 'Informe uma descrição.';
      });

      return;
    }

    if (amount <= 0) {
      setState(() {
        _error = 'Informe um valor maior que zero.';
      });

      return;
    }

    if (_accountId == null) {
      setState(() {
        _error = 'Selecione uma conta.';
      });

      return;
    }

    if (_effectiveCategoryId == null) {
      setState(() {
        _error = _isExpense
            ? 'Selecione uma categoria de gasto.'
            : 'Selecione uma categoria de receita.';
      });

      return;
    }

    if (_repeat == 'monthly' && _monthlyDays.isEmpty && !_monthlyLastDay) {
      setState(() {
        _error = 'Escolha pelo menos um dia do mês.';
      });

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (!_isRecurring) {
        await _registerOnce(amount);
      } else {
        await _registerRecurring(amount);
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
        _error = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _registerOnce(num amount) async {
    if (_isExpense) {
      await widget.repository.registerExpense(
        spaceId: widget.space.id,
        accountId: _accountId!,
        amount: amount,
        description: _description.text.trim(),
        categoryId: _effectiveCategoryId,
        occurredAt: _date,
      );

      return;
    }

    await widget.repository.registerIncome(
      spaceId: widget.space.id,
      accountId: _accountId!,
      amount: amount,
      description: _description.text.trim(),
      categoryId: _effectiveCategoryId,
      occurredAt: _date,
    );
  }

  Future<void> _registerRecurring(num amount) async {
    final dayOfMonth = _repeat == 'monthly' || _repeat == 'yearly'
        ? _dayOfMonth
        : null;

    final weekday = _repeat == 'weekly' || _repeat == 'biweekly'
        ? _weekday
        : null;

    final monthOfYear = _repeat == 'yearly' ? _monthOfYear : null;

    final monthlyDays = _repeat == 'monthly'
        ? (_monthlyDays.toList()..sort())
        : null;

    await widget.repository.createRecurringItem(
      spaceId: widget.space.id,
      name: _description.text.trim(),
      itemType: widget.initialType,
      amount: amount,
      frequency: _repeat,
      accountId: _accountId!,
      categoryId: _effectiveCategoryId,
      dayOfMonth: dayOfMonth,
      monthlyDays: monthlyDays,
      monthlyLastDay: _repeat == 'monthly' ? _monthlyLastDay : false,
      weekday: weekday,
      monthOfYear: monthOfYear,
      startsOn: _date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final purple = AppColors.primaryPurple(brightness);

    final iconBackground = _isExpense ? AppColors.lime : purple;

    final iconForeground = _isExpense ? AppColors.iconOnLime : Colors.white;

    final buttonBackground = _isExpense ? AppColors.lime : purple;

    final buttonForeground = _isExpense ? AppColors.iconOnLime : Colors.white;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 14,
          ),
          child: _loading
              ? const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
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
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: iconBackground,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: Icon(
                              _isExpense ? AppIcons.expense : AppIcons.income,
                              color: iconForeground,
                              size: 27,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _title,
                                  style: AppTypography.section(
                                    context,
                                    fontSize: 21,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _subtitle,
                                  style: AppTypography.body(
                                    context,
                                    fontSize: 13,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        style: AppTypography.money(
                          context,
                          fontSize: 22,
                          color: primaryText,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor',
                          prefixText: 'R\$ ',
                        ),
                      ),

                      const SizedBox(height: 12),

                      _buildCategorySelector(
                        brightness: brightness,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        border: border,
                        surface: surface,
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: _description,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Descrição',
                          hintText: _descriptionHint,
                        ),
                      ),

                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        initialValue: _accountId,
                        decoration: const InputDecoration(labelText: 'Conta'),
                        items: _accounts
                            .map(
                              (account) => DropdownMenuItem<String>(
                                value: account.id,
                                child: Text(account.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _accountId = value;
                          });
                        },
                      ),

                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        initialValue: _repeat,
                        decoration: const InputDecoration(labelText: 'Repete?'),
                        items: const [
                          DropdownMenuItem(
                            value: 'once',
                            child: Text('Uma vez'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Toda semana'),
                          ),
                          DropdownMenuItem(
                            value: 'biweekly',
                            child: Text('A cada 2 semanas'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Todo mês'),
                          ),
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Text('Todo ano'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          _changeRepeat(value);
                        },
                      ),

                      if (_repeat == 'weekly') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _weekday,
                          decoration: const InputDecoration(
                            labelText: 'Dia da semana',
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Domingo')),
                            DropdownMenuItem(
                              value: 1,
                              child: Text('Segunda-feira'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('Terça-feira'),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text('Quarta-feira'),
                            ),
                            DropdownMenuItem(
                              value: 4,
                              child: Text('Quinta-feira'),
                            ),
                            DropdownMenuItem(
                              value: 5,
                              child: Text('Sexta-feira'),
                            ),
                            DropdownMenuItem(value: 6, child: Text('Sábado')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _weekday = value;
                              });
                            }
                          },
                        ),
                      ],

                      if (_repeat == 'biweekly') ...[
                        const SizedBox(height: 10),
                        _InfoBox(
                          icon: AppIcons.recurring,
                          text:
                              'Repete a cada 14 dias a partir de ${_formatDate(_date)}.',
                        ),
                      ],

                      if (_repeat == 'monthly') ...[
                        const SizedBox(height: 16),
                        Text(
                          'Dias do mês',
                          style: AppTypography.label(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...(_monthlyDays.toList()..sort()).map(
                              (day) => InputChip(
                                label: Text('Dia $day'),
                                onDeleted: () {
                                  setState(() {
                                    _monthlyDays.remove(day);
                                  });
                                },
                              ),
                            ),
                            FilterChip(
                              label: const Text('Último dia'),
                              selected: _monthlyLastDay,
                              onSelected: (selected) {
                                setState(() {
                                  _monthlyLastDay = selected;
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(AppIcons.add, size: 18),
                              label: const Text('Outro dia'),
                              onPressed: _pickMonthlyDay,
                            ),
                          ],
                        ),
                        if (_monthlyDays.length + (_monthlyLastDay ? 1 : 0) >
                            1) ...[
                          const SizedBox(height: 10),
                          Text(
                            'O valor informado será considerado em cada uma dessas datas.',
                            style: AppTypography.body(
                              context,
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ],

                      if (_repeat == 'yearly') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _dayOfMonth,
                                decoration: const InputDecoration(
                                  labelText: 'Dia',
                                ),
                                items: List.generate(
                                  31,
                                  (index) => DropdownMenuItem<int>(
                                    value: index + 1,
                                    child: Text('${index + 1}'),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _dayOfMonth = value;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _monthOfYear,
                                decoration: const InputDecoration(
                                  labelText: 'Mês',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('Janeiro'),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text('Fevereiro'),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text('Março'),
                                  ),
                                  DropdownMenuItem(
                                    value: 4,
                                    child: Text('Abril'),
                                  ),
                                  DropdownMenuItem(
                                    value: 5,
                                    child: Text('Maio'),
                                  ),
                                  DropdownMenuItem(
                                    value: 6,
                                    child: Text('Junho'),
                                  ),
                                  DropdownMenuItem(
                                    value: 7,
                                    child: Text('Julho'),
                                  ),
                                  DropdownMenuItem(
                                    value: 8,
                                    child: Text('Agosto'),
                                  ),
                                  DropdownMenuItem(
                                    value: 9,
                                    child: Text('Setembro'),
                                  ),
                                  DropdownMenuItem(
                                    value: 10,
                                    child: Text('Outubro'),
                                  ),
                                  DropdownMenuItem(
                                    value: 11,
                                    child: Text('Novembro'),
                                  ),
                                  DropdownMenuItem(
                                    value: 12,
                                    child: Text('Dezembro'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _monthOfYear = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 10),

                      _DateTile(
                        title: _isRecurring ? 'Começa em' : 'Data',
                        value: _formatDate(_date),
                        onTap: _pickDate,
                      ),

                      if (_isRecurring) ...[
                        const SizedBox(height: 10),
                        const _InfoBox(
                          icon: AppIcons.recurring,
                          text:
                              'O Fôlego considera as próximas ocorrências automaticamente.',
                        ),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: AppColors.expenseText(
                              brightness,
                            ).withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _error!,
                            style: AppTypography.body(
                              context,
                              fontSize: 13,
                              color: AppColors.expenseText(brightness),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: buttonBackground,
                          foregroundColor: buttonForeground,
                        ),
                        child: _saving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: buttonForeground,
                                ),
                              )
                            : Text(_buttonLabel),
                      ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector({
    required Brightness brightness,
    required Color primaryText,
    required Color secondaryText,
    required Color border,
    required Color surface,
  }) {
    if (!_isExpense) {
      return DropdownButtonFormField<String>(
        initialValue: _incomeCategoryId,
        decoration: const InputDecoration(labelText: 'Categoria da receita'),
        items: _incomeCategories
            .map(
              (category) => DropdownMenuItem<String>(
                value: category.id,
                child: Row(
                  children: [
                    Icon(
                      AppIcons.income,
                      size: 19,
                      color: AppColors.positiveText(brightness),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _incomeCategoryId = value;
          });
        },
      );
    }

    final parents = _expenseParentCategories;
    final parent = _selectedExpenseParent;
    final subcategories = _selectedExpenseSubcategories;

    final familyColor = parent == null
        ? AppColors.primaryPurple(brightness)
        : CategoryVisuals.colorFor(
            category: parent.name,
            brightness: brightness,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _expenseParentCategoryId,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: parents
              .map(
                (category) => DropdownMenuItem<String>(
                  value: category.id,
                  child: Row(
                    children: [
                      Icon(
                        CategoryVisuals.iconFor(category: category.name),
                        size: 20,
                        color: CategoryVisuals.colorFor(
                          category: category.name,
                          brightness: brightness,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _expenseParentCategoryId = value;
              _expenseSubcategoryId = null;
              _error = null;
            });
          },
        ),

        if (parent != null && subcategories.isNotEmpty) ...[
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Subcategoria',
                  style: AppTypography.label(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
              ),
              Text(
                'opcional',
                style: AppTypography.label(
                  context,
                  fontSize: 10,
                  color: secondaryText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            'Escolha para deixar seus relatórios mais detalhados.',
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondaryText,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                showCheckmark: false,
                selected: _expenseSubcategoryId == null,
                avatar: Icon(
                  CategoryVisuals.iconFor(category: parent.name),
                  size: 17,
                  color: familyColor,
                ),
                label: const Text('Sem subcategoria'),
                selectedColor: familyColor.withValues(alpha: .16),
                side: BorderSide(
                  color: _expenseSubcategoryId == null ? familyColor : border,
                ),
                onSelected: (_) {
                  setState(() {
                    _expenseSubcategoryId = null;
                  });
                },
              ),

              ...subcategories.map((subcategory) {
                final selected = _expenseSubcategoryId == subcategory.id;

                return ChoiceChip(
                  showCheckmark: false,
                  selected: selected,
                  avatar: Icon(
                    CategoryVisuals.iconFor(
                      category: parent.name,
                      subcategory: subcategory.name,
                    ),
                    size: 17,
                    color: familyColor,
                  ),
                  label: Text(subcategory.name),
                  selectedColor: familyColor.withValues(alpha: .16),
                  side: BorderSide(color: selected ? familyColor : border),
                  onSelected: (_) {
                    setState(() {
                      _expenseSubcategoryId = subcategory.id;
                      _error = null;
                    });
                  },
                );
              }),
            ],
          ),
        ],
      ],
    );
  }

  int _postgresWeekday(DateTime date) {
    return date.weekday % 7;
  }

  CategoryItem? _findCategory(List<CategoryItem> categories, String? id) {
    if (id == null) {
      return null;
    }

    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }

    return null;
  }

  void _sortCategories(List<CategoryItem> categories) {
    categories.sort((a, b) => _sortKey(a.name).compareTo(_sortKey(b.name)));
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _friendlyError(Object error) {
    final text = error.toString();

    if (text.contains('write_access_denied')) {
      return 'Você não tem permissão para alterar esse espaço financeiro.';
    }

    if (text.contains('amount_must_be_positive')) {
      return 'O valor precisa ser maior que zero.';
    }

    return text
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
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
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(AppIcons.calendar, size: 21, color: secondaryText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.label(
                        context,
                        fontSize: 10,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTypography.body(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final purple = AppColors.primaryPurple(brightness);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: purple),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body(
                context,
                fontSize: 12,
                color: secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
