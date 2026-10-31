import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/upcoming_events.dart';
import 'package:folego/features/home/home_pulse_card.dart';
import 'package:folego/features/home/home_pulse_insight.dart';

FolegoSnapshot snapshot({
  num spendable = 900,
  num budgetPlanned = 1000,
  num budgetUsed = 100,
  bool needsIncomeSetup = false,
}) => FolegoSnapshot(
  asOfDate: DateTime(2026, 10, 13),
  nextIncomeDate: null,
  nextIncomeAmount: 0,
  daysUntilIncome: null,
  liquidBalance: 1000,
  protectedBalance: 0,
  mandatoryOutflowsUntilIncome: 100,
  cashHeadroom: 900,
  monthlyBudgetPlanned: budgetPlanned,
  monthlyBudgetUsed: budgetUsed,
  economicHeadroom: budgetPlanned - budgetUsed,
  spendablePool: spendable,
  dailyFolego: 30,
  shortfall: 0,
  limitingFactor: 'cash',
  status: 'ok',
  budgetConfigured: true,
  needsIncomeSetup: needsIncomeSetup,
);

UpcomingEvent invoice({
  int day = 15,
  String status = 'pending',
  String name = 'InfinityPay',
}) => UpcomingEvent(
  id: 'invoice-$day',
  source: 'invoice',
  name: name,
  dueDate: DateTime(2026, 10, day),
  amount: 140,
  direction: 'expense',
  status: status,
);

void main() {
  tearDown(() => FinancialPrivacy.hidden.value = false);

  test('a pending overdue invoice asks for confirmation, not automatic nonpayment', () {
    final insight = selectHomePulse(
      snapshot: snapshot(),
      upcoming: [invoice(day: 10)],
      upcomingAvailable: true,
    );
    expect(insight.requiresAttention, isTrue);
    expect(insight.action, HomePulseAction.upcoming);
    expect(insight.description, contains('Confira se já foi pago'));
    expect(insight.amount, 140);
  });

  test('nearby commitment takes priority over budget and missing income', () {
    final insight = selectHomePulse(
      snapshot: snapshot(spendable: 0, needsIncomeSetup: true),
      upcoming: [invoice(day: 14)],
      upcomingAvailable: true,
    );
    expect(insight.title, contains('amanhã'));
    expect(insight.action, HomePulseAction.upcoming);
  });

  test('no due item: missing income prompt is contextual, not a forced check-in', () {
    final insight = selectHomePulse(
      snapshot: snapshot(needsIncomeSetup: true),
      upcoming: [],
      upcomingAvailable: true,
    );
    expect(insight.title, contains('recebimento'));
    expect(insight.action, HomePulseAction.none);
  });

  test('zero discretionary pool is not called negative bank balance', () {
    final insight = selectHomePulse(
      snapshot: snapshot(spendable: 0),
      upcoming: [],
      upcomingAvailable: true,
    );
    expect(insight.title, contains('Não há folga'));
    expect(insight.description, contains('não significa'));
    expect(insight.action, HomePulseAction.budget);
  });

  test('next-week due event is useful without a login streak', () {
    final insight = selectHomePulse(
      snapshot: snapshot(),
      upcoming: [invoice(day: 18)],
      upcomingAvailable: true,
    );
    expect(insight.action, HomePulseAction.upcoming);
    expect(insight.amount, 140);
  });

  test('paid events never trigger a false overdue warning', () {
    final insight = selectHomePulse(
      snapshot: snapshot(),
      upcoming: [invoice(day: 10, status: 'paid')],
      upcomingAvailable: true,
    );
    expect(insight.requiresAttention, isFalse);
    expect(insight.title, contains('Nada urgente'));
    expect(insight.showCard, isFalse);
  });

  test('budget risk is secondary to impending payments', () {
    final insight = selectHomePulse(
      snapshot: snapshot(budgetUsed: 930),
      upcoming: [invoice(day: 30)],
      upcomingAvailable: true,
    );
    expect(insight.action, HomePulseAction.budget);
  });

  test('budget alert has a precise next step without leaking usage', () {
    final insight = selectHomePulse(
      snapshot: snapshot(budgetUsed: 930),
      upcoming: [],
      upcomingAvailable: true,
    );
    expect(insight.action, HomePulseAction.budget);
    expect(insight.budgetPercentUsed, 93);
    expect(homePulseShortDetail(insight, hidden: false),
        '93% usado · revisar categorias');
    expect(homePulseShortDetail(insight, hidden: true),
        'revisar categorias');
  });

  test('budget can exceed 100%, but is not a cash balance', () {
    final insight = selectHomePulse(
      snapshot: snapshot(budgetUsed: 1250),
      upcoming: [],
      upcomingAvailable: true,
    );
    expect(insight.budgetPercentUsed, 125);
    expect(insight.title, 'Orçamento passou do planejado');
    expect(insight.description, isNot(contains('saldo negativo')));
  });

  testWidgets('budget percentage is concealed by the privacy eye',
      (tester) async {
    final insight = selectHomePulse(
      snapshot: snapshot(budgetUsed: 930),
      upcoming: [],
      upcomingAvailable: true,
    );
    Widget card() => MaterialApp(
      home: Scaffold(body: HomePulseCard(insight: insight)),
    );
    await tester.pumpWidget(card());
    expect(find.textContaining('93% usado'), findsOneWidget);
    FinancialPrivacy.hidden.value = true;
    await tester.pumpWidget(card());
    expect(find.textContaining('93% usado'), findsNothing);
    expect(find.text('revisar categorias'), findsWidgets);
  });

  test('missing agenda does not claim no urgent commitments', () {
    final insight = selectHomePulse(
      snapshot: snapshot(),
      upcoming: [],
      upcomingAvailable: false,
    );
    expect(insight.eyebrow, 'resumo parcial');
    expect(insight.title, contains('não consegui'));
  });

  testWidgets('Home stays clean when there is no actionable insight',
      (tester) async {
    final insight = selectHomePulse(
      snapshot: snapshot(),
      upcoming: [],
      upcomingAvailable: true,
    );
    expect(insight.showCard, isFalse);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomePulseCard(insight: insight)),
    ));
    expect(find.byKey(const ValueKey('home-pulse')), findsNothing);
  });

  testWidgets('Pulse respects privacy and opens the relevant agenda', (
    tester,
  ) async {
    final insight = selectHomePulse(
      snapshot: snapshot(),
      upcoming: [invoice(day: 14)],
      upcomingAvailable: true,
    );
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomePulseCard(
          insight: insight,
          onOpenUpcoming: () => opened++,
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('home-pulse')), findsOneWidget);
    expect(find.textContaining('140,00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-pulse')));
    expect(opened, 1);

    FinancialPrivacy.hidden.value = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomePulseCard(
          insight: insight,
          onOpenUpcoming: () => opened++,
        ),
      ),
    ));
    expect(find.textContaining('140,00'), findsNothing);
    expect(find.textContaining('••••'), findsOneWidget);
  });
}
