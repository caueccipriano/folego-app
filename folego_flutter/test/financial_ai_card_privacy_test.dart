import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/financial_insights_service.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/widgets/financial_ai_card.dart';

// Fictional local data only. These tests intentionally never initialize
// Supabase or send prompts, and prove an obsolete response cannot reach B.
class _DelayedRepo implements FolegoRepository {
  _DelayedRepo(this.userId);

  String? userId;
  final pending = Completer<MonthlyMoneySummary>();

  @override
  String? get currentUserId => userId;

  @override
  Future<MonthlyMoneySummary> getMonthlyMoneySummary({
    required String spaceId,
    DateTime? periodMonth,
  }) => pending.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _screen(_DelayedRepo repo, String spaceId, {bool embedded = true}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: FinancialAiCard(
          service: FinancialInsightsService(repo),
          spaceId: spaceId,
          embedded: embedded,
        ),
      ),
    ),
  );
}

Future<void> _ask(TesterBridge tester) async {
  await tester.enterText(
    find.byType(TextField),
    'Como esta meu orcamento deste mes?',
  );
  await tester.tap(find.text('Perguntar à IA'));
  await tester.pump();
}

// Avoid a private integration-test driver: WidgetTester already implements
// the test methods consumed by the helper.
typedef TesterBridge = WidgetTester;

MonthlyMoneySummary _fictionalSummary() => MonthlyMoneySummary.fromJson({
  'period_month': '2026-09-01',
  'income_amount': 1000,
  'competence_net': 300,
});

void main() {
  testWidgets('embedded AI has no duplicate heading or nested Card', (tester) async {
    await tester.pumpWidget(_screen(_DelayedRepo('fake-A'), 'space-A'));
    expect(find.text('Pergunte ao Fôlego ✨'), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('apenas os totais'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid question is labeled as an error, not an AI answer',
      (tester) async {
    await tester.pumpWidget(_screen(_DelayedRepo('fake-A'), 'space-A'));
    await tester.tap(find.text('Perguntar à IA'));
    await tester.pump();
    expect(find.text('Não foi possível responder'), findsOneWidget);
    expect(find.text('Resposta do Fôlego'), findsNothing);
    expect(find.text('Escreva uma pergunta de 3 a 500 caracteres.'), findsOneWidget);
  });

  testWidgets('switching A to B drops the pending A summary before any AI call',
      (tester) async {
    final a = _DelayedRepo('fake-A');
    final b = _DelayedRepo('fake-B');
    await tester.pumpWidget(_screen(a, 'space-A'));
    await _ask(tester);
    expect(find.text('Consultando…'), findsOneWidget);

    await tester.pumpWidget(_screen(b, 'space-B'));
    await tester.pump();
    expect(find.text('Consultando…'), findsNothing);
    expect(find.text('Resposta do Fôlego'), findsNothing);
    expect(find.text('Não foi possível responder'), findsNothing);
    expect(find.byType(TextField).evaluate().single.widget, isA<TextField>());

    // If an A request were sent after this point, Supabase.instance would be
    // uninitialized in the widget-test process and display an erroneous result.
    a.pending.complete(_fictionalSummary());
    await tester.pump();
    expect(find.text('Não foi possível responder'), findsNothing);
    expect(find.text('Resposta do Fôlego'), findsNothing);
    expect(find.text('Consultando…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing signed-in identity cancels pending old-user answer',
      (tester) async {
    final repo = _DelayedRepo('fake-A');
    await tester.pumpWidget(_screen(repo, 'space-A'));
    await _ask(tester);
    repo.userId = 'fake-B';
    repo.pending.complete(_fictionalSummary());
    await tester.pump();
    expect(find.text('Consultando…'), findsNothing);
    expect(find.text('Resposta do Fôlego'), findsNothing);
    expect(find.text('Não foi possível responder'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
