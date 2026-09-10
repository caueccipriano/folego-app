import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/onboarding_state.dart';
import '../../data/repositories/folego_repository.dart';
import '../../shared/widgets/section_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.space,
    required this.repository,
    required this.initialState,
    required this.onCompleted,
  });

  final FinancialSpace space;
  final FolegoRepository repository;
  final OnboardingState initialState;
  final Future<void> Function() onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _titles = [
    'Seu dinheiro hoje',
    'Quando você recebe?',
    'Contas antes de receber',
    'Dinheiro protegido',
    'Seu cartão',
    'Seu orçamento',
  ];

  int _step = 0;
  bool _busy = false;
  String? _error;
  late OnboardingState _state;
  List<AccountItem> _accounts = const [];
  List<CategoryItem> _categories = const [];

  String? _selectedAccountId;
  String? _recurringCategoryId;
  String? _budgetCategoryId;
  DateTime? _invoiceDueDate;

  final _accountName = TextEditingController(text: 'Conta principal');
  final _institution = TextEditingController();
  final _openingBalance = TextEditingController();

  final _incomeName = TextEditingController(text: 'Salário');
  final _incomeAmount = TextEditingController();
  final _incomeDay = TextEditingController(text: '15');

  final _recurringName = TextEditingController(text: 'Aluguel');
  final _recurringAmount = TextEditingController();
  final _recurringDay = TextEditingController(text: '10');

  final _reserveBalance = TextEditingController();

  final _cardName = TextEditingController(text: 'Meu cartão');
  final _cardIssuer = TextEditingController();
  final _cardClosingDay = TextEditingController(text: '23');
  final _cardDueDay = TextEditingController(text: '5');
  final _cardInvoice = TextEditingController();

  final _budgetAmount = TextEditingController();

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    if (!_state.hasAccount) {
      _step = 0;
    } else if (!_state.hasConfirmedIncome) {
      _step = 1;
    } else {
      _step = 2;
    }
    _loadReferenceData();
  }

  @override
  void dispose() {
    for (final controller in [
      _accountName,
      _institution,
      _openingBalance,
      _incomeName,
      _incomeAmount,
      _incomeDay,
      _recurringName,
      _recurringAmount,
      _recurringDay,
      _reserveBalance,
      _cardName,
      _cardIssuer,
      _cardClosingDay,
      _cardDueDay,
      _cardInvoice,
      _budgetAmount,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    try {
      final results = await Future.wait([
        widget.repository.listAccounts(widget.space.id),
        widget.repository.listExpenseCategories(widget.space.id),
      ]);
      if (!mounted) return;
      final accounts = results[0] as List<AccountItem>;
      final categories = results[1] as List<CategoryItem>;
      setState(() {
        _accounts = accounts;
        _categories = categories;
        _selectedAccountId ??= accounts.isEmpty ? null : accounts.first.id;
        _recurringCategoryId ??= categories.isEmpty ? null : categories.first.id;
        final discretionary = categories.where((item) => !item.essential).toList();
        _budgetCategoryId ??= discretionary.isNotEmpty
            ? discretionary.first.id
            : (categories.isEmpty ? null : categories.first.id);
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _refreshState() async {
    final state = await widget.repository.getOnboardingState(widget.space.id);
    if (!mounted) return;
    setState(() => _state = state);
    await _loadReferenceData();
  }

  void _next() {
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(0, _titles.length - 1).toInt();
    });
  }

  void _previous() {
    setState(() {
      _error = null;
      _step = (_step - 1).clamp(0, _titles.length - 1).toInt();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAccount() => _run(() async {
        if (_accountName.text.trim().isEmpty) {
          throw const FormatException('Dê um nome para sua conta.');
        }
        final balance = Formatters.parseMoney(_openingBalance.text);
        await widget.repository.createOnboardingAccount(
          spaceId: widget.space.id,
          name: _accountName.text.trim(),
          institution: _institution.text.trim().isEmpty ? null : _institution.text.trim(),
          openingBalance: balance,
          balanceDate: DateTime.now(),
        );
        await _refreshState();
        _next();
      });

  Future<void> _saveIncome() => _run(() async {
        if (_selectedAccountId == null) {
          throw const FormatException('Selecione a conta em que você recebe.');
        }
        final amount = Formatters.parseMoney(_incomeAmount.text);
        final day = int.tryParse(_incomeDay.text.trim()) ?? 0;
        if (amount <= 0) throw const FormatException('Informe quanto você recebe.');
        if (day < 1 || day > 31) throw const FormatException('Informe um dia entre 1 e 31.');
        await widget.repository.configureIncome(
          spaceId: widget.space.id,
          name: _incomeName.text.trim().isEmpty ? 'Recebimento' : _incomeName.text.trim(),
          amount: amount,
          dayOfMonth: day,
          accountId: _selectedAccountId!,
          startsOn: DateTime.now(),
        );
        await _refreshState();
        _next();
      });

  Future<void> _saveRecurring() => _run(() async {
        final amount = Formatters.parseMoney(_recurringAmount.text);
        if (amount <= 0) {
          _next();
          return;
        }
        if (_selectedAccountId == null || _recurringCategoryId == null) {
          throw const FormatException('Selecione conta e categoria.');
        }
        final day = int.tryParse(_recurringDay.text.trim()) ?? 0;
        if (day < 1 || day > 31) throw const FormatException('Informe um dia entre 1 e 31.');
        await widget.repository.configureRecurringExpense(
          spaceId: widget.space.id,
          name: _recurringName.text.trim().isEmpty ? 'Conta fixa' : _recurringName.text.trim(),
          amount: amount,
          dayOfMonth: day,
          categoryId: _recurringCategoryId!,
          accountId: _selectedAccountId!,
          startsOn: DateTime.now(),
        );
        await _refreshState();
        _next();
      });

  Future<void> _saveReserve() => _run(() async {
        final amount = Formatters.parseMoney(_reserveBalance.text);
        if (amount > 0 && !_state.reserveConfigured) {
          await widget.repository.createOnboardingAccount(
            spaceId: widget.space.id,
            name: 'Reserva',
            openingBalance: amount,
            balanceDate: DateTime.now(),
            type: 'reserve',
            availableForSpending: false,
          );
          await _refreshState();
        }
        _next();
      });

  Future<void> _saveCard() => _run(() async {
        final invoice = Formatters.parseMoney(_cardInvoice.text);
        if (_cardName.text.trim().isEmpty && invoice <= 0) {
          _next();
          return;
        }
        if (_selectedAccountId == null) {
          throw const FormatException('Selecione a conta que paga a fatura.');
        }
        final closing = int.tryParse(_cardClosingDay.text.trim()) ?? 0;
        final due = int.tryParse(_cardDueDay.text.trim()) ?? 0;
        if (closing < 1 || closing > 31 || due < 1 || due > 31) {
          throw const FormatException('Fechamento e vencimento devem estar entre 1 e 31.');
        }
        if (invoice > 0 && _invoiceDueDate == null) {
          throw const FormatException('Informe o vencimento da fatura atual.');
        }
        await widget.repository.createCard(
          spaceId: widget.space.id,
          name: _cardName.text.trim().isEmpty ? 'Cartão' : _cardName.text.trim(),
          closingDay: closing,
          dueDay: due,
          paymentAccountId: _selectedAccountId!,
          issuer: _cardIssuer.text.trim().isEmpty ? null : _cardIssuer.text.trim(),
          currentInvoiceBalance: invoice,
          currentInvoiceDueDate: _invoiceDueDate,
        );
        await _refreshState();
        _next();
      });

  Future<void> _finish() => _run(() async {
        final amount = Formatters.parseMoney(_budgetAmount.text);
        if (amount > 0 && _budgetCategoryId != null) {
          await widget.repository.setBudgetItem(
            spaceId: widget.space.id,
            periodMonth: DateTime.now(),
            categoryId: _budgetCategoryId!,
            plannedAmount: amount,
          );
        }
        await widget.repository.completeOnboarding(widget.space.id);
        await widget.onCompleted();
      });

  Future<void> _pickInvoiceDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: _invoiceDueDate ?? now.add(const Duration(days: 10)),
    );
    if (selected != null && mounted) setState(() => _invoiceDueDate = selected);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / _titles.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fôlego'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => widget.repository.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: progress, minHeight: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  Text('Passo ${_step + 1} de ${_titles.length}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 6),
                  Text(_titles[_step], style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(_subtitleForStep(), style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45)),
                  const SizedBox(height: 22),
                  SectionCard(child: _stepContent()),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 20),
                  _primaryButton(),
                  if (_isOptionalStep()) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: _busy ? null : _next, child: const Text('Pular por enquanto')),
                  ],
                  if (_step > 0) TextButton(onPressed: _busy ? null : _previous, child: const Text('Voltar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleForStep() {
    switch (_step) {
      case 0:
        return 'Começamos pelo dinheiro que já está disponível em uma conta sua.';
      case 1:
        return 'O Fôlego precisa saber qual é o próximo recebimento confiável para calcular até onde seu dinheiro precisa durar.';
      case 2:
        return 'Inclua uma conta fixa que vence antes do próximo recebimento. Você poderá cadastrar outras depois.';
      case 3:
        return 'Reserva existe no seu patrimônio, mas não deve aparecer como dinheiro livre para gastar.';
      case 4:
        return 'Se já existe uma fatura em aberto, informe o saldo atual para o cálculo começar certo desde o primeiro dia.';
      default:
        return 'Defina um limite para uma categoria variável. Isso faz o Fôlego respeitar não só seu caixa, mas também seu plano mensal.';
    }
  }

  bool _isOptionalStep() => _step >= 2 && _step <= 4;

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return Column(children: [
          _field(_accountName, 'Nome da conta', hint: 'Ex.: Santander'),
          const SizedBox(height: 12),
          _field(_institution, 'Banco / instituição', hint: 'Opcional'),
          const SizedBox(height: 12),
          _moneyField(_openingBalance, 'Saldo disponível hoje'),
          const SizedBox(height: 10),
          const _Hint(text: 'Saldo inicial não será tratado como receita. Ele apenas ancora o caixa atual.'),
        ]);
      case 1:
        return Column(children: [
          _field(_incomeName, 'Nome do recebimento', hint: 'Ex.: Salário'),
          const SizedBox(height: 12),
          _moneyField(_incomeAmount, 'Quanto você recebe?'),
          const SizedBox(height: 12),
          _numberField(_incomeDay, 'Dia do mês'),
          const SizedBox(height: 12),
          _accountDropdown('Conta em que recebe'),
        ]);
      case 2:
        return Column(children: [
          _field(_recurringName, 'Descrição', hint: 'Ex.: Aluguel'),
          const SizedBox(height: 12),
          _moneyField(_recurringAmount, 'Valor'),
          const SizedBox(height: 12),
          _numberField(_recurringDay, 'Dia do vencimento'),
          const SizedBox(height: 12),
          _categoryDropdown(recurring: true),
          const SizedBox(height: 12),
          _accountDropdown('Conta de pagamento'),
        ]);
      case 3:
        return Column(children: [
          _moneyField(_reserveBalance, 'Valor já separado em reserva'),
          const SizedBox(height: 10),
          const _Hint(text: 'Informe somente dinheiro que já está separado do saldo da conta principal. Se ainda não tem reserva, pode pular.'),
        ]);
      case 4:
        return Column(children: [
          _field(_cardName, 'Nome do cartão', hint: 'Ex.: AMEX Gold'),
          const SizedBox(height: 12),
          _field(_cardIssuer, 'Banco / emissor', hint: 'Opcional'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _numberField(_cardClosingDay, 'Fecha dia')),
            const SizedBox(width: 10),
            Expanded(child: _numberField(_cardDueDay, 'Vence dia')),
          ]),
          const SizedBox(height: 12),
          _moneyField(_cardInvoice, 'Fatura atual', hint: '0,00 se não houver'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickInvoiceDate,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(_invoiceDueDate == null ? 'Vencimento da fatura atual' : Formatters.fullDate.format(_invoiceDueDate!)),
          ),
          const SizedBox(height: 12),
          _accountDropdown('Conta que paga a fatura'),
        ]);
      default:
        return Column(children: [
          _categoryDropdown(recurring: false),
          const SizedBox(height: 12),
          _moneyField(_budgetAmount, 'Limite mensal da categoria'),
          const SizedBox(height: 10),
          const _Hint(text: 'Você poderá criar todos os outros limites depois. Um já é suficiente para demonstrar o cálculo econômico do Fôlego.'),
        ]);
    }
  }

  Widget _primaryButton() {
    final actions = <Future<void> Function()>[
      _saveAccount,
      _saveIncome,
      _saveRecurring,
      _saveReserve,
      _saveCard,
      _finish,
    ];
    final labels = ['Salvar conta', 'Salvar recebimento', 'Salvar e continuar', 'Salvar reserva', 'Salvar cartão', 'Ver meu Fôlego'];
    return FilledButton(
      onPressed: _busy ? null : actions[_step],
      child: _busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(labels[_step]),
    );
  }

  Widget _accountDropdown(String label) {
    return DropdownButtonFormField<String>(
      key: ValueKey(_selectedAccountId),
      initialValue: _accounts.any((item) => item.id == _selectedAccountId) ? _selectedAccountId : null,
      decoration: InputDecoration(labelText: label),
      items: _accounts.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
      onChanged: (value) => setState(() => _selectedAccountId = value),
    );
  }

  Widget _categoryDropdown({required bool recurring}) {
    final discretionary = _categories.where((item) => !item.essential).toList();
    final list = recurring ? _categories : (discretionary.isEmpty ? _categories : discretionary);
    final current = recurring ? _recurringCategoryId : _budgetCategoryId;
    return DropdownButtonFormField<String>(
      key: ValueKey(current),
      initialValue: list.any((item) => item.id == current) ? current : null,
      decoration: InputDecoration(labelText: recurring ? 'Categoria' : 'Categoria do orçamento'),
      items: list.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
      onChanged: (value) => setState(() {
        if (recurring) {
          _recurringCategoryId = value;
        } else {
          _budgetCategoryId = value;
        }
      }),
    );
  }

  Widget _field(TextEditingController controller, String label, {String? hint}) {
    return TextField(controller: controller, decoration: InputDecoration(labelText: label, hintText: hint));
  }

  Widget _moneyField(TextEditingController controller, String label, {String? hint}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: hint ?? '0,00', prefixText: 'R\$ '),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label));
  }

  String _message(Object error) {
    if (error is FormatException) return error.message.toString();
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4))),
      ],
    );
  }
}
