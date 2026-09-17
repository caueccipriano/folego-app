import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/data/models/transaction_detail.dart';
import 'package:folego/data/models/transaction_filters.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/models/transaction_page.dart';
import 'package:folego/data/models/upcoming_events.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/home_screen_base.dart' as home;
import 'package:folego/features/transactions/transactions_screen_base.dart';

void main() {
  const space = FinancialSpace(id: 'space-1', name: 'Pessoal');

  testWidgets('lançamento de benefício continua visível e identificado na lista', (
    tester,
  ) async {
    final benefit = _benefitTransaction();

    await tester.pumpWidget(
      MaterialApp(
        home: TransactionsScreenV3(
          repository: _BenefitRepository(),
          space: space,
          optionsLoader: (_) async => TransactionFilterOptions.empty(),
          pageLoader: ({
            required String spaceId,
            required TransactionFilters filters,
            required TransactionCursor? cursor,
            required int pageSize,
          }) async => TransactionPage(
            items: [benefit],
            hasMore: false,
            nextCursor: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Almoço no Flash'), findsOneWidget);
    expect(
      find.text('gasto de benefício • 17/09/2026 • Flash'),
      findsOneWidget,
    );
  });

  test('detalhe de benefício explica que não afeta saldo disponível', () {
    final detail = TransactionDetail(
      id: 'benefit-1',
      spaceId: 'space-1',
      eventType: 'benefit_expense',
      description: 'Almoço no Flash',
      amount: 42,
      occurredAt: DateTime.utc(2026, 9, 17, 12),
      status: 'confirmed',
      source: 'app',
      impacts: const [
        TransactionDetailAccountImpact(
          dimension: 'benefit',
          amount: -42,
          accountId: 'benefit-account',
          accountName: 'Flash',
          accountType: 'benefit',
        ),
        TransactionDetailAccountImpact(dimension: 'economic', amount: -42),
        TransactionDetailAccountImpact(dimension: 'budget', amount: -42),
      ],
    );

    expect(detail.isBenefitExpense, isTrue);
    expect(detail.hasBenefitBacking, isTrue);
    expect(detail.sourceImpact, isNull);
    expect(detail.typeLabel, contains('benefício'));
    expect(detail.typeLabel, contains('não afeta saldo disponível'));
  });

  testWidgets('Home deixa claro que sobra e gastos principais são cash', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: home.HomeScreen(
          space: space,
          repository: _BenefitRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('te sobra pra gastar'), findsOneWidget);
    expect(find.textContaining('dinheiro disponível, sem benefícios'), findsOneWidget);
    expect(
      find.text('gastos do bolso neste mês; benefícios ficam separados'),
      findsOneWidget,
    );
    expect(find.textContaining('1.600'), findsOneWidget);
  });
}

TransactionItem _benefitTransaction() => TransactionItem(
  id: 'benefit-1',
  eventType: 'benefit_expense',
  description: 'Almoço no Flash',
  amount: 42,
  occurredAt: DateTime.utc(2026, 9, 17, 12),
  status: 'confirmed',
  source: 'app',
  accountId: 'benefit-account',
  accountName: 'Flash',
  categoryName: 'Alimentação',
);

class _BenefitRepository implements FolegoRepository {
  @override
  Future<FolegoSnapshot> getSnapshot(
    String spaceId, {
    DateTime? asOfDate,
  }) async => FolegoSnapshot(
    asOfDate: DateTime(2026, 9, 17),
    nextIncomeDate: DateTime(2026, 9, 30),
    nextIncomeAmount: 6000,
    daysUntilIncome: 13,
    liquidBalance: 4000,
    protectedBalance: 500,
    mandatoryOutflowsUntilIncome: 1200,
    cashHeadroom: 2300,
    monthlyBudgetPlanned: 2500,
    monthlyBudgetUsed: 900,
    economicHeadroom: 1600,
    spendablePool: 1600,
    dailyFolego: 123,
    shortfall: 0,
    limitingFactor: 'budget',
    status: 'ok',
    budgetConfigured: true,
    needsIncomeSetup: false,
  );

  @override
  Future<String> getProfileName() async => 'Cauê';

  @override
  Future<TransactionPage> getTransactionsPage(
    String spaceId, {
    TransactionCursor? cursor,
    int pageSize = transactionPageSize,
  }) async => TransactionPage(
    items: [_benefitTransaction()],
    hasMore: false,
    nextCursor: null,
  );

  @override
  Future<List<CategoryItem>> listExpenseCategories(String spaceId) async => [];

  @override
  Future<List<CategoryItem>> listIncomeCategories(String spaceId) async => [];

  @override
  Future<List<UpcomingEvent>> getUpcomingEvents(
    String spaceId, {
    DateTime? from,
    int days = 30,
  }) async => [];

  @override
  Future<List<RecurringItem>> listRecurringItems(String spaceId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
