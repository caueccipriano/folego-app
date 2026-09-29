import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/panorama/panorama_budget_watch.dart';

BudgetOverviewItem _category({
  required String id,
  required String name,
  required double limit,
  required double used,
  String? parentId,
  double warningThreshold = .7,
}) =>
    BudgetOverviewItem(
      categoryId: id,
      categoryName: name,
      parentId: parentId,
      essential: false,
      plannedAmount: limit,
      actualAmount: used,
      remainingAmount: limit - used,
      warningThreshold: warningThreshold,
      criticalThreshold: .9,
      usageRatio: limit <= 0 ? 0 : used / limit,
      status: used > limit ? 'exceeded' : 'ok',
    );

Future<void> _show(
  WidgetTester tester,
  List<PanoramaBudgetWatchEntry> entries,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: PanoramaBudgetWatch(entries: entries),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  test('unavailable backend and loaded empty budget must stay distinct', () {
    expect(PanoramaBudgetWatchEntry.fromBudgets(null), isNull);
    expect(PanoramaBudgetWatchEntry.fromBudgets(const []), isEmpty);
  });

  test('only PARENT categories trigger watch; never double count children',
      () {
    final watch = PanoramaBudgetWatchEntry.fromBudgets([
      _category(id: 'family', name: 'Alimentação',
          limit: 500, used: 410),
      _category(id: 'child', name: 'Mercado',
          parentId: 'family', limit: 350, used: 340),
      _category(id: 'no-limit', name: 'Sem limite',
          limit: 0, used: 900),
      _category(id: 'safe', name: 'Transporte',
          limit: 500, used: 100),
    ]);
    expect(watch, hasLength(1));
    expect(watch!.single.item.categoryName, 'Alimentação');
    expect(watch.single.ratio, closeTo(.82, .0001));
  });

  test('threshold respects category-specific settings and fails safe if malformed',
      () {
    final watch = PanoramaBudgetWatchEntry.fromBudgets([
      _category(id: 'strict', name: 'Estrita',
          limit: 100, used: 80, warningThreshold: .95),
      _category(id: 'fallback', name: 'Padrão',
          limit: 100, used: 80, warningThreshold: 1.3),
    ]);
    expect(watch, hasLength(1));
    expect(watch!.single.item.categoryName, 'Padrão');
  });

  test('prioritize largest overruns, then nearest finite upcoming limits',
      () {
    final watch = PanoramaBudgetWatchEntry.fromBudgets([
      _category(id: 'near', name: 'Perto', limit: 100, used: 90),
      _category(id: 'big', name: 'Excedeu mais',
          limit: 100, used: 175),
      _category(id: 'small', name: 'Excedeu menos',
          limit: 100, used: 110),
      _category(id: 'medium', name: 'Ainda acompanha',
          limit: 100, used: 85),
    ]);
    expect(watch, hasLength(3));
    expect(watch!.map((x) => x.item.categoryId),
        ['big', 'small', 'near']);
    expect(watch.first.exceeded, 75);
    expect(watch.first.remaining, 0);
    expect(watch.last.exceeded, 0);
    expect(watch.last.remaining, 10);
  });

  test('negative/invalid economic amounts and nonpositive limits cannot alert',
      () {
    final watch = PanoramaBudgetWatchEntry.fromBudgets([
      _category(id: 'negative', name: 'Reembolsos',
          limit: 100, used: -900),
      _category(id: 'invalid', name: 'Inválido',
          limit: double.nan, used: 100),
      _category(id: 'zero', name: 'Sem teto',
          limit: 0, used: 700),
      _category(id: 'fine', name: 'Normal',
          limit: 100, used: 65),
    ]);
    expect(watch, isEmpty);
  });

  testWidgets('compact accessible watchlist displays categories and balances',
      (tester) async {
    final entries = PanoramaBudgetWatchEntry.fromBudgets([
      _category(id: 'food', name: 'Alimentação',
          limit: 1000, used: 1200),
      _category(id: 'car', name: 'Transporte',
          limit: 1000, used: 800),
    ])!;
    await _show(tester, entries);
    expect(find.byKey(const ValueKey('panorama-budget-watch')), findsOneWidget);
    expect(find.text('categorias para acompanhar'), findsOneWidget);
    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.textContaining('acima'), findsOneWidget);
    expect(find.textContaining('restante'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy mode hides BOTH currency values and progress ratios',
      (tester) async {
    final watch = PanoramaBudgetWatchEntry.fromBudgets([
      _category(id: 'food', name: 'Alimentação',
          limit: 1000, used: 1200),
    ])!;
    await _show(tester, watch);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    FinancialPrivacy.hidden.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('valores ocultos'), findsOneWidget);
    expect(find.textContaining('200,00'), findsNothing);
    FinancialPrivacy.hidden.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
