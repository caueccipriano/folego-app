import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/core/utils/formatters.dart';
import 'package:folego/features/plan/plan_insights_section.dart';

void main() {
  final insights = PlanInsights.fromJson({
    'economic_spending': 3313.04,
    'debt_payments': 1476.51,
    'budget_tracked': 4789.55,
    'cash_outflows': 3857.17,
    'cash_inflows': 4034.58,
    'estimated_available_now': 62.90,
    'issues': [
      {
        'code': 'needs_classification',
        'title': 'lançamentos a classificar',
        'description': 'sem categoria',
        'amount': 157.69,
        'count': 7,
      },
    ],
    'suggestions': [
      {
        'category_id': 'school',
        'category_name': 'Faculdade',
        'sample_months': 2,
        'historical_average': 488.19,
        'suggested_limit': 540,
      },
    ],
  });

  testWidgets('cash, budget, and bank estimate have distinct labels',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          PlanInsightsSection(insights: Future.value(insights)),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-intelligence')), findsOneWidget);
    expect(find.text('despesas do mês'), findsOneWidget);
    expect(find.text('dinheiro que saiu das contas'), findsOneWidget);
    expect(find.text('disponível estimado agora'), findsOneWidget);
    expect(find.textContaining(Formatters.money(insights.debtPayments)), findsOneWidget);
  });

  testWidgets('suggested limit stays opt-in until explicit review callback',
      (tester) async {
    PlanSuggestion? reviewed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          PlanInsightsSection(
            insights: Future.value(insights),
            onReviewSuggestion: (value) => reviewed = value,
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    final expansion = find.byKey(
      const ValueKey('plan-insights-suggestions'),
    );
    await tester.ensureVisible(expansion);
    await tester.tap(expansion);
    await tester.pumpAndSettle();
    expect(reviewed, isNull);

    final review = find.byKey(
      const ValueKey('plan-review-suggestion-school'),
    );
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pump();
    expect(reviewed?.categoryId, 'school');
    expect(reviewed?.suggestedLimit, 540);
  });

  testWidgets('disabled edits never offer an apply button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          PlanInsightsSection(
            insights: Future.value(insights),
            allowEditing: false,
            onReviewSuggestion: (_) {},
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-insights-suggestions')));
    await tester.pumpAndSettle();
    expect(find.byKey(
      const ValueKey('plan-review-suggestion-school'),
    ), findsNothing);
  });
}
