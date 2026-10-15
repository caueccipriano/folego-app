import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/registered_spending_margin.dart';
import 'package:folego/data/models/spending_behavior.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/plan/spending_behavior_screen.dart';

class _FakeRepository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  final entries = <SpendingBehaviorEntry>[
    SpendingBehaviorEntry(
      id: 'rent', description: 'Aluguel', amount: 1000,
      occurredAt: DateTime(2026, 10, 5), behavior: ExpenseBehavior.fixed,
    ),
    SpendingBehaviorEntry(
      id: 'power', description: 'Energia', amount: 150,
      occurredAt: DateTime(2026, 10, 8),
      behavior: ExpenseBehavior.variable, frequencyClass: 'recurring',
    ),
    SpendingBehaviorEntry(
      id: 'pending-class', description: 'Sem tipo', amount: 250,
      occurredAt: DateTime(2026, 10, 9),
      behavior: ExpenseBehavior.unclassified,
    ),
  ];

  test('registered income never creates spendable cash or hides unknowns', () {
    final totals = SpendingBehaviorSummary.fromEntries(entries);
    final margin = buildRegisteredSpendingMargin(
      registeredIncome: 3000, expenses: totals,
    );
    expect(margin.registeredIncome, 3000);
    expect(margin.afterClassifiedFixed, 2000);
    expect(margin.afterAllRecordedSpending, 1600);
    expect(margin.fixedShareOfIncome, closeTo(1 / 3, .00001));
    expect(margin.hasUnknownExpenses, isTrue);
  });

  test('zero revenue, overspending, invalid revenue retain correct semantics', () {
    final totals = SpendingBehaviorSummary.fromEntries(entries);
    final zero = buildRegisteredSpendingMargin(
      registeredIncome: 0, expenses: totals,
    );
    expect(zero.fixedShareOfIncome, isNull);
    expect(zero.afterAllRecordedSpending, -1400);
    final short = buildRegisteredSpendingMargin(
      registeredIncome: 400, expenses: totals,
    );
    expect(short.afterClassifiedFixed, -600);
    expect(short.afterAllRecordedSpending, -1000);
    expect(
      () => buildRegisteredSpendingMargin(
        registeredIncome: double.nan, expenses: totals,
      ),
      throwsFormatException,
    );
    expect(
      () => buildRegisteredSpendingMargin(
        registeredIncome: -10, expenses: totals,
      ),
      throwsFormatException,
    );
  });

  testWidgets('monthly margin uses loaded income, warns about incomplete types',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var incomeCalls = 0;
    await tester.pumpWidget(MaterialApp(home: SpendingBehaviorScreen(
      repository: _FakeRepository(),
      spaceId: 'test-space',
      periodMonth: DateTime(2026, 10),
      loadOverride: (space, month) async {
        expect(space, 'test-space');
        return entries;
      },
      incomeOverride: (space, month) async {
        expect(month.month, 10);
        incomeCalls++;
        return 3000;
      },
    )));
    await tester.pumpAndSettle();
    expect(incomeCalls, 1);
    expect(find.byKey(const ValueKey('spending-registered-income-margin')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('spending-after-fixed')), findsOneWidget);
    expect(find.byKey(const ValueKey('spending-after-all-recorded')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('spending-unknown-warning')),
        findsOneWidget);
    expect(find.textContaining('não é saldo livre para gastar'), findsOneWidget);

    FinancialPrivacy.hidden.value = true;
    await tester.pumpAndSettle();
    expect(find.textContaining('33% das'), findsNothing);
    expect(find.textContaining('R$'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('income query failure does not present a zero-income calculation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: SpendingBehaviorScreen(
      repository: _FakeRepository(),
      spaceId: 'test-space',
      periodMonth: DateTime(2026, 10),
      loadOverride: (space, month) async => entries,
      incomeOverride: (space, month) async =>
          throw StateError('network error'),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('spending-income-unavailable')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('spending-after-fixed')), findsNothing);
    expect(find.text('fixos x variáveis.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('income query and expense query share same date and confirmation rules', () {
    final repository = File('lib/data/repositories/folego_repository.dart')
        .readAsStringSync();
    final income = repository.split('getRegisteredIncomeForMonth').last
        .split('setSpendingBehavior').first;
    expect(income, contains(".eq('event_type', 'income')"));
    expect(income, contains(".eq('status', 'confirmed')"));
    expect(income, contains(".eq('space_id', spaceId)"));
    expect(income, contains(".gte('occurred_at', start.toUtc().toIso8601String())"));
    expect(income, contains(".lt('occurred_at', end.toUtc().toIso8601String())"));
    expect(income, contains("throw StateError('muitas receitas"));
  });
}
