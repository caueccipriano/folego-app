import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/debt_detail.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/data/models/transaction_page.dart';
import 'package:folego/data/models/upcoming_events.dart';
import 'package:folego/data/models/upcoming_financial_event.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/data/repositories/folego_repository_agenda.dart';
import 'package:folego/data/repositories/folego_repository_debts.dart';
import 'package:folego/features/home/home_screen.dart';
import 'package:folego/features/home/upcoming_events_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  tearDown(() {
    debugFinancialAgendaLoader = null;
    debugDebtDetailLoader = null;
  });

  test('agenda groups overdue, today, tomorrow, week and later correctly', () {
    expect(_event('atrasado', -1, overdue: true).section, AgendaSection.overdue);
    expect(_event('hoje', 0).section, AgendaSection.today);
    expect(_event('amanhã', 1).section, AgendaSection.tomorrow);
    expect(_event('semana', 5).section, AgendaSection.thisWeek);
    expect(_event('adiante', 8).section, AgendaSection.later);
    expect(_event('hoje', 0).overdue, isFalse);
  });

  test('agenda filters and summary do not count card information as cash', () {
    final recurring = _event(
      'conta',
      2,
      source: UpcomingEventSource.recurring,
      cash: true,
    );
    final cardInfo = _event(
      'cartão recorrente',
      2,
      source: UpcomingEventSource.recurring,
      direction: UpcomingEventDirection.informational,
      cash: false,
      amount: 90,
    );
    final invoice = _event(
      'fatura',
      3,
      source: UpcomingEventSource.cardInvoice,
      cash: true,
      amount: 100,
    );
    final debt = _event(
      'dívida',
      4,
      source: UpcomingEventSource.debt,
      cash: true,
      amount: 30,
    );
    final income = _event(
      'salário',
      1,
      source: UpcomingEventSource.recurring,
      direction: UpcomingEventDirection.income,
      cash: false,
      amount: 500,
    );
    final summary = AgendaSummary.nextDays([
      recurring,
      cardInfo,
      invoice,
      debt,
      income,
    ]);

    expect(summary.outflowCount, 3);
    expect(summary.outflowAmount, 150);
    expect(summary.incomeCount, 1);
    expect(summary.incomeAmount, 500);
    expect(cardInfo.matches(AgendaFilter.recurring), isTrue);
    expect(invoice.matches(AgendaFilter.cards), isTrue);
    expect(debt.matches(AgendaFilter.debts), isTrue);
    expect(income.matches(AgendaFilter.income), isTrue);
  });

  testWidgets('agenda loads, shows sections and simple filters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final events = [
      _event('Conta vencida', -1, overdue: true),
      _event('Conta hoje', 0),
      _event('Conta amanhã', 1),
      _event('Parcela semana', 4, source: UpcomingEventSource.debt),
      _event('Fatura adiante', 12, source: UpcomingEventSource.cardInvoice),
    ];
    debugFinancialAgendaLoader = (
      {
      required spaceId,
      startDate,
      endDate,
      required limit,
    }) async => events;

    await tester.pumpWidget(
      MaterialApp(
        home: UpcomingEventsScreen(
          repository: _FakeRepository(),
          spaceId: 'space',
        ),
      ),
    );
    await _flush(tester);

    expect(find.text('agenda'), findsOneWidget);
    expect(find.text('atrasados'), findsOneWidget);
    expect(find.text('hoje'), findsWidgets);
    expect(find.text('amanhã'), findsWidgets);
    expect(find.text('todos'), findsOneWidget);
    expect(find.text('dívidas'), findsOneWidget);

    await tester.ensureVisible(find.text('dívidas'));
    await tester.pump();
    await tester.tap(find.text('dívidas'));
    await tester.pump();
    expect(find.text('Parcela semana'), findsOneWidget);
    expect(find.text('Conta hoje'), findsNothing);
  });

  testWidgets('agenda empty state is friendly', (tester) async {
    debugFinancialAgendaLoader = (
      {
      required spaceId,
      startDate,
      endDate,
      required limit,
    }) async => const [];
    await tester.pumpWidget(
      MaterialApp(
        home: UpcomingEventsScreen(
          repository: _FakeRepository(),
          spaceId: 'space',
        ),
      ),
    );
    await _flush(tester);
    expect(find.text('nada apertando por enquanto'), findsOneWidget);
  });

  testWidgets('tapping recurring item opens canonical recurring editor', (
    tester,
  ) async {
    final repository = _FakeRepository(
      recurringItems: [
        RecurringItem(
          id: 'rec-1',
          spaceId: 'space',
          name: 'Internet',
          itemType: 'expense',
          amount: 100,
          frequency: 'monthly',
          dayOfMonth: 10,
          monthlyDays: const [10],
          startsOn: DateTime(2026, 1, 1),
          certainty: 'confirmed',
          active: true,
          accountId: 'account-1',
          categoryId: 'category-1',
        ),
      ],
    );
    debugFinancialAgendaLoader = (
      {
      required spaceId,
      startDate,
      endDate,
      required limit,
    }) async => [_event('Internet', 2, sourceId: 'rec-1')];
    await tester.pumpWidget(
      MaterialApp(
        home: UpcomingEventsScreen(
          repository: repository,
          spaceId: 'space',
        ),
      ),
    );
    await _flush(tester);
    await tester.tap(find.text('Internet'));
    await _flush(tester);
    expect(find.text('editar recorrência'), findsOneWidget);
  });

  testWidgets('tapping invoice uses canonical wallet destination', (
    tester,
  ) async {
    final repository = _FakeRepository(overview: _overview());
    debugFinancialAgendaLoader = (
      {
      required spaceId,
      startDate,
      endDate,
      required limit,
    }) async => [
      _event(
        'Fatura teste',
        2,
        source: UpcomingEventSource.cardInvoice,
        cardId: 'card-1',
        sourceId: 'invoice-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: UpcomingEventsScreen(
          repository: repository,
          spaceId: 'space',
        ),
      ),
    );
    await _flush(tester);
    await tester.tap(find.text('Fatura teste'));
    await _flush(tester);
    expect(find.text('Cartão teste'), findsWidgets);
  });

  testWidgets('tapping debt uses canonical wallet destination', (tester) async {
    final repository = _FakeRepository(overview: _overview());
    debugDebtDetailLoader = (
      {required spaceId, required debtId}
    ) async => _debtDetail();
    debugFinancialAgendaLoader = (
      {
      required spaceId,
      startDate,
      endDate,
      required limit,
    }) async => [
      _event(
        'Dívida teste',
        2,
        source: UpcomingEventSource.debt,
        debtId: 'debt-1',
        sourceId: 'installment-1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: UpcomingEventsScreen(
          repository: repository,
          spaceId: 'space',
        ),
      ),
    );
    await _flush(tester);
    await tester.tap(find.text('Dívida teste'));
    await _flush(tester);
    expect(find.text('dívida'), findsOneWidget);
    expect(find.text('Dívida teste'), findsWidgets);
  });

  testWidgets('home próximos dias uses upcoming source and CTA opens agenda', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeRepository(
      homeUpcoming: [
        UpcomingEvent(
          id: 'rec-1',
          source: 'recurring',
          name: 'Internet',
          dueDate: DateTime.now().add(const Duration(days: 2)),
          amount: 100,
          direction: 'expense',
          status: 'pending',
        ),
      ],
    );
    debugFinancialAgendaLoader = (
      {
      required spaceId,
      startDate,
      endDate,
      required limit,
    }) async => [_event('Internet', 2, sourceId: 'rec-1')];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          space: const FinancialSpace(id: 'space', name: 'Casa'),
          repository: repository,
        ),
      ),
    );
    await _flush(tester);
    expect(find.text('próximos dias'), findsOneWidget);
    expect(find.textContaining('Internet'), findsOneWidget);
    await tester.tap(find.text('próximos dias'));
    await _flush(tester);
    expect(find.text('agenda'), findsOneWidget);
  });
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump();
}

UpcomingFinancialEvent _event(
  String title,
  int offset, {
  bool overdue = false,
  UpcomingEventSource source = UpcomingEventSource.recurring,
  UpcomingEventDirection direction = UpcomingEventDirection.outflow,
  bool cash = true,
  double amount = 20,
  String? sourceId,
  String? cardId,
  String? debtId,
}) {
  return UpcomingFinancialEvent(
    eventKey: '$title:$offset',
    source: source,
    sourceId: sourceId ?? '$title-source',
    title: title,
    subtitle: source.name,
    dueDate: DateTime(2026, 9, 16).add(Duration(days: offset)),
    amount: amount,
    direction: direction,
    status: overdue ? 'overdue' : 'pending',
    overdue: overdue,
    realized: false,
    recurring: source == UpcomingEventSource.recurring,
    dayOffset: offset,
    cashObligation: cash,
    navigationTarget: source.name,
    cardId: cardId,
    debtId: debtId,
  );
}

WalletOverview _overview() => WalletOverview(
  summary: const WalletSummary(
    totalCash: 0,
    availableCash: 0,
    totalCardInvoice: 100,
    totalDebtRemaining: 70,
  ),
  accounts: const [],
  cards: [
    WalletCard(
      id: 'card-1',
      name: 'Cartão teste',
      closingDay: 20,
      dueDay: 27,
      invoiceBalance: 100,
      invoiceId: 'invoice-1',
    ),
  ],
  debts: const [
    WalletDebt(
      id: 'debt-1',
      name: 'Dívida teste',
      openingBalance: 100,
      remainingBalance: 70,
      nextAmount: 30,
      paidInstallments: 1,
      creditor: 'Banco',
      originalAmount: 100,
      totalInstallments: 3,
    ),
  ],
  installments: const [],
);

DebtDetail _debtDetail() => DebtDetail(
  debt: const DebtRecord(
    id: 'debt-1',
    name: 'Dívida teste',
    creditor: 'Banco',
    debtType: 'loan',
    originalAmount: 100,
    openingBalance: 100,
    remainingBalance: 70,
    totalInstallments: 3,
    status: 'active',
  ),
  installments: const [],
  payments: const [],
  today: DateTime(2026, 9, 16),
);

class _FakeRepository implements FolegoRepository {
  _FakeRepository({
    this.recurringItems = const [],
    WalletOverview? overview,
    this.homeUpcoming = const [],
  }) : overview = overview ?? _overview();

  final List<RecurringItem> recurringItems;
  final WalletOverview overview;
  final List<UpcomingEvent> homeUpcoming;

  @override
  Future<List<RecurringItem>> listRecurringItems(String spaceId) async =>
      List<RecurringItem>.from(recurringItems);

  @override
  Future<WalletOverview> getWalletOverview({required String spaceId}) async =>
      overview;

  @override
  Future<List<AccountItem>> listAccounts(String spaceId) async => [
    const AccountItem(id: 'account-1', name: 'Conta teste', type: 'checking'),
  ];

  @override
  Future<List<CategoryItem>> listExpenseCategories(String spaceId) async => [
    const CategoryItem(
      id: 'category-1',
      name: 'Casa',
      essential: true,
      kind: 'expense',
    ),
  ];

  @override
  Future<List<CategoryItem>> listIncomeCategories(String spaceId) async => [
    const CategoryItem(
      id: 'income-1',
      name: 'Salário',
      essential: true,
      kind: 'income',
    ),
  ];

  @override
  Future<List<UpcomingEvent>> getUpcomingEvents(
    String spaceId, {
    DateTime? from,
    int days = 30,
  }) async => List<UpcomingEvent>.from(homeUpcoming);

  @override
  Future<String> getProfileName() async => 'Caue';

  @override
  Future<MonthlyMoneySummary> getMonthlyMoneySummary({
    required String spaceId,
    DateTime? periodMonth,
  }) async => MonthlyMoneySummary(
    periodMonth: DateTime(2026, 9),
    incomeAmount: 1000,
    spendingAccount: 100,
    spendingCards: 0,
    spendingBenefits: 0,
    refundsAmount: 0,
    spendingNet: 100,
    incomeMinusSpending: 900,
    competenceCardsTotal: 0,
    competenceDirect: 100,
    competenceBenefits: 0,
    competenceRefunds: 0,
    competenceNet: 100,
    competenceCards: const [],
    cashInflow: 1000,
    cashOutflow: 100,
    cashNet: 900,
    movementCardPayments: 0,
    movementTransfers: 0,
    movementReserveInvestment: 0,
    movementReconciliation: 0,
  );

  @override
  Future<FolegoSnapshot> getSnapshot(
    String spaceId, {
    DateTime? asOfDate,
  }) async => FolegoSnapshot(
    asOfDate: DateTime(2026, 9, 16),
    nextIncomeDate: DateTime(2026, 9, 20),
    nextIncomeAmount: 1000,
    daysUntilIncome: 4,
    liquidBalance: 500,
    protectedBalance: 0,
    mandatoryOutflowsUntilIncome: 100,
    cashHeadroom: 400,
    monthlyBudgetPlanned: 0,
    monthlyBudgetUsed: 0,
    economicHeadroom: 400,
    spendablePool: 400,
    dailyFolego: 100,
    shortfall: 0,
    limitingFactor: 'cash',
    status: 'tranquilo',
    budgetConfigured: false,
    needsIncomeSetup: false,
  );

  @override
  Future<TransactionPage> getTransactionsPage(
    String spaceId, {
    TransactionCursor? cursor,
    int pageSize = transactionPageSize,
  }) async => const TransactionPage(
    items: [],
    hasMore: false,
    nextCursor: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
