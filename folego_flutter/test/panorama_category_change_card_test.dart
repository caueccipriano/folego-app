import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/panorama/panorama_category_change_card.dart';
import 'package:folego/features/panorama/panorama_category_changes.dart';

BudgetOverviewItem item(String id, String name, double actual) =>
    BudgetOverviewItem(
      categoryId: id,
      categoryName: name,
      essential: false,
      plannedAmount: 400,
      actualAmount: actual,
      remainingAmount: 400 - actual,
      warningThreshold: .7,
      criticalThreshold: .9,
      usageRatio: actual / 400,
      status: 'ok',
    );

PanoramaCategoryChanges? sample({
  bool unavailable = false,
  bool unmatched = false,
  bool unchanged = false,
}) => PanoramaCategoryChanges.compare(
      earlier: unavailable ? null : [item('x', 'Mercado', 190)],
      later: [
        item(unmatched ? 'different' : 'x', 'Mercado',
            unchanged ? 190 : 230),
      ],
      referenceDate: DateTime(2026, 9, 29),
    );

Future<void> showCard(
  WidgetTester tester,
  PanoramaCategoryChanges? data,
) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: PanoramaCategoryChangeCard(comparison: data),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  testWidgets('compact historical card explains a recorded absolute change',
      (tester) async {
    await showCard(tester, sample());
    expect(find.text('o que mudou por categoria'), findsOneWidget);
    expect(find.textContaining('07/2026'), findsOneWidget);
    expect(find.textContaining('08/2026'), findsOneWidget);
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.textContaining('aumentou'), findsOneWidget);
    expect(find.textContaining('40,00'), findsOneWidget);
    expect(find.textContaining('importações incompletas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable months are not presented as verified empty',
      (tester) async {
    await showCard(tester, sample(unavailable: true));
    expect(
      find.byKey(const ValueKey('category-changes-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('category-changes-no-common')),
        findsNothing);
  });

  testWidgets('no comparable categories and no changes are distinct',
      (tester) async {
    await showCard(tester, sample(unmatched: true));
    expect(find.byKey(const ValueKey('category-changes-no-common')),
        findsOneWidget);
    await showCard(tester, sample(unchanged: true));
    expect(find.byKey(const ValueKey('category-changes-unchanged')),
        findsOneWidget);
  });

  testWidgets('privacy switch immediately masks amounts AND change direction',
      (tester) async {
    await showCard(tester, sample());
    expect(find.textContaining('40,00'), findsOneWidget);
    FinancialPrivacy.hidden.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-changes-hidden')),
        findsOneWidget);
    expect(find.text('Mercado'), findsNothing);
    expect(find.text('valores ocultos'), findsNothing);
    expect(find.textContaining('40,00'), findsNothing);
    expect(find.textContaining('aumentou'), findsNothing);
    FinancialPrivacy.hidden.value = false;
    await tester.pumpAndSettle();
    expect(find.textContaining('40,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
