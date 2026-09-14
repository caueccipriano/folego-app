import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/credit_card_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';
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

  List<AccountItem> _paymentAccounts = const [];
  List<AccountItem> _benefitAccounts = const [];
  List<CreditCardItem> _creditCards = const [];
  List<CategoryItem> _categories = const [];

  String? _incomeAccountId;
  String? _categoryId;
  QuickExpensePaymentState _expensePayment = const QuickExpensePaymentState();

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
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _merchant.dispose();
    super.dispose();
  }

  Future<T> _withTimeout<T>(Future<T> future, String message) {
    return future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(message),
    );
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
      final categoryFuture = _withTimeout(
        _isExpense
            ? widget.repository.listExpenseCategoryCatalog(widget.space.id)
            : widget.repository.listIncomeCategoryCatalog(widget.space.id),
        'As categorias demoraram demais para carregar.',
      );

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
          : await Future.wait<dynamic>([
              accountsFuture,
              categoryFuture,
            ]);

      if (!mounted) return;

      final accounts = values[0] as List<AccountItem>;
      final categories = (_isExpense ? values[3] : values[1]) as List<CategoryItem>;
      final selectable = categories.where((category) => category.isSelectable).toList();
      selectable.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.name.compareTo(b.name);
      });

      String? defaultCategoryId;
      if (_isExpense) {
        for (final item in selectable) {
          if (item.isParent) {
            defaultCategoryId = item.id;
            break;
          }
        }
      }
      defaultCategoryId ??= selectable.isEmpty ? null : selectable.first.id;

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
    final layout = AppBreakpoints.of(context);
    final dialogMode = layout != AppLayoutSize.compact;

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
      if (type == QuickExpensePaymentType.benefit) {
        final now = DateTime.now();
        _date = DateTime(now.year, now.month, now.day);
      }
      _error = null;
    });
  }

  void _changeInstallments(int delta) {
    final next = (_expensePayment.installmentsCount + delta)
        .clamp(cardPurchaseMinInstallments, cardPurchaseMaxInstallments)
        .toInt();
    if (next == _expensePayment.installmentsCount) return;
    setState(() {
      _expensePayment = _expensePayment.withInstallmentsCount(next);
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    if (_isExpense && _expensePayment.type == QuickExpensePaymentType.benefit) {
      return;
    }
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
              onSelected: exists ? null : (_) => Navigator.of(sheetContext).pop(day),
            );
          }),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _monthlyDays.add(selected);
      final sorted = _monthlyDays.toList()..sort();
      _dayOfMonth = sorted.first;
    });
  }

  void _changeRepeat(String value) {
    if (_isExpense && !_expensePayment.supportsRecurring) return;
    setState(() {
      _repeat = value;
      switch (value) {
        case 'weekly':
        case 'biweekly':
          _weekday = _postgresWeekday(_date);
          break;
        case 'monthly':
          if (_monthlyDays.isEmpty) _monthlyDays.add(_date.day);
          _dayOfMonth = (_monthlyDays.toList()..sort()).first;
          break;
        case 'yearly':
          _dayOfMonth = _date.day;
          _monthOfYear = _date.month;
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

    try {
      if (_isRecurring) {
        await _registerRecurring(amount, description);
      } else {
        await _registerOnce(amount, description);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _registerOnce(num amount, String description) async {
    if (!_isExpense) {
      await widget.repository.registerIncome(
        spaceId: widget.space.id,
        accountId: _incomeAccountId!,
        amount: amount,
        description: description,
        categoryId: _categoryId,
        occurredAt: _date,
      );
      return;
    }

    switch (_expensePayment.saveTarget) {
      case QuickExpenseSaveTarget.expense:
        await widget.repository.registerExpense(
          spaceId: widget.space.id,
          accountId: _expensePayment.accountId!,
          amount: amount,
          description: description,
          categoryId: _categoryId,
          occurredAt: _date,
        );
        return;
      case QuickExpenseSaveTarget.cardPurchase:
        await widget.repository.registerCardPurchase(
          spaceId: widget.space.id,
          cardId: _expensePayment.cardId!,
          totalAmount: amount,
          description: description,
          installmentsCount: _expensePayment.installmentsCount,
          categoryId: _categoryId,
          purchaseAt: _date,
          merchant: _merchant.text,
        );
        return;
      case QuickExpenseSaveTarget.benefitExpense:
        await widget.repository.registerBenefit(
          spaceId: widget.space.id,
          accountId: _expensePayment.benefitAccountId!,
          amount: amount,
          description: description,
          isCredit: false,
          categoryId: _categoryId,
        );
        return;
    }
  }

  Future<void> _registerRecurring(num amount, String description) async {
    if (_isExpense && !_expensePayment.supportsRecurring) {
      throw StateError('Recorrência não disponível para este meio de pagamento.');
    }
    final accountId = _isExpense ? _expensePayment.accountId : _incomeAccountId;
    if (accountId == null) throw StateError('Selecione uma conta.');

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
      categoryId: _categoryId,
      dayOfMonth: _repeat == 'monthly' || _repeat == 'yearly' ? _dayOfMonth : null,
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
    final viewport = media.size;
    final layout = AppBreakpoints.of(context);
    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final accent = _isExpense ? AppColors.lime : AppColors.positiveText(brightness);
    final maxWidth = layout == AppLayoutSize.compact
        ? viewport.width
        : AppContentWidths.form;
    final horizontal = AppResponsiveSpacing.horizontalForWidth(viewport.width);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: viewport.height * .94),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(top: BorderSide(color: border)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                14,
                horizontal,
                media.viewInsets.bottom + 18,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 320,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
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
                              CategoryIconBadge(
                                icon: _isExpense ? AppIcons.expense : AppIcons.income,
                                color: accent,
                                size: 52,
                                iconSize: 25,
                                radius: 17,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isExpense ? 'novo gasto' : 'nova receita',
                                      style: AppTypography.section(
                                        context,
                                        fontSize: 21,
                                        color: primaryText,
                                      ),
                                    ),
                                    Text(
                                      _isExpense ? 'registre uma saída' : 'registre uma entrada',
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
                          _Panel(
                            child: TextField(
                              controller: _amount,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: AppTypography.money(context, fontSize: 30, color: primaryText),
                              decoration: const InputDecoration(
                                labelText: 'quanto?',
                                prefixText: 'R\$ ',
                                hintText: '0,00',
                              ),
                              onChanged: (_) => _clearError(),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _SectionLabel(
                            title: 'categoria',
                            subtitle: _isExpense
                                ? 'escolha pela árvore ou busque direto'
                                : 'de onde esse dinheiro veio',
                          ),
                          const SizedBox(height: 9),
                          _CategoryTile(
                            category: _selectedCategory,
                            eventType: widget.initialType,
                            onTap: _pickCategory,
                          ),
                          if (_isExpense) ...[
                            const SizedBox(height: 22),
                            const _SectionLabel(
                              title: 'como pagou?',
                              subtitle: 'conta, cartão ou benefício',
                            ),
                            const SizedBox(height: 9),
                            _Panel(
                              child: Column(
                                children: [
                                  _PaymentSelector(
                                    selected: _expensePayment.type,
                                    onSelected: _changePaymentType,
                                  ),
                                  const SizedBox(height: 14),
                                  _paymentFields(primaryText, secondaryText),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const _SectionLabel(
                            title: 'detalhes',
                            subtitle: 'o básico para lembrar depois',
                          ),
                          const SizedBox(height: 9),
                          _Panel(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _description,
                                  textCapitalization: TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    labelText: 'descrição',
                                    hintText: _isExpense
                                        ? 'ex.: jantar com amigos'
                                        : 'ex.: salário',
                                  ),
                                  onChanged: (_) => _clearError(),
                                ),
                                if (!_isExpense) ...[
                                  const SizedBox(height: 12),
                                  _accountDropdown(
                                    value: _incomeAccountId,
                                    label: 'conta',
                                    accounts: _paymentAccounts,
                                    onChanged: (value) => setState(() => _incomeAccountId = value),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _DateTile(
                                  value: _isExpense &&
                                          _expensePayment.type == QuickExpensePaymentType.benefit
                                      ? 'hoje · definida pelo benefício'
                                      : _formatDate(_date),
                                  onTap: _isExpense &&
                                          _expensePayment.type == QuickExpensePaymentType.benefit
                                      ? null
                                      : _pickDate,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _SectionLabel(
                            title: 'repetição',
                            subtitle: 'é uma vez só ou faz parte da rotina?',
                          ),
                          const SizedBox(height: 9),
                          _buildRecurrencePanel(primaryText, secondaryText),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: AppColors.expenseText(brightness).withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: AppColors.expenseText(brightness).withValues(alpha: .20),
                                ),
                              ),
                              child: Text(
                                _error!,
                                style: AppTypography.body(
                                  context,
                                  fontSize: 12,
                                  color: AppColors.expenseText(brightness),
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
                                  : Text(_isExpense ? 'registrar gasto' : 'registrar receita'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentFields(Color primaryText, Color secondaryText) {
    switch (_expensePayment.type) {
      case QuickExpensePaymentType.account:
        return _accountDropdown(
          value: _expensePayment.accountId,
          label: 'conta',
          accounts: _paymentAccounts,
          empty: 'Nenhuma conta disponível',
          onChanged: (value) {
            setState(() => _expensePayment = _expensePayment.withAccountId(value));
          },
        );
      case QuickExpensePaymentType.creditCard:
        if (_creditCards.isEmpty) return const _EmptyState('Nenhum cartão cadastrado');
        return Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _expensePayment.cardId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'cartão'),
              items: _creditCards
                  .map(
                    (card) => DropdownMenuItem(
                      value: card.id,
                      child: Text(_cardLabel(card), overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _expensePayment = _expensePayment.withCardId(value));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _merchant,
              decoration: const InputDecoration(
                labelText: 'estabelecimento',
                hintText: 'opcional',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'parcelas · ${_expensePayment.installmentsCount}x',
                    style: AppTypography.body(context, fontSize: 12, color: primaryText),
                  ),
                ),
                IconButton(
                  onPressed: _expensePayment.installmentsCount > cardPurchaseMinInstallments
                      ? () => _changeInstallments(-1)
                      : null,
                  icon: const Text('−'),
                ),
                IconButton(
                  onPressed: _expensePayment.installmentsCount < cardPurchaseMaxInstallments
                      ? () => _changeInstallments(1)
                      : null,
                  icon: const Text('+'),
                ),
              ],
            ),
          ],
        );
      case QuickExpensePaymentType.benefit:
        return _accountDropdown(
          value: _expensePayment.benefitAccountId,
          label: 'benefício',
          accounts: _benefitAccounts,
          empty: 'Nenhum benefício cadastrado',
          onChanged: (value) {
            setState(
              () => _expensePayment = _expensePayment.withBenefitAccountId(value),
            );
          },
        );
    }
  }

  Widget _accountDropdown({
    required String? value,
    required String label,
    required List<AccountItem> accounts,
    required ValueChanged<String?> onChanged,
    String empty = 'Nenhuma conta disponível',
  }) {
    if (accounts.isEmpty) return _EmptyState(empty);
    final safeValue = accounts.any((item) => item.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: accounts
          .map(
            (account) => DropdownMenuItem(
              value: account.id,
              child: Text(account.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildRecurrencePanel(Color primaryText, Color secondaryText) {
    if (_isExpense && !_expensePayment.supportsRecurring) {
      return const _Panel(
        child: _EmptyState(
          'Cartão e benefício ficam como “uma vez” até a realização recorrente canônica estar pronta.',
        ),
      );
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _repeat,
            decoration: const InputDecoration(labelText: 'repete?'),
            items: const [
              DropdownMenuItem(value: 'once', child: Text('uma vez')),
              DropdownMenuItem(value: 'weekly', child: Text('toda semana')),
              DropdownMenuItem(value: 'biweekly', child: Text('a cada 2 semanas')),
              DropdownMenuItem(value: 'monthly', child: Text('todo mês')),
              DropdownMenuItem(value: 'yearly', child: Text('todo ano')),
            ],
            onChanged: (value) {
              if (value != null) _changeRepeat(value);
            },
          ),
          if (_repeat == 'weekly') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              decoration: const InputDecoration(labelText: 'dia da semana'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('domingo')),
                DropdownMenuItem(value: 1, child: Text('segunda-feira')),
                DropdownMenuItem(value: 2, child: Text('terça-feira')),
                DropdownMenuItem(value: 3, child: Text('quarta-feira')),
                DropdownMenuItem(value: 4, child: Text('quinta-feira')),
                DropdownMenuItem(value: 5, child: Text('sexta-feira')),
                DropdownMenuItem(value: 6, child: Text('sábado')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _weekday = value);
              },
            ),
          ],
          if (_repeat == 'monthly') ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...(_monthlyDays.toList()..sort()).map(
                  (day) => InputChip(
                    label: Text('dia $day'),
                    onDeleted: () => setState(() => _monthlyDays.remove(day)),
                  ),
                ),
                ChoiceChip(
                  label: const Text('último dia'),
                  selected: _monthlyLastDay,
                  onSelected: (selected) => setState(() => _monthlyLastDay = selected),
                ),
                ActionChip(
                  avatar: const Icon(AppIcons.add, size: 16),
                  label: const Text('outro dia'),
                  onPressed: _addMonthlyDay,
                ),
              ],
            ),
          ],
          if (_repeat == 'yearly') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _dayOfMonth,
                    decoration: const InputDecoration(labelText: 'dia'),
                    items: List.generate(
                      31,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) setState(() => _dayOfMonth = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _monthOfYear,
                    decoration: const InputDecoration(labelText: 'mês'),
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) setState(() => _monthOfYear = value);
                    },
                  ),
                ),
              ],
            ),
          ],
          if (_repeat == 'biweekly') ...[
            const SizedBox(height: 10),
            Text(
              'repete a cada 14 dias a partir da data escolhida',
              style: AppTypography.body(context, fontSize: 11, color: secondaryText),
            ),
          ],
        ],
      ),
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  int _postgresWeekday(DateTime date) => date.weekday % 7;

  String _cardLabel(CreditCardItem card) {
    final details = <String>[
      if (card.brand != null) card.brand!,
      if (card.lastFour != null) 'final ${card.lastFour}',
      if (card.issuer != null && card.issuer != card.brand) card.issuer!,
    ];
    return details.isEmpty ? card.name : '${card.name} · ${details.join(' · ')}';
  }

  String _formatDate(DateTime date) {
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
    if (text.contains('invalid_installments_count')) {
      return 'a quantidade de parcelas não é válida';
    }
    if (text.contains('invalid_card')) return 'selecione um cartão válido';
    if (text.contains('invalid_benefit_account')) return 'selecione um benefício válido';
    if (error is TimeoutException) return error.message ?? 'demorou demais para carregar';
    return text
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.eventType,
    required this.onTap,
  });

  final CategoryItem? category;
  final String eventType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final item = category;
    final parent = item?.parentName;
    final visual = CategoryVisuals.resolve(
      brightness: brightness,
      category: parent ?? item?.name,
      subcategory: parent == null ? null : item?.name,
      eventType: eventType,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface(brightness),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(brightness)),
          ),
          child: Row(
            children: [
              CategoryIconBadge(
                icon: visual.icon,
                color: visual.color,
                size: 42,
                iconSize: 21,
                radius: 13,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item?.breadcrumb ?? 'selecionar categoria',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'toque para buscar ou trocar',
                      style: AppTypography.label(
                        context,
                        fontSize: 9,
                        color: AppColors.secondaryText(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AppIcons.search,
                size: 18,
                color: AppColors.secondaryText(brightness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({required this.selected, required this.onSelected});
  final QuickExpensePaymentType selected;
  final ValueChanged<QuickExpensePaymentType> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <(QuickExpensePaymentType, String, IconData)>[
      (QuickExpensePaymentType.account, 'Conta', AppIcons.account),
      (QuickExpensePaymentType.creditCard, 'Cartão', AppIcons.creditCard),
      (QuickExpensePaymentType.benefit, 'Benefício', AppIcons.benefit),
    ];
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: ChoiceChip(
              avatar: Icon(options[i].$3, size: 17),
              label: Text(options[i].$2),
              selected: selected == options[i].$1,
              onSelected: (_) => onSelected(options[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.value, required this.onTap});
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(AppIcons.calendar),
      title: const Text('data'),
      subtitle: Text(value),
      trailing: onTap == null ? null : const Icon(AppIcons.chevronRight),
      onTap: onTap,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: AppTypography.body(
          context,
          fontSize: 11,
          color: AppColors.secondaryText(Theme.of(context).brightness),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
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
