import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/theme/reflection_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/credit_card_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/transaction_reflection.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../data/repositories/folego_repository_diary.dart';
import '../../data/repositories/folego_repository_payment_instruments.dart';
import '../../shared/widgets/category_icon_badge.dart';
import '../../shared/widgets/category_search_picker.dart';
import 'quick_register_payment_state.dart';

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
  final _merchant = TextEditingController();
  final _reflectionNote = TextEditingController();

  RealtimeRefreshBinding? _categoryRealtimeBinding;
  RealtimeRefreshBinding? _instrumentRealtimeBinding;

  List<AccountItem> _paymentAccounts = const [];
  List<AccountItem> _benefitAccounts = const [];
  List<CreditCardItem> _creditCards = const [];
  List<CategoryItem> _categories = const [];

  String? _incomeAccountId;
  String? _categoryId;
  QuickExpensePaymentState _expensePayment = const QuickExpensePaymentState();
  ReflectionType? _reflectionType;

  String _repeat = 'once';
  DateTime _date = DateTime.now();
  int _dayOfMonth = DateTime.now().day;
  int _monthOfYear = DateTime.now().month;
  int _weekday = DateTime.now().weekday % 7;
  final Set<int> _monthlyDays = <int>{};
  bool _monthlyLastDay = false;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isExpense => widget.initialType == 'expense';
  bool get _isRecurring => _repeat != 'once';
  bool get _canReflect => _isExpense && !_isRecurring;

  CategoryItem? get _selectedCategory {
    final id = _categoryId;
    if (id == null) return null;
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
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
    _bindCategoryRealtime();
    _bindInstrumentRealtime();
    _load();
  }

  @override
  void dispose() {
    _categoryRealtimeBinding?.dispose();
    _instrumentRealtimeBinding?.dispose();
    _description.dispose();
    _amount.dispose();
    _merchant.dispose();
    _reflectionNote.dispose();
    super.dispose();
  }

  void _bindCategoryRealtime() {
    final coordinator = AppRealtimeRegistry.coordinator;
    if (coordinator == null) return;
    _categoryRealtimeBinding = coordinator.bind(
      domain: AppRealtimeDomain.categories,
      onRefresh: _refreshCategories,
    );
  }

  void _bindInstrumentRealtime() {
    final coordinator = AppRealtimeRegistry.coordinator;
    if (coordinator == null) return;
    _instrumentRealtimeBinding = coordinator.bind(
      domain: AppRealtimeDomain.paymentInstruments,
      onRefresh: _refreshPaymentInstruments,
    );
  }

  Future<T> _withTimeout<T>(Future<T> future, String message) {
    return future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(message),
    );
  }

  Future<List<CategoryItem>> _loadCategoryCatalog() {
    return _withTimeout(
      _isExpense
          ? widget.repository.listExpenseCategoryCatalog(widget.space.id)
          : widget.repository.listIncomeCategoryCatalog(widget.space.id),
      'As categorias demoraram demais para carregar.',
    );
  }

  List<CategoryItem> _selectableCategories(List<CategoryItem> categories) {
    return categories.where((category) => category.isSelectable).toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
  }

  String? _defaultCategoryId(List<CategoryItem> categories) {
    if (_isExpense) {
      for (final item in categories) {
        if (item.isParent) return item.id;
      }
    }
    return categories.isEmpty ? null : categories.first.id;
  }

  Future<void> _refreshCategories() async {
    try {
      final selectable = _selectableCategories(await _loadCategoryCatalog());
      if (!mounted) return;

      final currentId = _categoryId;
      final currentStillAvailable = currentId != null &&
          selectable.any((category) => category.id == currentId);
      final nextId = currentStillAvailable
          ? currentId
          : currentId == null
              ? _defaultCategoryId(selectable)
              : null;

      setState(() {
        _categories = selectable;
        _categoryId = nextId;
      });
    } catch (_) {
      // Uma atualização de taxonomia não deve apagar o lançamento em edição.
    }
  }

  Future<void> _refreshPaymentInstruments() async {
    try {
      final accountsFuture = _withTimeout(
        widget.repository.listPaymentAccounts(widget.space.id),
        'As contas demoraram demais para atualizar.',
      );
      final values = _isExpense
          ? await Future.wait<dynamic>([
              accountsFuture,
              _withTimeout(
                widget.repository.listBenefitAccounts(widget.space.id),
                'Os benefícios demoraram demais para atualizar.',
              ),
              _withTimeout(
                widget.repository.listActiveCreditCards(widget.space.id),
                'Os cartões demoraram demais para atualizar.',
              ),
            ])
          : await Future.wait<dynamic>([accountsFuture]);
      if (!mounted) return;

      final accounts = values[0] as List<AccountItem>;
      final benefits = _isExpense
          ? values[1] as List<AccountItem>
          : const <AccountItem>[];
      final cards = _isExpense
          ? values[2] as List<CreditCardItem>
          : const <CreditCardItem>[];
      final currentPayment = _expensePayment;

      String? nextId<T>(
        List<T> items,
        String? current,
        String Function(T item) idOf,
      ) {
        if (current != null && items.any((item) => idOf(item) == current)) {
          return current;
        }
        return items.isEmpty ? null : idOf(items.first);
      }

      setState(() {
        _paymentAccounts = accounts;
        _benefitAccounts = benefits;
        _creditCards = cards;
        _incomeAccountId = nextId(
          accounts,
          _incomeAccountId,
          (item) => item.id,
        );
        _expensePayment = QuickExpensePaymentState(
          type: currentPayment.type,
          accountId: nextId(
            accounts,
            currentPayment.accountId,
            (item) => item.id,
          ),
          cardId: nextId(
            cards,
            currentPayment.cardId,
            (item) => item.id,
          ),
          benefitAccountId: nextId(
            benefits,
            currentPayment.benefitAccountId,
            (item) => item.id,
          ),
          installmentsCount: currentPayment.installmentsCount,
        );
      });
    } catch (_) {
      // Atualizar instrumentos nunca limpa valor, descrição, estabelecimento,
      // reflexão, categoria ou os demais campos do lançamento em edição.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final accountsFuture = _withTimeout(
        widget.repository.listPaymentAccounts(widget.space.id),
        'As contas demoraram demais para carregar.',
      );
      final categoryFuture = _loadCategoryCatalog();

      final values = _isExpense
          ? await Future.wait<dynamic>([
              accountsFuture,
              _withTimeout(
                widget.repository.listBenefitAccounts(widget.space.id),
                'Os benefícios demoraram demais para carregar.',
              ),
              _withTimeout(
                widget.repository.listActiveCreditCards(widget.space.id),
                'Os cartões demoraram demais para carregar.',
              ),
              categoryFuture,
            ])
          : await Future.wait<dynamic>([accountsFuture, categoryFuture]);

      if (!mounted) return;
      final accounts = values[0] as List<AccountItem>;
      final categories = (_isExpense ? values[3] : values[1]) as List<CategoryItem>;
      final selectable = _selectableCategories(categories);
      final defaultCategoryId = _defaultCategoryId(selectable);
      final accountId = accounts.isEmpty ? null : accounts.first.id;

      setState(() {
        _paymentAccounts = accounts;
        _benefitAccounts = _isExpense ? values[1] as List<AccountItem> : const [];
        _creditCards = _isExpense ? values[2] as List<CreditCardItem> : const [];
        _categories = selectable;
        _categoryId = defaultCategoryId;
        _incomeAccountId = accountId;
        _expensePayment = QuickExpensePaymentState(accountId: accountId);
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
    if (_categories.isEmpty) {
      setState(() => _error = 'nenhuma categoria disponível');
      return;
    }

    FocusScope.of(context).unfocus();
    final dialogMode = AppBreakpoints.of(context) != AppLayoutSize.compact;
    final selected = dialogMode
        ? await showDialog<CategoryItem>(
            context: context,
            useRootNavigator: true,
            builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: SizedBox(
                width: AppContentWidths.form,
                height: MediaQuery.sizeOf(dialogContext).height * .82,
                child: CategorySearchPicker(
                  categories: _categories,
                  selectedId: _categoryId,
                  eventType: widget.initialType,
                  dialogMode: true,
                ),
              ),
            ),
          )
        : await showModalBottomSheet<CategoryItem>(
            context: context,
            useRootNavigator: true,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => FractionallySizedBox(
              heightFactor: .86,
              child: CategorySearchPicker(
                categories: _categories,
                selectedId: _categoryId,
                eventType: widget.initialType,
              ),
            ),
          );

    if (selected == null || !mounted) return;
    setState(() {
      _categoryId = selected.id;
      _error = null;
    });
  }

  void _changePaymentType(QuickExpensePaymentType type) {
    setState(() {
      _expensePayment = _expensePayment.select(type);
      if (!_expensePayment.supportsRecurring) _repeat = 'once';
      _error = null;
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
    if (selected == null || !mounted) return;
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

  Future<void> _addMonthlyDay() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(31, (index) {
            final day = index + 1;
            final exists = _monthlyDays.contains(day);
            return ChoiceChip(
              label: Text('$day'),
              selected: exists,
              onSelected: exists
                  ? null
                  : (_) => Navigator.of(sheetContext).pop(day),
            );
          }),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _monthlyDays.add(selected);
      _dayOfMonth = (_monthlyDays.toList()..sort()).first;
    });
  }

  void _changeRepeat(String value) {
    if (_isExpense && !_expensePayment.supportsRecurring) return;
    setState(() {
      _repeat = value;
      if (_isExpense &&
          value != 'once' &&
          _expensePayment.type == QuickExpensePaymentType.creditCard &&
          _expensePayment.installmentsCount != 1) {
        _expensePayment = _expensePayment.withInstallmentsCount(1);
      }
      switch (value) {
        case 'weekly':
        case 'biweekly':
          _weekday = _postgresWeekday(_date);
        case 'monthly':
          if (_monthlyDays.isEmpty) _monthlyDays.add(_date.day);
          _dayOfMonth = (_monthlyDays.toList()..sort()).first;
        case 'yearly':
          _dayOfMonth = _date.day;
          _monthOfYear = _date.month;
        case 'once':
          break;
      }
      _error = null;
    });
  }

  String? _instrumentError() {
    if (!_isExpense) {
      return _incomeAccountId == null ? 'selecione uma conta' : null;
    }
    return switch (_expensePayment.type) {
      QuickExpensePaymentType.account =>
        _expensePayment.accountId == null ? 'selecione uma conta' : null,
      QuickExpensePaymentType.creditCard =>
        _expensePayment.cardId == null ? 'selecione um cartão' : null,
      QuickExpensePaymentType.benefit =>
        _expensePayment.benefitAccountId == null ? 'selecione um benefício' : null,
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = Formatters.parseMoney(_amount.text);
    final description = _description.text.trim();

    if (description.isEmpty) {
      setState(() => _error = 'informe uma descrição');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'informe um valor maior que zero');
      return;
    }
    final instrumentError = _instrumentError();
    if (instrumentError != null) {
      setState(() => _error = instrumentError);
      return;
    }
    if (_categoryId == null) {
      setState(() => _error = 'selecione uma categoria');
      return;
    }
    if (_repeat == 'monthly' && _monthlyDays.isEmpty && !_monthlyLastDay) {
      setState(() => _error = 'escolha pelo menos um dia do mês');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    var reflectionFailed = false;
    try {
      if (_isRecurring) {
        await _registerRecurring(amount, description);
      } else {
        final eventId = await _registerOnce(amount, description);
        if (_canReflect && _reflectionType != null && eventId != null) {
          try {
            await widget.repository.upsertReflection(
              spaceId: widget.space.id,
              eventId: eventId,
              type: _reflectionType!,
              note: _reflectionNote.text,
            );
          } catch (_) {
            reflectionFailed = true;
          }
        }
      }

      if (!mounted) return;
      if (reflectionFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'o lançamento foi salvo, mas a reflexão não pôde ser registrada.',
            ),
          ),
        );
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _registerOnce(num amount, String description) async {
    if (!_isExpense) {
      return widget.repository.registerIncome(
        spaceId: widget.space.id,
        accountId: _incomeAccountId!,
        amount: amount,
        description: description,
        categoryId: _categoryId,
        occurredAt: _date,
      );
    }

    switch (_expensePayment.saveTarget) {
      case QuickExpenseSaveTarget.expense:
        return widget.repository.registerExpense(
          spaceId: widget.space.id,
          accountId: _expensePayment.accountId!,
          amount: amount,
          description: description,
          categoryId: _categoryId,
          occurredAt: _date,
        );
      case QuickExpenseSaveTarget.cardPurchase:
        return widget.repository.registerCardPurchase(
          spaceId: widget.space.id,
          cardId: _expensePayment.cardId!,
          totalAmount: amount,
          description: description,
          installmentsCount: _expensePayment.installmentsCount,
          categoryId: _categoryId,
          purchaseAt: _date,
          merchant: _merchant.text,
        );
      case QuickExpenseSaveTarget.benefitExpense:
        return widget.repository.registerBenefit(
          spaceId: widget.space.id,
          accountId: _expensePayment.benefitAccountId!,
          amount: amount,
          description: description,
          isCredit: false,
          categoryId: _categoryId,
          occurredAt: _date,
        );
    }
  }

  Future<void> _registerRecurring(num amount, String description) async {
    if (_isExpense && !_expensePayment.supportsRecurring) {
      throw StateError('Recorrência não disponível para este meio de pagamento.');
    }

    final accountId = _isExpense
        ? _expensePayment.recurringAccountId
        : _incomeAccountId;
    final cardId = _isExpense ? _expensePayment.recurringCardId : null;

    if (accountId == null && cardId == null) {
      throw StateError(_isExpense ? 'Selecione uma conta ou cartão.' : 'Selecione uma conta.');
    }

    final monthlyDays = _repeat == 'monthly'
        ? (_monthlyDays.toList()..sort())
        : null;

    await widget.repository.createRecurringItem(
      spaceId: widget.space.id,
      name: description,
      itemType: widget.initialType,
      amount: amount,
      frequency: _repeat,
      accountId: accountId,
      cardId: cardId,
      categoryId: _categoryId,
      dayOfMonth: _repeat == 'monthly' || _repeat == 'yearly'
          ? _dayOfMonth
          : null,
      monthlyDays: monthlyDays,
      monthlyLastDay: _repeat == 'monthly' ? _monthlyLastDay : false,
      weekday: _repeat == 'weekly' || _repeat == 'biweekly' ? _weekday : null,
      monthOfYear: _repeat == 'yearly' ? _monthOfYear : null,
      startsOn: _date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * .92;
    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppContentWidths.form, maxHeight: maxHeight),
        child: Material(
          color: AppColors.surface(brightness),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(28),
            bottom: compact ? Radius.zero : const Radius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: _loading
                ? const SizedBox(
                    height: 340,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      14,
                      20,
                      media.viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(brightness),
                        const SizedBox(height: 22),
                        _moneyField(),
                        const SizedBox(height: 14),
                        _categoryField(brightness),
                        const SizedBox(height: 18),
                        _paymentSection(brightness),
                        const SizedBox(height: 18),
                        _detailsSection(),
                        if (_canReflect) ...[
                          const SizedBox(height: 20),
                          _reflectionSection(brightness),
                        ],
                        const SizedBox(height: 20),
                        _recurrenceSection(brightness),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: AppTypography.body(
                              context,
                              fontSize: 11,
                              color: AppColors.expenseText(brightness),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.lime,
                            foregroundColor: AppColors.iconOnLime,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_isRecurring ? 'salvar recorrência' : 'salvar lançamento'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _header(Brightness brightness) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isExpense ? 'novo gasto' : 'nova receita',
                style: AppTypography.section(
                  context,
                  fontSize: 20,
                  color: AppColors.primaryText(brightness),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isExpense
                    ? 'registre primeiro. reflita só se fizer sentido.'
                    : 'registre o que entrou sem complicação.',
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: AppColors.secondaryText(brightness),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'fechar',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(AppIcons.close),
        ),
      ],
    );
  }

  Widget _moneyField() {
    return TextField(
      controller: _amount,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTypography.money(context, fontSize: 26),
      decoration: const InputDecoration(
        labelText: 'valor',
        prefixText: 'R\$ ',
        hintText: '0,00',
      ),
    );
  }

  Widget _categoryField(Brightness brightness) {
    final selected = _selectedCategory;
    final family = selected?.parentName ?? selected?.name ?? 'A classificar';
    final visual = CategoryVisuals.resolve(
      brightness: brightness,
      category: family,
      subcategory: selected?.parentName == null ? null : selected?.name,
      eventType: widget.initialType,
      systemKey: selected?.systemKey,
      colorHex: selected?.isSystem == false ? selected?.colorHex : null,
      iconKey: selected?.isSystem == false ? selected?.iconKey : null,
    );

    return InkWell(
      onTap: _pickCategory,
      borderRadius: BorderRadius.circular(AppRadii.compactCard),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.compactCard),
          border: Border.all(color: AppColors.border(brightness)),
        ),
        child: Row(
          children: [
            CategoryIconBadge(
              icon: visual.icon,
              color: visual.color,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'categoria',
                    style: AppTypography.label(
                      context,
                      fontSize: 9,
                      color: AppColors.secondaryText(brightness),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selected?.breadcrumb ?? 'selecionar',
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText(brightness),
                    ),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, color: AppColors.secondaryText(brightness)),
          ],
        ),
      ),
    );
  }

  Widget _paymentSection(Brightness brightness) {
    if (!_isExpense) {
      return DropdownButtonFormField<String>(
        initialValue: _incomeAccountId,
        decoration: const InputDecoration(labelText: 'conta que recebeu'),
        items: _paymentAccounts
            .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
            .toList(),
        onChanged: (value) => setState(() => _incomeAccountId = value),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'como pagou?',
          style: AppTypography.body(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText(brightness),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _paymentChip(QuickExpensePaymentType.account, 'conta', AppIcons.account),
            _paymentChip(QuickExpensePaymentType.creditCard, 'cartão', AppIcons.creditCard),
            _paymentChip(QuickExpensePaymentType.benefit, 'benefício', AppIcons.benefit),
          ],
        ),
        const SizedBox(height: 12),
        switch (_expensePayment.type) {
          QuickExpensePaymentType.account => DropdownButtonFormField<String>(
              initialValue: _paymentAccounts.any((e) => e.id == _expensePayment.accountId)
                  ? _expensePayment.accountId
                  : null,
              decoration: const InputDecoration(labelText: 'conta'),
              items: _paymentAccounts
                  .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                  .toList(),
              onChanged: (value) => setState(
                () => _expensePayment = _expensePayment.withAccountId(value),
              ),
            ),
          QuickExpensePaymentType.creditCard => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _creditCards.any((e) => e.id == _expensePayment.cardId)
                      ? _expensePayment.cardId
                      : null,
                  decoration: const InputDecoration(labelText: 'cartão'),
                  items: _creditCards
                      .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                      .toList(),
                  onChanged: (value) => setState(
                    () => _expensePayment = _expensePayment.withCardId(value),
                  ),
                ),
                const SizedBox(height: 10),
                if (_isRecurring)
                  Text(
                    'cada ocorrência será lançada como uma compra 1x no cartão.',
                    style: AppTypography.label(
                      context,
                      fontSize: 9,
                      color: AppColors.secondaryText(brightness),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'parcelas',
                          style: AppTypography.body(context, fontSize: 11),
                        ),
                      ),
                      IconButton(
                        onPressed: _expensePayment.installmentsCount <= 1
                            ? null
                            : () => setState(() {
                                _expensePayment = _expensePayment.withInstallmentsCount(
                                  _expensePayment.installmentsCount - 1,
                                );
                              }),
                        icon: const Icon(AppIcons.delete, size: 17),
                      ),
                      Text('${_expensePayment.installmentsCount}x'),
                      IconButton(
                        onPressed: _expensePayment.installmentsCount >= cardPurchaseMaxInstallments
                            ? null
                            : () => setState(() {
                                _expensePayment = _expensePayment.withInstallmentsCount(
                                  _expensePayment.installmentsCount + 1,
                                );
                              }),
                        icon: const Icon(AppIcons.add, size: 18),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _merchant,
                    decoration: const InputDecoration(
                      labelText: 'estabelecimento',
                      hintText: 'opcional',
                    ),
                  ),
                ],
              ],
            ),
          QuickExpensePaymentType.benefit => DropdownButtonFormField<String>(
              initialValue: _benefitAccounts.any(
                (e) => e.id == _expensePayment.benefitAccountId,
              )
                  ? _expensePayment.benefitAccountId
                  : null,
              decoration: const InputDecoration(labelText: 'benefício'),
              items: _benefitAccounts
                  .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                  .toList(),
              onChanged: (value) => setState(
                () => _expensePayment = _expensePayment.withBenefitAccountId(value),
              ),
            ),
        },
      ],
    );
  }

  Widget _paymentChip(QuickExpensePaymentType type, String label, IconData icon) {
    return ChoiceChip(
      selected: _expensePayment.type == type,
      avatar: Icon(icon, size: 17),
      label: Text(label),
      onSelected: (_) => _changePaymentType(type),
    );
  }

  Widget _detailsSection() {
    return Column(
      children: [
        TextField(
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'descrição',
            hintText: 'ex.: almoço, mercado, curso',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(AppIcons.calendar, size: 18),
          label: Text(_formatDate(_date)),
        ),
      ],
    );
  }

  Widget _reflectionSection(Brightness brightness) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.background(brightness).withValues(alpha: .45),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'como esse gasto se encaixa pra você?',
            style: AppTypography.body(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'opcional · não muda seu saldo, categoria ou orçamento',
            style: AppTypography.label(
              context,
              fontSize: 9,
              color: AppColors.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: ReflectionType.values.map((type) {
              final selected = _reflectionType == type;
              final color = ReflectionVisuals.foreground(type, brightness);
              return ChoiceChip(
                selected: selected,
                avatar: Icon(ReflectionVisuals.icon(type), size: 15, color: color),
                label: Text(type.label),
                onSelected: (_) => setState(() {
                  _reflectionType = selected ? null : type;
                  if (_reflectionType == null) _reflectionNote.clear();
                }),
                selectedColor: ReflectionVisuals.background(type, brightness),
                side: BorderSide(
                  color: selected
                      ? ReflectionVisuals.border(type, brightness)
                      : AppColors.border(brightness),
                ),
              );
            }).toList(),
          ),
          if (_reflectionType != null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _reflectionNote,
              maxLength: 300,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'nota opcional',
                hintText: 'quer lembrar alguma coisa sobre esse gasto?',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recurrenceSection(Brightness brightness) {
    final available = !_isExpense || _expensePayment.supportsRecurring;
    if (!available) {
      return Text(
        'recorrência não está disponível para benefícios.',
        style: AppTypography.label(
          context,
          fontSize: 9,
          color: AppColors.secondaryText(brightness),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'repetição',
          style: AppTypography.body(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: const <(String, String)>[
            ('once', 'uma vez'),
            ('weekly', 'semanal'),
            ('biweekly', 'quinzenal'),
            ('monthly', 'mensal'),
            ('yearly', 'anual'),
          ].map((item) {
            return ChoiceChip(
              selected: _repeat == item.$1,
              label: Text(item.$2),
              onSelected: (_) => _changeRepeat(item.$1),
            );
          }).toList(),
        ),
        if (_repeat == 'monthly') ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...(_monthlyDays.toList()..sort()).map(
                (day) => InputChip(
                  label: Text('dia $day'),
                  onDeleted: _monthlyDays.length == 1 && !_monthlyLastDay
                      ? null
                      : () => setState(() => _monthlyDays.remove(day)),
                ),
              ),
              ActionChip(
                avatar: const Icon(AppIcons.add, size: 15),
                label: const Text('outro dia'),
                onPressed: _addMonthlyDay,
              ),
              FilterChip(
                selected: _monthlyLastDay,
                label: const Text('último dia'),
                onSelected: (value) => setState(() => _monthlyLastDay = value),
              ),
            ],
          ),
        ],
      ],
    );
  }

  int _postgresWeekday(DateTime date) => date.weekday % 7;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
