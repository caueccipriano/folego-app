import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/financial_insights_service.dart';
import 'package:folego/core/intelligence/financial_report_builder.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/widgets/monthly_insights_card.dart';

class _FakeRepository extends Fake implements FolegoRepository {}

class _MonthlyFixtureService extends FinancialInsightsService {
  _MonthlyFixtureService() : super(_FakeRepository());

  @override
  Future<MonthlyIntelligenceReport> monthly({
    required String spaceId,
    required DateTime month,
  }) async {
    expect(spaceId, 'fictional-household');
    return const MonthlyIntelligenceReport(
      income: 1000,
      expenses: 1200,
      result: -200,
      insights: [
        PeriodInsight(
          title: 'Atenção ao resultado',
          description: 'As despesas superaram as receitas.',
        ),
        PeriodInsight(
          title: 'Mudança nas despesas',
          description: 'Despesas do mês subiram.',
        ),
      ],
    );
  }
}

void main() {
  testWidgets('monthly summary hides the repeated subtitle while expanded',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: MonthlyInsightsCard(
          service: _MonthlyFixtureService(),
          spaceId: 'fictional-household',
          month: DateTime(2026, 9),
        ),
      )),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Seu mês em perspectiva'), findsOneWidget);
    expect(find.text('Atenção ao resultado'), findsOneWidget);
    await tester.tap(find.text('Seu mês em perspectiva'));
    await tester.pumpAndSettle();

    // Exactly one visible insight heading, never both the subtitle and item.
    expect(find.text('Atenção ao resultado'), findsOneWidget);
    expect(find.text('As despesas superaram as receitas.'), findsOneWidget);
    expect(find.text('Mudança nas despesas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
