import 'dart:async';

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
import '../../shared/widgets/category_icon_badge.dart';

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
      _isExpense ? 'ex.: jantar com amigos' : 'ex.: salário';

  String get _buttonLabel {
    if (_isRecurring) {
      return _isExpense
          ? 'salvar gasto recorrente'
          : 'salvar receita recorrente';
    }

    return _isExpense ? 'registrar gasto' : 'registrar receita';
  }

  String? get _effectiveCategoryId {
    if (_isExpense) {
      return _expenseSubcategoryId ?? _expenseParentCategoryId;
    }

    return _incomeCategoryId;
  }

  List<CategoryItem> get _expenseParentCategories {
    final result =
        _expenseCategories.where((category) => category.isParent).toList();

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
    return _findCategory(
      _expenseCategories,
      _expenseParentCategoryId,
    );
  }

  CategoryItem? get _selectedIncomeCategory {
    return _findCategory(
      _incomeCategories,
      _incomeCategoryId,
    );
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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      debugPrint('[QuickRegister] carregando contas...');

      final accounts = await widget.repository
          .listAccounts(widget.space.id)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'As contas demoraram demais para carregar.',
              );
            },
          );

      debugPrint(
        '[QuickRegister] contas carregadas: ${accounts.length}',
      );

      List<CategoryItem> expenseCategories = const [];
      List<CategoryItem> incomeCategories = const [];

      if (_isExpense) {
        debugPrint(
          '[QuickRegister] carregando categorias de gasto...',
        );

        expenseCategories = await widget.repository
            .listExpenseCategories(widget.space.id)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException(
                  'As categorias de gasto demoraram demais para carregar.',
                );
              },
            );

        debugPrint(
          '[QuickRegister] categorias de gasto: '
          '${expenseCategories.length}',
        );
      } else {
        debugPrint(
          '[QuickRegister] carregando categorias de receita...',
        );

        incomeCategories = await widget.repository
            .listIncomeCategories(widget.space.id)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException(
                  'As categorias de receita demoraram demais para carregar.',
                );
              },
            );

        debugPrint(
          '[QuickRegister] categorias de receita: '
          '${incomeCategories.length}',
        );
      }

      if (!mounted) {
        return;
      }

      _sortCategories(expenseCategories);
      _sortCategories(incomeCategories);

      final expenseParents =
          expenseCategories.where((category) => category.isParent).toList();

      _sortCategories(expenseParents);

      setState(() {
        _accounts = accounts;

        _expenseCategories = expenseCategories;
        _incomeCategories = incomeCategories;

        _accountId = accounts.isEmpty ? null : accounts.first.id;

        _expenseParentCategoryId =
            expenseParents.isEmpty ? null : expenseParents.first.id;

        _expenseSubcategoryId = null;

        _incomeCategoryId =
            incomeCategories.isEmpty ? null : incomeCategories.first.id;

        _loading = false;
      });

      debugPrint('[QuickRegister] carregamento concluído.');
    } catch (error, stackTrace) {
      debugPrint('[QuickRegister] ERRO: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _pickExpenseParentCategory() async {
    FocusScope.of(context).unfocus();

    final categories = _expenseParentCategories;

    if (categories.isEmpty) {
      setState(() {
        _error = 'nenhuma categoria de gasto foi encontrada';
      });

      return;
    }

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) {
        return _CategoryPickerSheet(
          title: 'categoria',
          subtitle: 'onde esse gasto entra?',
          categories: categories,
          selectedId: _expenseParentCategoryId,
          iconBuilder: (category) {
            return CategoryVisuals.iconFor(
              category: category.name,
            );
          },
          colorBuilder: (category, brightness) {
            return CategoryVisuals.colorFor(
              category: category.name,
              brightness: brightness,
            );
          },
        );
      },
    );

    if (selectedId == null || !mounted) {
      return;
    }

    setState(() {
      _expenseParentCategoryId = selectedId;
      _expenseSubcategoryId = null;
      _error = null;
    });
  }

  Future<void> _pickIncomeCategory() async {
    FocusScope.of(context).unfocus();

    if (_incomeCategories.isEmpty) {
      setState(() {
        _error = 'nenhuma categoria de receita foi encontrada';
      });

      return;
    }

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) {
        return _CategoryPickerSheet(
          title: 'categoria da receita',
          subtitle: 'de onde esse dinheiro veio?',
          categories: _incomeCategories,
          selectedId: _incomeCategoryId,
          iconBuilder: (_) => AppIcons.income,
          colorBuilder: (_, brightness) {
            return AppColors.positiveText(brightness);
          },
        );
      },
    );

    if (selectedId == null || !mounted) {
      return;
    }

    setState(() {
      _incomeCategoryId = selectedId;
      _error = null;
    });
  }

  Future<void> _pickMonthlyDay() async {
    final selectedDay = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) {
        final brightness = Theme.of(sheetContext).brightness;

        final background = AppColors.background(brightness);
        final border = AppColors.border(brightness);
        final primaryText = AppColors.primaryText(brightness);
        final secondaryText = AppColors.secondaryText(brightness);
        final purple = AppColors.primaryPurple(brightness);

        return Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              14,
              20,
              28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 22),
                Text(
                  'qual dia?',
                  style: AppTypography.section(
                    sheetContext,
                    fontSize: 20,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'você pode adicionar mais de um dia',
                  style: AppTypography.body(
                    sheetContext,
                    fontSize: 12,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 31,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (context, index) {
                    final day = index + 1;

                    final selected = _monthlyDays.contains(day);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: selected
                            ? null
                            : () {
                                Navigator.of(sheetContext).pop(day);
                              },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? purple.withValues(alpha: .13)
                                : AppColors.surface(brightness),
                            border: Border.all(
                              color: selected ? purple : border,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '$day',
                            style: AppTypography.label(
                              sheetContext,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? purple : primaryText,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
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
      helpText: _isRecurring ? 'quando começa?' : 'data do lançamento',
      cancelText: 'cancelar',
      confirmText: 'selecionar',
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

  void _changeRepeat(
    String value,
  ) {
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
        _error = 'informe uma descrição';
      });

      return;
    }

    if (amount <= 0) {
      setState(() {
        _error = 'informe um valor maior que zero';
      });

      return;
    }

    if (_accountId == null) {
      setState(() {
        _error = 'selecione uma conta';
      });

      return;
    }

    if (_effectiveCategoryId == null) {
      setState(() {
        _error = _isExpense
            ? 'selecione uma categoria de gasto'
            : 'selecione uma categoria de receita';
      });

      return;
    }

    if (_repeat == 'monthly' &&
        _monthlyDays.isEmpty &&
        !_monthlyLastDay) {
      setState(() {
        _error = 'escolha pelo menos um dia do mês';
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

  Future<void> _registerOnce(
    num amount,
  ) async {
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

  Future<void> _registerRecurring(
    num amount,
  ) async {
    final dayOfMonth = _repeat == 'monthly' || _repeat == 'yearly'
        ? _dayOfMonth
        : null;

    final weekday =
        _repeat == 'weekly' || _repeat == 'biweekly' ? _weekday : null;

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
  Widget build(
    BuildContext context,
  ) {
    final brightness = Theme.of(context).brightness;

    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    final accent = _isExpense
        ? AppColors.lime
        : AppColors.positiveText(brightness);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .94,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(30),
            ),
            border: Border(
              top: BorderSide(
                color: border,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: _loading
                ? const SizedBox(
                    height: 320,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .13),
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(
                                  color: accent.withValues(alpha: .22),
                                ),
                              ),
                              child: Icon(
                                _isExpense
                                    ? AppIcons.expense
                                    : AppIcons.income,
                                color: accent,
                                size: 26,
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
                                      fontSize: 12,
                                      color: secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            14,
                            16,
                            10,
                          ),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: accent.withValues(alpha: .24),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'quanto?',
                                style: AppTypography.label(
                                  context,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: secondaryText,
                                ),
                              ),
                              TextField(
                                controller: _amount,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.next,
                                style: AppTypography.money(
                                  context,
                                  fontSize: 30,
                                  color: primaryText,
                                ),
                                decoration: const InputDecoration(
                                  prefixText: 'R\$ ',
                                  hintText: '0,00',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() {
                                      _error = null;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel(
                          title: 'categoria',
                          subtitle: _isExpense
                              ? 'onde esse gasto entra'
                              : 'de onde esse dinheiro veio',
                        ),
                        const SizedBox(height: 10),
                        _buildCategorySelector(
                          brightness: brightness,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          border: border,
                          surface: surface,
                        ),
                        const SizedBox(height: 24),
                        const _SectionLabel(
                          title: 'detalhes',
                          subtitle: 'o básico para lembrar depois',
                        ),
                        const SizedBox(height: 10),
                        _FormPanel(
                          surface: surface,
                          border: border,
                          child: Column(
                            children: [
                              TextField(
                                controller: _description,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'descrição',
                                  hintText: _descriptionHint,
                                ),
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() {
                                      _error = null;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _accountId,
                                decoration: const InputDecoration(
                                  labelText: 'conta',
                                ),
                                items: _accounts
                                    .map(
                                      (account) => DropdownMenuItem<String>(
                                        value: account.id,
                                        child: Text(
                                          account.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _accountId = value;
                                    _error = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _DateTile(
                                title: _isRecurring ? 'começa em' : 'data',
                                value: _formatDate(_date),
                                onTap: _pickDate,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _SectionLabel(
                          title: 'repetição',
                          subtitle: 'é uma vez só ou faz parte da rotina?',
                        ),
                        const SizedBox(height: 10),
                        _FormPanel(
                          surface: surface,
                          border: border,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _repeat,
                                decoration: const InputDecoration(
                                  labelText: 'repete?',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'once',
                                    child: Text('uma vez'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'weekly',
                                    child: Text('toda semana'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'biweekly',
                                    child: Text('a cada 2 semanas'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: Text('todo mês'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'yearly',
                                    child: Text('todo ano'),
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
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _weekday,
                                  decoration: const InputDecoration(
                                    labelText: 'dia da semana',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 0,
                                      child: Text('domingo'),
                                    ),
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text('segunda-feira'),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text('terça-feira'),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text('quarta-feira'),
                                    ),
                                    DropdownMenuItem(
                                      value: 4,
                                      child: Text('quinta-feira'),
                                    ),
                                    DropdownMenuItem(
                                      value: 5,
                                      child: Text('sexta-feira'),
                                    ),
                                    DropdownMenuItem(
                                      value: 6,
                                      child: Text('sábado'),
                                    ),
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
                                const SizedBox(height: 12),
                                _InfoBox(
                                  icon: AppIcons.recurring,
                                  text:
                                      'repete a cada 14 dias a partir de ${_formatDate(_date)}',
                                ),
                              ],
                              if (_repeat == 'monthly') ...[
                                const SizedBox(height: 18),
                                Text(
                                  'dias do mês',
                                  style: AppTypography.label(
                                    context,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'toque em um dia escolhido para removê-lo',
                                  style: AppTypography.body(
                                    context,
                                    fontSize: 10,
                                    color: secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...(_monthlyDays.toList()..sort()).map(
                                      (day) => _CompactPill(
                                        label: 'dia $day',
                                        selected: true,
                                        color: AppColors.primaryPurple(
                                          brightness,
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _monthlyDays.remove(day);
                                          });
                                        },
                                      ),
                                    ),
                                    _CompactPill(
                                      label: 'último dia',
                                      selected: _monthlyLastDay,
                                      color: AppColors.primaryPurple(
                                        brightness,
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _monthlyLastDay = !_monthlyLastDay;
                                        });
                                      },
                                    ),
                                    _CompactPill(
                                      label: 'outro dia',
                                      icon: AppIcons.add,
                                      color: AppColors.primaryPurple(
                                        brightness,
                                      ),
                                      onTap: _pickMonthlyDay,
                                    ),
                                  ],
                                ),
                                if (_monthlyDays.length +
                                        (_monthlyLastDay ? 1 : 0) >
                                    1) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'o valor informado será considerado em cada uma dessas datas',
                                    style: AppTypography.body(
                                      context,
                                      fontSize: 11,
                                      color: secondaryText,
                                    ),
                                  ),
                                ],
                              ],
                              if (_repeat == 'yearly') ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        initialValue: _dayOfMonth,
                                        decoration: const InputDecoration(
                                          labelText: 'dia',
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
                                          labelText: 'mês',
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 1,
                                            child: Text('janeiro'),
                                          ),
                                          DropdownMenuItem(
                                            value: 2,
                                            child: Text('fevereiro'),
                                          ),
                                          DropdownMenuItem(
                                            value: 3,
                                            child: Text('março'),
                                          ),
                                          DropdownMenuItem(
                                            value: 4,
                                            child: Text('abril'),
                                          ),
                                          DropdownMenuItem(
                                            value: 5,
                                            child: Text('maio'),
                                          ),
                                          DropdownMenuItem(
                                            value: 6,
                                            child: Text('junho'),
                                          ),
                                          DropdownMenuItem(
                                            value: 7,
                                            child: Text('julho'),
                                          ),
                                          DropdownMenuItem(
                                            value: 8,
                                            child: Text('agosto'),
                                          ),
                                          DropdownMenuItem(
                                            value: 9,
                                            child: Text('setembro'),
                                          ),
                                          DropdownMenuItem(
                                            value: 10,
                                            child: Text('outubro'),
                                          ),
                                          DropdownMenuItem(
                                            value: 11,
                                            child: Text('novembro'),
                                          ),
                                          DropdownMenuItem(
                                            value: 12,
                                            child: Text('dezembro'),
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
                              if (_isRecurring) ...[
                                const SizedBox(height: 12),
                                const _InfoBox(
                                  icon: AppIcons.recurring,
                                  text:
                                      'o Fôlego considera as próximas ocorrências automaticamente',
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.expenseText(
                                brightness,
                              ).withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: AppColors.expenseText(
                                  brightness,
                                ).withValues(alpha: .20),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: AppTypography.body(
                                context,
                                fontSize: 12,
                                color: AppColors.expenseText(
                                  brightness,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.lime,
                              foregroundColor: AppColors.iconOnLime,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.iconOnLime,
                                    ),
                                  )
                                : Text(
                                    _buttonLabel,
                                    style: AppTypography.button(
                                      context,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
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
      final selected = _selectedIncomeCategory;

      final positive = AppColors.positiveText(brightness);

      return _FormPanel(
        surface: surface,
        border: border,
        child: _CategorySelectTile(
          label: 'categoria da receita',
          value: selected?.name ?? 'selecionar categoria',
          icon: AppIcons.income,
          color: positive,
          onTap: _pickIncomeCategory,
        ),
      );
    }

    final parent = _selectedExpenseParent;
    final subcategories = _selectedExpenseSubcategories;

    final familyColor = parent == null
        ? AppColors.primaryPurple(brightness)
        : CategoryVisuals.colorFor(
            category: parent.name,
            brightness: brightness,
          );

    final familyIcon = parent == null
        ? CategoryVisuals.iconFor(category: 'A classificar')
        : CategoryVisuals.iconFor(
            category: parent.name,
          );

    return _FormPanel(
      surface: surface,
      border: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CategorySelectTile(
            label: 'categoria',
            value: parent?.name ?? 'selecionar categoria',
            icon: familyIcon,
            color: familyColor,
            onTap: _pickExpenseParentCategory,
          ),
          if (parent != null && subcategories.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'subcategoria',
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
                    fontSize: 9,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'deixa seu histórico e seu plano mais detalhados',
              style: AppTypography.body(
                context,
                fontSize: 10,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CategoryChoiceChip(
                  label: 'sem subcategoria',
                  icon: CategoryVisuals.iconFor(
                    category: parent.name,
                  ),
                  color: familyColor,
                  selected: _expenseSubcategoryId == null,
                  onTap: () {
                    setState(() {
                      _expenseSubcategoryId = null;
                      _error = null;
                    });
                  },
                ),
                ...subcategories.map(
                  (subcategory) {
                    final selected =
                        _expenseSubcategoryId == subcategory.id;

                    return _CategoryChoiceChip(
                      label: subcategory.name,
                      icon: CategoryVisuals.iconFor(
                        category: parent.name,
                        subcategory: subcategory.name,
                      ),
                      color: familyColor,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          _expenseSubcategoryId = subcategory.id;
                          _error = null;
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  int _postgresWeekday(
    DateTime date,
  ) {
    return date.weekday % 7;
  }

  CategoryItem? _findCategory(
    List<CategoryItem> categories,
    String? id,
  ) {
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

  void _sortCategories(
    List<CategoryItem> categories,
  ) {
    categories.sort(
      (a, b) => _sortKey(a.name).compareTo(
        _sortKey(b.name),
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
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _friendlyError(
    Object error,
  ) {
    final text = error.toString();

    if (text.contains('write_access_denied')) {
      return 'você não tem permissão para alterar esse espaço financeiro';
    }

    if (text.contains('amount_must_be_positive')) {
      return 'o valor precisa ser maior que zero';
    }

    if (error is TimeoutException) {
      return error.message ?? 'demorou demais para carregar';
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

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.title,
    required this.subtitle,
    required this.categories,
    required this.selectedId,
    required this.iconBuilder,
    required this.colorBuilder,
  });

  final String title;
  final String subtitle;
  final List<CategoryItem> categories;
  final String? selectedId;
  final IconData Function(CategoryItem category) iconBuilder;
  final Color Function(
    CategoryItem category,
    Brightness brightness,
  ) colorBuilder;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return FractionallySizedBox(
      heightFactor: .76,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(30),
          ),
          border: Border(
            top: BorderSide(color: border),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 14),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  22,
                  20,
                  14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.section(
                              context,
                              fontSize: 21,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
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
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        AppIcons.close,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    24,
                  ),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 8);
                  },
                  itemBuilder: (context, index) {
                    final category = categories[index];

                    final selected = category.id == selectedId;

                    final color = colorBuilder(
                      category,
                      brightness,
                    );

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop(category.id);
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Ink(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: .10)
                                : surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? color.withValues(alpha: .45)
                                  : border,
                            ),
                          ),
                          child: Row(
                            children: [
                              CategoryIconBadge(
                                icon: iconBuilder(category),
                                color: color,
                                size: 40,
                                iconSize: 20,
                                radius: 13,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: AppTypography.body(
                                    context,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: primaryText,
                                  ),
                                ),
                              ),
                              if (selected)
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: purple.withValues(alpha: .12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    AppIcons.check,
                                    size: 16,
                                    color: purple,
                                  ),
                                )
                              else
                                Icon(
                                  AppIcons.chevronRight,
                                  size: 18,
                                  color: secondaryText,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySelectTile extends StatelessWidget {
  const _CategorySelectTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: border,
            ),
          ),
          child: Row(
            children: [
              CategoryIconBadge(
                icon: icon,
                color: color,
                size: 38,
                iconSize: 19,
                radius: 12,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.label(
                        context,
                        fontSize: 9,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(
    BuildContext context,
  ) {
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.section(
            context,
            fontSize: 16,
            color: AppColors.primaryText(brightness),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: AppTypography.body(
            context,
            fontSize: 11,
            color: AppColors.secondaryText(brightness),
          ),
        ),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.surface,
    required this.border,
    required this.child,
  });

  final Color surface;
  final Color border;
  final Widget child;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: child,
    );
  }
}

class _CategoryChoiceChip extends StatelessWidget {
  const _CategoryChoiceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final brightness = Theme.of(context).brightness;

    final primaryText = AppColors.primaryText(brightness);
    final border = AppColors.border(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            7,
            6,
            11,
            6,
          ),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: .14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: .48)
                  : border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryIconBadge(
                icon: icon,
                color: color,
                size: 26,
                iconSize: 14,
                radius: 9,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTypography.label(
                  context,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactPill extends StatelessWidget {
  const _CompactPill({
    required this.label,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  final bool selected;
  final IconData? icon;

  @override
  Widget build(
    BuildContext context,
  ) {
    final brightness = Theme.of(context).brightness;

    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: .13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: .42)
                  : border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: color,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTypography.label(
                  context,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
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
    final brightness = Theme.of(context).brightness;

    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: border,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  AppIcons.calendar,
                  size: 18,
                  color: purple,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.label(
                        context,
                        fontSize: 9,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: secondaryText,
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
    final brightness = Theme.of(context).brightness;

    final border = AppColors.border(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: purple.withValues(alpha: .06),
        border: Border.all(
          color: border,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: purple,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}