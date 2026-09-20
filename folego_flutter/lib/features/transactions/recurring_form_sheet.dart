import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/credit_card_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/recurring_item.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_payment_instruments.dart';
import '../../shared/widgets/app_loading_state.dart';

typedef ActiveRecurringCardLoader = Future<List<CreditCardItem>> Function(
  String spaceId,
);

class RecurringFormSheet extends StatefulWidget {
  const RecurringFormSheet({
    super.key,
    required this.space,
    required this.repository,
    this.item,
    this.activeCardLoader,
  });

  final FinancialSpace space;
  final FolegoRepository repository;
  final RecurringItem? item;
  final ActiveRecurringCardLoader? activeCardLoader;

  @override
  State<RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends State<RecurringFormSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  List<AccountItem> _accounts = const [];
  List<_RecurringCardOption> _cards = const [];
  List<CategoryItem> _expenseCategories = const [];
  List<CategoryItem> _incomeCategories = const [];

  String _type = 'expense';
  String _frequency = 'monthly';

  String? _accountId;
  String? _cardId;
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

  bool get _showAccountDestination {
    return !_isExpense || _cardId == null;
  }

  bool get _showCardDestination {
    return _isExpense && _cardId != null;
  }

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
      _cardId = item.cardId;
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

  Future<List<CreditCardItem>> _loadActiveCards() {
    final loader = widget.activeCardLoader;
    if (loader != null) {
      return loader(widget.space.id);
    }
    return widget.repository.listActiveCreditCards(widget.space.id);
  }

  Future<void> _load() async {
    try {
      final cardOverviewFuture = _editing && _cardId != null
          ? widget.repository.getWalletOverview(spaceId: widget.space.id)
          : Future<WalletOverview?>.value(null);

      final activeCardsFuture = !_editing && _isExpense
          ? _loadActiveCards()
          : Future<List<CreditCardItem>>.value(const <CreditCardItem>[]);

      final values = await Future.wait([
        widget.repository.listAccounts(widget.space.id),
        cardOverviewFuture,
        activeCardsFuture,
        widget.repository.listExpenseCategories(widget.space.id),
        widget.repository.listIncomeCategories(widget.space.id),
      ]);

      if (!mounted) {
        return;
      }

      final accounts = (values[0] as List<AccountItem>)
          .where((account) => !account.isBenefit)
          .toList();

      final walletOverview = values[1] as WalletOverview?;
      final activeCards = values[2] as List<CreditCardItem>;

      final cardsById = <String, _RecurringCardOption>{
        for (final card in walletOverview?.cards ?? const <WalletCard>[])
          card.id: _RecurringCardOption(
            id: card.id,
            name: card.name,
            available: true,
          ),
        for (final card in activeCards)
          card.id: _RecurringCardOption(
            id: card.id,
            name: card.name,
            available: true,
          ),
      };

      final currentCardId = _cardId;

      if (currentCardId != null && !cardsById.containsKey(currentCardId)) {
        cardsById[currentCardId] = _RecurringCardOption(
          id: currentCardId,
          name: 'cartão atual',
          available: false,
        );
      }

      final expenseCategories =
          List<CategoryItem>.of(values[3] as List<CategoryItem>);

      final incomeCategories =
          List<CategoryItem>.of(values[4] as List<CategoryItem>);

      _sortCategories(expenseCategories);
      _sortCategories(incomeCategories);

      setState(() {
        _accounts = accounts;

        _cards = cardsById.values.toList();

        _expenseCategories = expenseCategories;

        _incomeCategories = incomeCategories;

        if (!_editing && _accountId == null && _cardId == null) {
          _accountId = accounts.isEmpty ? null : accounts.first.id;
          if (_accountId == null && _cards.isNotEmpty && _isExpense) {
            _cardId = _cards.first.id;
          }
        }

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

  void _selectDestination(bool useCard) {
    if (!_isExpense) {
      return;
    }

    setState(() {
      if (useCard) {
        _accountId = null;
        _cardId ??= _cards.isEmpty ? null : _cards.first.id;
      } else {
        _cardId = null;
        _accountId ??= _accounts.isEmpty ? null : _accounts.first.id;
      }
      _error = null;
    });
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
              'qual dia?',
              style: AppTypography.section(context, fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              'você pode adicionar mais de um dia',
              style: AppTypography.body(
                context,
                fontSize: 12,
                color: AppColors.secondaryText(Theme.of(context).brightness),
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
      helpText: 'quando começa?',
      cancelText: 'cancelar',
      confirmText: 'selecionar',
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
      helpText: 'quando termina?',
      cancelText: 'cancelar',
      confirmText: 'selecionar',
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

      if (!_isExpense) {
        _cardId = null;
        _accountId ??= _accounts.isEmpty ? null : _accounts.first.id;
      }

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
        _error = 'informe o nome da recorrência';
      });

      return;
    }

    if (amount <= 0) {
      setState(() {
        _error = 'informe um valor maior que zero';
      });

      return;
    }

    final hasAccount = _accountId != null;
    final hasCard = _cardId != null;
    final invalidDestination = _isExpense
        ? hasAccount == hasCard
        : !hasAccount || hasCard;

    if (invalidDestination) {
      setState(() {
        _error = _isExpense
            ? 'selecione uma conta ou cartão'
            : 'selecione uma conta';
      });

      return;
    }

    if (_categoryId == null) {
      setState(() {
        _error = _isExpense
            ? 'selecione uma categoria de gasto'
            : 'selecione uma categoria de receita';
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
          accountId: _accountId,
          cardId: _cardId,
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
          accountId: _accountId,
          cardId: _cardId,
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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final accent = _isExpense
        ? AppColors.lime
        : AppColors.primaryPurple(brightness);
    final accentForeground = _isExpense
        ? AppColors.iconOnLime
        : isDark
            ? AppColors.darkPrimaryText
            : Colors.white;

    final iconBackground = accent;
    final iconForeground = accentForeground;
    final buttonBackground = accent;
    final buttonForeground = accentForeground;

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
            ? const AppLoadingState(label: 'organizando sua recorrência')
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
                          borderRadius: BorderRadius.circular(AppRadii.pill),
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
                            borderRadius: BorderRadius.circular(AppRadii.compactCard),
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
                                style: AppTypography.section(
                                  context,
                                  fontSize: 21,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'o Fôlego considera isso antes do dinheiro sair ou entrar',
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

                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('gasto'),
                          icon: Icon(Icons.receipt_long_rounded),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('receita'),
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
                        labelText: 'nome',
                        hintText: _isExpense ? 'ex.: aluguel' : 'ex.: salário',
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
                        labelText: 'valor',
                        prefixText: 'R\$ ',
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_isExpense && _cards.isNotEmpty) ...[
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('conta'),
                            icon: Icon(AppIcons.account),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('cartão'),
                            icon: Icon(AppIcons.creditCard),
                          ),
                        ],
                        selected: {_cardId != null},
                        onSelectionChanged: (values) {
                          _selectDestination(values.first);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_showAccountDestination)
                      DropdownButtonFormField<String>(
                        initialValue: _accountId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'conta',
                          prefixIcon: Icon(AppIcons.account),
                        ),
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
                            _cardId = null;
                            _error = null;
                          });
                        },
                      ),

                    if (_showAccountDestination && _showCardDestination)
                      const SizedBox(height: 12),

                    if (_showCardDestination) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _cardId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'cartão',
                          prefixIcon: Icon(AppIcons.creditCard),
                        ),
                        items: _cards
                            .map(
                              (card) => DropdownMenuItem<String>(
                                value: card.id,
                                child: Text(
                                  card.available
                                      ? card.name
                                      : '${card.name} (inativo ou indisponível)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _cardId = value;
                            _accountId = null;
                            _error = null;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _cards.any(
                          (card) => card.id == _cardId && !card.available,
                        )
                            ? 'este cartão não aparece mais entre os cartões ativos. o vínculo atual será preservado'
                            : 'cada ocorrência será lançada como uma compra 1x neste cartão',
                        style: AppTypography.body(
                          context,
                          fontSize: 11,
                          color: AppColors.secondaryText(
                            Theme.of(context).brightness,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: InputDecoration(
                        labelText: _isExpense
                            ? 'categoria do gasto'
                            : 'categoria da receita',
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
                        labelText: 'frequência',
                      ),
                      items: const [
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

                        _changeFrequency(value);
                      },
                    ),

if (_frequency == 'monthly') ...[
  const SizedBox(height: 12),

  Text(
    'dias do mês',
    style: AppTypography.label(
      context,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: primaryText,
    ),
  ),

  const SizedBox(height: 8),

  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ...(_monthlyDays.toList()..sort()).map(
        (day) => InputChip(
          label: Text('dia $day'),
          onDeleted: () {
            setState(() {
              _monthlyDays.remove(day);
            });
          },
        ),
      ),

      FilterChip(
        label: const Text('último dia'),
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
        label: const Text('outro dia'),
        onPressed: _pickMonthlyDay,
      ),
    ],
  ),

  if (_monthlyDays.length + (_monthlyLastDay ? 1 : 0) > 1) ...[
    const SizedBox(height: 10),

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

                    if (_frequency == 'weekly') ...[
                      const SizedBox(height: 12),

                      DropdownButtonFormField<int>(
                        initialValue: _weekday,
                        decoration: const InputDecoration(
                          labelText: 'dia da semana',
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('domingo')),
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
                          DropdownMenuItem(value: 6, child: Text('sábado')),
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
                          borderRadius: BorderRadius.circular(AppRadii.control),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_repeat_rounded, size: 21),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'vai repetir a cada 14 dias a partir de ${_dateLabel(_startsOn)}',
                                style: AppTypography.body(
                                  context,
                                  fontSize: 12,
                                  color: primaryText,
                                ),
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

                          const SizedBox(width: 12),

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
                                DropdownMenuItem(value: 5, child: Text('maio')),
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

                    const SizedBox(height: 16),

                    _DateTile(
                      title: 'começa em',
                      value: _dateLabel(_startsOn),
                      icon: Icons.calendar_today_outlined,
                      onTap: _pickStartDate,
                    ),

                    const SizedBox(height: 10),

                    _DateTile(
                      title: 'termina em',
                      value: _endsOn == null
                          ? 'sem data final'
                          : _dateLabel(_endsOn!),
                      icon: Icons.event_available_outlined,
                      onTap: _pickEndDate,
                      trailing: _endsOn == null
                          ? null
                          : IconButton(
                              tooltip: 'remover data final',
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
                          borderRadius: BorderRadius.circular(AppRadii.control),
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
                                  ? 'salvar recorrência'
                                  : 'criar recorrência',
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
      return 'você não tem permissão para alterar esse espaço financeiro';
    }

    if (text.contains('amount_must_be_positive')) {
      return 'o valor precisa ser maior que zero';
    }

    if (text.contains('Invalid income category')) {
      return 'selecione uma categoria de receita válida';
    }

    return text
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
  }
}

class _RecurringCardOption {
  const _RecurringCardOption({
    required this.id,
    required this.name,
    required this.available,
  });

  final String id;
  final String name;
  final bool available;
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
    final brightness = Theme.of(context).brightness;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21),

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
                        color: AppColors.secondaryText(brightness),
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      value,
                      style: AppTypography.body(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText(brightness),
                      ),
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
