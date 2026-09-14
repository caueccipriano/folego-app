import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/recurring_item.dart';
import '../../data/repositories/folego_repository.dart';

class RecurringFormSheet extends StatefulWidget {
  const RecurringFormSheet({
    super.key,
    required this.space,
    required this.repository,
    this.item,
  });

  final FinancialSpace space;
  final FolegoRepository repository;
  final RecurringItem? item;

  @override
  State<RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends State<RecurringFormSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  List<AccountItem> _accounts = const [];
  List<CategoryItem> _expenseCategories = const [];
  List<CategoryItem> _incomeCategories = const [];

  String _type = 'expense';
  String _frequency = 'monthly';

  String? _accountId;
  String? _categoryId;

  int _dayOfMonth = 1;

  // PostgreSQL:
  // 0 = domingo
  // 1 = segunda
  // 2 = terça
  // 3 = quarta
  // 4 = quinta
  // 5 = sexta
  // 6 = sábado
  int _weekday = 0;

  int _monthOfYear = 1;
  
  final Set<int> _monthlyDays = <int>{};
bool _monthlyLastDay = false;

  DateTime _startsOn = DateTime.now();
  DateTime? _endsOn;

  bool _loading = true;
  bool _saving = false;

  String? _error;

  bool get _editing => widget.item != null;

  bool get _isExpense => _type == 'expense';

  List<CategoryItem> get _availableCategories {
    return _isExpense ? _expenseCategories : _incomeCategories;
  }

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    if (item != null) {
      _name.text = item.name;

      _amount.text = item.amount.toStringAsFixed(2).replaceAll('.', ',');

      _type = item.itemType;
      _frequency = item.frequency;

      _accountId = item.accountId;
      _categoryId = item.categoryId;

      _dayOfMonth = item.dayOfMonth ?? item.startsOn.day;

      _weekday = item.weekday ?? _postgresWeekday(item.startsOn);

      _monthOfYear = item.monthOfYear ?? item.startsOn.month;
_monthlyDays
  ..clear()
  ..addAll(item.monthlyDays);

if (_monthlyDays.isEmpty && item.dayOfMonth != null) {
  _monthlyDays.add(item.dayOfMonth!);
}

_monthlyLastDay = item.monthlyLastDay;

      _startsOn = item.startsOn;
      _endsOn = item.endsOn;
    } else {
      _dayOfMonth = _startsOn.day;
      _weekday = _postgresWeekday(_startsOn);
      _monthOfYear = _startsOn.month;

      _monthlyDays.add(_startsOn.day);
_monthlyLastDay = false;
    }

    _load();
  }

  @override
  void dispose() {
    _name.dispose();
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

      setState(() {
        _accounts = accounts;

        _expenseCategories = expenseCategories;

        _incomeCategories = incomeCategories;

        _accountId ??= accounts.isEmpty ? null : accounts.first.id;

        final categories = _availableCategories;

        final currentCategoryExists =
            _categoryId != null &&
            categories.any((category) => category.id == _categoryId);

        if (!currentCategoryExists) {
          _categoryId = categories.isEmpty ? null : categories.first.id;
        }

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
    builder: (sheetContext) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          18,
          20,
          24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qual dia?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Você pode adicionar mais de um dia.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .58),
                  ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                31,
                (index) {
                  final day = index + 1;
                  final selected = _monthlyDays.contains(day);

                  return ChoiceChip(
                    label: Text('$day'),
                    selected: selected,
                    onSelected: selected
                        ? null
                        : (_) {
                            Navigator.of(sheetContext).pop(day);
                          },
                  );
                },
              ),
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

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Quando começa?',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _startsOn = selected;

      switch (_frequency) {
        case 'weekly':
          _weekday = _postgresWeekday(selected);
          break;

        case 'biweekly':
          // No quinzenal, o backend calcula
          // a cada 14 dias a partir da
          // data inicial.
          _weekday = _postgresWeekday(selected);
          break;

        case 'yearly':
          _dayOfMonth = selected.day;

          _monthOfYear = selected.month;
          break;

        case 'monthly':
        default:
          _dayOfMonth = selected.day;
      }

      if (_endsOn != null && _endsOn!.isBefore(_startsOn)) {
        _endsOn = null;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endsOn ?? _startsOn.add(const Duration(days: 365)),
      firstDate: _startsOn,
      lastDate: DateTime(2100),
      helpText: 'Quando termina?',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _endsOn = selected;
    });
  }

  void _changeType(String type) {
    setState(() {
      _type = type;

      final categories = _availableCategories;

      _categoryId = categories.isEmpty ? null : categories.first.id;

      _error = null;
    });
  }

  void _changeFrequency(String frequency) {
    setState(() {
      _frequency = frequency;

      switch (frequency) {
        case 'weekly':
          _weekday = _postgresWeekday(_startsOn);
          break;

        case 'biweekly':
          _weekday = _postgresWeekday(_startsOn);
          break;

        case 'yearly':
          _dayOfMonth = _startsOn.day;

          _monthOfYear = _startsOn.month;
          break;

        case 'monthly':
        default:
          _dayOfMonth = _startsOn.day;
      }
    });
  }

  Future<void> _save() async {
    final amount = Formatters.parseMoney(_amount.text);

    if (_name.text.trim().isEmpty) {
      setState(() {
        _error = 'Informe o nome da recorrência.';
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

    if (_categoryId == null) {
      setState(() {
        _error = _isExpense
            ? 'Selecione uma categoria de gasto.'
            : 'Selecione uma categoria de receita.';
      });

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final dayOfMonth = _frequency == 'monthly' || _frequency == 'yearly'
          ? _dayOfMonth
          : null;

      final weekday = _frequency == 'weekly' || _frequency == 'biweekly'
          ? _weekday
          : null;

      final monthOfYear = _frequency == 'yearly' ? _monthOfYear : null;

      if (_editing) {
        await widget.repository.updateRecurringItem(
          spaceId: widget.space.id,
          itemId: widget.item!.id,
          name: _name.text.trim(),
          itemType: _type,
          amount: amount,
          frequency: _frequency,
          accountId: _accountId!,
          categoryId: _categoryId,
          dayOfMonth: dayOfMonth,

          monthlyDays:
    _frequency == 'monthly'
        ? (_monthlyDays.toList()..sort())
        : null,
monthlyLastDay:
    _frequency == 'monthly'
        ? _monthlyLastDay
        : false,

          weekday: weekday,
          monthOfYear: monthOfYear,
          startsOn: _startsOn,
          endsOn: _endsOn,
          active: widget.item!.active,
          certainty: widget.item!.certainty,
        );
      } else {
        await widget.repository.createRecurringItem(
          spaceId: widget.space.id,
          name: _name.text.trim(),
          itemType: _type,
          amount: amount,
          frequency: _frequency,
          accountId: _accountId!,
          categoryId: _categoryId,
          dayOfMonth: dayOfMonth,
          monthlyDays:
              _frequency == 'monthly' ? (_monthlyDays.toList()..sort()) : null,
          monthlyLastDay: _frequency == 'monthly' ? _monthlyLastDay : false,
          weekday: weekday,
          monthOfYear: monthOfYear,
          startsOn: _startsOn,
          endsOn: _endsOn,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconBackground = _isExpense
        ? AppPalette.lime
        : isDark
        ? const Color(0xFFF3F1EC)
        : const Color(0xFF111111);

    final iconForeground = _isExpense
        ? const Color(0xFF111111)
        : isDark
        ? const Color(0xFF111111)
        : AppPalette.lime;

    final buttonBackground = _isExpense
        ? AppPalette.lime
        : isDark
        ? const Color(0xFFF3F1EC)
        : const Color(0xFF111111);

    final buttonForeground = _isExpense
        ? const Color(0xFF111111)
        : isDark
        ? const Color(0xFF111111)
        : AppPalette.lime;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
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
                          color: Theme.of(context).colorScheme.outlineVariant,
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
                          decoration: BoxDecoration(
                            color: iconBackground,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Icon(
                            _isExpense
                                ? Icons.receipt_long_rounded
                                : Icons.add_rounded,
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
                                _editing
                                    ? 'editar recorrência'
                                    : 'nova recorrência',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'o Fôlego considera isso antes do dinheiro sair ou entrar',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: .58),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('Gasto'),
                          icon: Icon(Icons.receipt_long_rounded),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('Receita'),
                          icon: Icon(Icons.add_rounded),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (values) {
                        _changeType(values.first);
                      },
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        hintText: _isExpense ? 'Ex.: Aluguel' : 'Ex.: Salário',
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        prefixText: 'R\$ ',
                      ),
                    ),

                    const SizedBox(height: 12),

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

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: InputDecoration(
                        labelText: _isExpense
                            ? 'Categoria do gasto'
                            : 'Categoria da receita',
                      ),
                      items: _availableCategories
                          .map(
                            (category) => DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _categoryId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequência',
                      ),
                      items: const [
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

                        _changeFrequency(value);
                      },
                    ),

if (_frequency == 'monthly') ...[
  const SizedBox(height: 12),

  Text(
    'Dias do mês',
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
  ),

  const SizedBox(height: 8),

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
        avatar: const Icon(
          Icons.add_rounded,
          size: 18,
        ),
        label: const Text('Outro dia'),
        onPressed: _pickMonthlyDay,
      ),
    ],
  ),

  if (_monthlyDays.length + (_monthlyLastDay ? 1 : 0) > 1) ...[
    const SizedBox(height: 10),

    Text(
      'O valor informado será considerado em cada uma dessas datas.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: .58),
          ),
    ),
  ],
],

                    if (_frequency == 'weekly') ...[
                      const SizedBox(height: 12),

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

                    if (_frequency == 'biweekly') ...[
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_repeat_rounded, size: 21),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'Vai repetir a cada 14 dias a partir de ${_dateLabel(_startsOn)}.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_frequency == 'yearly') ...[
                      const SizedBox(height: 12),

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

                          const SizedBox(width: 12),

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
                                DropdownMenuItem(value: 5, child: Text('Maio')),
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

                    const SizedBox(height: 16),

                    _DateTile(
                      title: 'Começa em',
                      value: _dateLabel(_startsOn),
                      icon: Icons.calendar_today_outlined,
                      onTap: _pickStartDate,
                    ),

                    const SizedBox(height: 10),

                    _DateTile(
                      title: 'Termina em',
                      value: _endsOn == null
                          ? 'Sem data final'
                          : _dateLabel(_endsOn!),
                      icon: Icons.event_available_outlined,
                      onTap: _pickEndDate,
                      trailing: _endsOn == null
                          ? null
                          : IconButton(
                              tooltip: 'Remover data final',
                              onPressed: () {
                                setState(() {
                                  _endsOn = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer
                              .withValues(alpha: isDark ? .25 : .65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

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
                          : Text(
                              _editing
                                  ? 'Salvar recorrência'
                                  : 'Criar recorrência',
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  int _postgresWeekday(DateTime date) {
    return date.weekday % 7;
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

  String _dateLabel(DateTime date) {
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

    if (text.contains('Invalid income category')) {
      return 'Selecione uma categoria de receita válida.';
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
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodySmall),

                    const SizedBox(height: 2),

                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
