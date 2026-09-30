import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/purchase_timeline.dart';
import 'package:folego/data/models/projection_model.dart';
import 'package:folego/widgets/purchase_timeline_card.dart';

ProjectionResult projection(List<(String, double)> months) => ProjectionResult.fromJson({
  'scenario': 'test',
  'horizon_months': 12,
  'as_of_date': '2026-09-30',
  'has_projection_inputs': true,
  'months': [
    for (final (month, balance) in months)
      {'month': month, 'closing_projected': balance},
  ],
});

void main() {
  test('aligns months by year and month without assuming equal ordering', () {
    final current = projection([
      ('2026-09-01', 500), ('2026-10-01', 400), ('2026-11-01', 350),
    ]);
    final changed = projection([
      ('2026-11-01', -100), ('2026-09-01', 400),
      ('2026-10-01', 200), ('2026-12-01', 99),
    ]);
    final result = purchaseTimeline(current, changed);
    expect(result.length, 3);
    expect(result.map((e) => e.month.month), [9,10,11]);
    expect(result.map((e) => e.difference), [-100, -200, -450]);
    expect(result.last.isNegative, true);
    expect(result.first.isNegative, false);
  });

  test('missing periods and duplicate months never fabricate a result', () {
    final baseline = projection([('2026-09-01', 500),('2026-09-16', 999),('2026-10-01', 400)]);
    final changed = projection([('2026-09-01', 450)]);
    final result = purchaseTimeline(baseline, changed);
    expect(result.length, 1);
    expect(result.first.baselineBalance, 500);
    expect(() => result.add(result.first), throwsUnsupportedError);
  });

  testWidgets('renders responsive comparison from projections with no provider',
      (tester) async {
    final months = purchaseTimeline(
      projection([('2026-09-01', 300),('2026-10-01', 100)]),
      projection([('2026-09-01', 200),('2026-10-01', -50)]),
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 320,
        child: PurchaseTimelineCard(months: months),
      )),
    )));
    expect(find.text('Ver impacto mês a mês'), findsOneWidget);
    await tester.tap(find.text('Ver impacto mês a mês'));
    await tester.pumpAndSettle();
    expect(find.text('09/2026'), findsOneWidget);
    expect(find.text('10/2026'), findsOneWidget);
    expect(find.text('Saldo projetado negativo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
