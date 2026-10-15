import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/registered_spending_margin.dart';
import 'package:folego/data/models/spending_behavior.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/plan/spending_behavior_screen.dart';

class _StubRepository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  final entries = <SpendingBehaviorEntry>[
    SpendingBehaviorEntry(
      id: 'rent',
      description: 'Aluguel',
      amount: 1000,
      occurredAt: DateTime(2026, 10, 5),
      behavior: ExpenseBehavior.fixed,
    ),
    SpendingBehaviorEntry(
      id: 'power',
      description: 'Energia',
      amount: 150,
      occurredAt: DateTime(2026, 10, 8),
      behavior: ExpenseBehavior.variable,
      frequencyClass: 'recurring',
    ),
    SpendingBehaviorEntry(
      id: 'unknown',
      description: 'Não classificado',
      amount: 250,
      occurredAt: DateTime(2026, 10, 9),
      behavior: ExpenseBehavior.unclassified,
    ),
  ];

  test('fixed expense comparison preserves unknown variable spending', () {
    final spending = SpendingBehaviorSummary.fromEntries(entries);
    final result = buildRegisteredSpendingMargin(
      registeredIncome: 3000,
      expenses: spending,
    );
    expect(result.afterClassifiedFixed, 2000);
    expect(result.afterAllRecordedSpending, 1600);
    expect(result.hasUnknownExpenses, isTrue);
    expect(result.fixedShareOfIncome, closeTo(1 / 3, .001));
  });

  test('zero and insufficient income do not masquerade as cash available', () {
    final spending = SpendingBehaviorSummary.fromEntries(entries);
    final zero = buildRegisteredSpendingMargin(
      registeredIncome: 0, expenses: spending,
    );
    expect(zero.fixedShareOfIncome, isNull);
    expect(zero.afterAllRecordedSpending, -1400);
    final low = buildRegisteredSpendingMargin(
      registeredIncome: 400, expenses: spending,
    );
    expect(low.afterClassifiedFixed, -600);
    expect(low.afterAllRecordedSpending, -1000);
    expect(low.fixedShareOfIncome, 2.5);
    expect(
      () => buildRegisteredSpendingMargin(
        registeredIncome: double.nan, expenses: spending,
      ),
      throwsFormatException,
    );
  });

  testWidgets('margin widget explains recorded amounts and masks figures',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: SpendingBehaviorScreen(
        repository: _StubRepository(),
        spaceId: 'test-space',
        periodMonth: DateTime(2026, 10),
        loadOverride: (spaceId, month) async => entries,
        incomeOverride: (spaceId, month) async => 3000,
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('spending-registered-income-margin')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('spending-after-fixed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('spending-unknown-warning')),
      findsOneWidget,
    );
    expect(find.textContaining('não é saldo livre para gastar'), findsOneWidget);

    FinancialPrivacy.hidden.value = true;
    await tester.pumpAndSettle();
    expect(find.textContaining('33% das'), findsNothing);
    expect(find.textContaining('3.000,00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown income is never rendered as zero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SpendingBehaviorScreen(
        repository: _StubRepository(),
        spaceId: 'space-a',
        periodMonth: DateTime(2026, 10),
        loadOverride: (spaceId, month) async => entries,
        incomeOverride: (spaceId, month) async =>
            throw StateError('network failure'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('spending-income-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('spending-after-fixed')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow phone size remains usable', (tester) async {
    tester.view.physicalSize = const Size(320, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: SpendingBehaviorScreen(
        repository: _StubRepository(),
        spaceId: 'space-a',
        periodMonth: DateTime(2026, 10),
        loadOverride: (spaceId, month) async => entries,
        incomeOverride: (spaceId, month) async => 1600,
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('spending-registered-income-margin')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
