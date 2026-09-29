import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/financial_insights_service.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/widgets/financial_ai_card.dart';

class _FictionalRepository implements FolegoRepository {
  _FictionalRepository(this.identity);
  final String identity;
  final summary = Completer<MonthlyMoneySummary>();

  @override
  String? get currentUserId => identity;

  @override
  Future<MonthlyMoneySummary> getMonthlyMoneySummary({
    required String spaceId,
    DateTime? periodMonth,
  }) => summary.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _screen(_FictionalRepository repo, String space) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: FinancialAiCard(
        service: FinancialInsightsService(repo),
        spaceId: space,
        embedded: true,
      ),
    ),
  ),
);

MonthlyMoneySummary _month(double income, double expenses) =>
    MonthlyMoneySummary.fromJson({
      'period_month': '2026-09-01',
      'income_amount': income,
      'competence_net': expenses,
    });

void main() {
  testWidgets('personal local analysis works with NO Supabase initialization or AI call',
      (tester) async {
    final repo = _FictionalRepository('fictional-personal-account');
    await tester.pumpWidget(_screen(repo, 'fictional-space'));
    expect(find.text('Analisar sem limite'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Como está meu mês?');
    await tester.tap(find.text('Analisar sem limite'));
    await tester.pump();
    expect(find.text('Consultando…'), findsOneWidget);

    repo.summary.complete(_month(3000, 2200));
    await tester.pump();
    expect(find.text('Resposta automática · sem IA'), findsOneWidget);
    expect(find.textContaining('3.000,00'), findsWidgets);
    expect(find.text('Copiar totais e pergunta para meu ChatGPT'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // No Supabase.instance initialization: a provider call would fail this test.
  });

  testWidgets('late private monthly response cannot appear in another account',
      (tester) async {
    final a = _FictionalRepository('fictional-A');
    final b = _FictionalRepository('fictional-B');
    await tester.pumpWidget(_screen(a, 'space-A'));
    await tester.enterText(find.byType(TextField), 'Como está meu mês?');
    await tester.tap(find.text('Analisar sem limite'));
    await tester.pump();
    await tester.pumpWidget(_screen(b, 'space-B'));
    a.summary.complete(_month(999999, 1));
    await tester.pump();
    expect(find.textContaining('999.999'), findsNothing);
    expect(find.text('Resposta automática · sem IA'), findsNothing);
    expect(find.text('Copiar totais e pergunta para meu ChatGPT'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
