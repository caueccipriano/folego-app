import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/core/theme/app_typography.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/plan/budget_spending_story.dart';

BudgetOverviewItem item(
  String id,
  double spent, {
  double limit = 100,
  String? parent = 'family',
  bool essential = false,
}) => BudgetOverviewItem(
  categoryId: id,
  categoryName: id,
  parentId: parent,
  essential: essential,
  plannedAmount: limit,
  actualAmount: spent,
  remainingAmount: limit - spent,
  warningThreshold: .8,
  criticalThreshold: 1,
  usageRatio: limit > 0 ? spent / limit : 0,
  status: spent > limit ? 'exceeded' : 'ok',
);

void main() {
  tearDown(() => FinancialPrivacy.hidden.value = false);
  final overview = FlexibleBudgetOverview(
    periodMonth: DateTime(2026, 10),
    configured: true,
    explicitLimit: true,
    limitAmount: 1000,
    usedAmount: 1200,
    remainingAmount: 0,
    exceededAmount: 200,
    categoryLimitsTotal: 900,
  );
  final rows = [
    item('sem limite', 300, limit: 0),
    item('lazer', 150),
    item('mercado', 80),
    item('parent total', 9999, parent: null),
    item('essencial', 5000, essential: true),
  ];
  Widget app({
    double width = 390,
    Brightness brightness = Brightness.light,
    ValueChanged<BudgetOverviewItem>? select,
    VoidCallback? classify,
    VoidCallback? behavior,
    FlexibleBudgetOverview? data,
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: BudgetSpendingStory(
              overview: data ?? overview,
              items: rows,
              onCategory: select ?? (_) {},
              onClassify: classify ?? () {},
              onSpendingBehavior: behavior ?? () {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'restores expressive section titles while keeping numeric face stable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(AppTypography.section(context).fontFamily, 'Unbounded');
              expect(AppTypography.money(context).fontFamily, 'Manrope');
              return const SizedBox();
            },
          ),
        ),
      );
    },
  );

  for (final width in [320.0, 768.0, 1440.0]) {
    for (final mode in Brightness.values) {
      testWidgets('readable graph at $width in $mode', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(width: width, brightness: mode));
        expect(tester.takeException(), isNull);
        expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
        expect(find.textContaining('parent total'), findsNothing);
          expect(find.byKey(const ValueKey('budget-story-essencial')), findsNothing);
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('budget-story-lazer')))
              .dy,
          lessThan(
            tester
                .getTopLeft(
                  find.byKey(const ValueKey('budget-story-sem limite')),
                )
                .dy,
          ),
        );
        expect(find.textContaining('passou do teto'), findsOneWidget);
      });
    }
  }

  testWidgets('bars open their category and guidance actions are connected', (
    tester,
  ) async {
    String? selected;
    var classified = false;
    var separated = false;
    await tester.pumpWidget(
      app(
        select: (i) => selected = i.categoryId,
        classify: () => classified = true,
        behavior: () => separated = true,
      ),
    );
    final bar = find.byKey(const ValueKey('budget-story-lazer'));
    await tester.ensureVisible(bar);
    await tester.tap(bar);
    expect(selected, 'lazer');
    final classify = find.byKey(const ValueKey('budget-story-classify'));
    await tester.ensureVisible(classify);
    await tester.tap(classify);
    final fixed = find.byKey(const ValueKey('budget-story-fixed-variable'));
    await tester.ensureVisible(fixed);
    await tester.tap(fixed);
    expect(classified && separated, isTrue);
  });

  testWidgets('privacy immediately hides values and comparative bar lengths', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    FinancialPrivacy.hidden.value = true;
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('1.200'), findsNothing);
    expect(find.textContaining('150,00'), findsNothing);
    expect(find.textContaining('gráfico oculto'), findsNWidgets(3));
  });

  testWidgets('missing limit does not invent an overspending conclusion', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        data: FlexibleBudgetOverview(
          periodMonth: DateTime(2026, 10),
          configured: false,
          explicitLimit: false,
          limitAmount: 0,
          usedAmount: 500,
          remainingAmount: 0,
          exceededAmount: 0,
          categoryLimitsTotal: 0,
        ),
      ),
    );
    expect(find.textContaining('Sem um teto definido'), findsOneWidget);
    expect(find.textContaining('O gasto passou do teto'), findsNothing);
  });
}
