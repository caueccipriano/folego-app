import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/panorama/panorama_360_data.dart';
import 'package:folego/features/panorama/panorama_category_changes.dart';

BudgetOverviewItem category(
  String id,
  String name,
  double actual, {
  String? parent,
  double planned = 0,
}) => BudgetOverviewItem(
      categoryId: id,
      categoryName: name,
      parentId: parent,
      essential: false,
      plannedAmount: planned,
      actualAmount: actual,
      remainingAmount: planned - actual,
      warningThreshold: .70,
      criticalThreshold: .90,
      usageRatio: planned > 0 ? actual / planned : 0,
      status: 'ok',
    );

PanoramaCategoryChanges? comparison(
  List<BudgetOverviewItem>? earlier,
  List<BudgetOverviewItem>? later, {
  DateTime? referenceDate,
}) => PanoramaCategoryChanges.compare(
      earlier: earlier,
      later: later,
      referenceDate: referenceDate ?? DateTime(2026, 9, 29),
    );

void main() {
  test('only identical parent IDs compare, never parent plus child', () {
    final data = comparison(
      [
        category('food', 'Comida antiga', 250),
        category('market', 'Mercado', 100, parent: 'food'),
      ],
      [
        category('food', 'Alimentação', 390),
        category('market', 'Mercado', 200, parent: 'food'),
      ],
    );
    expect(data?.commonCategories, 1);
    expect(data?.changes, hasLength(1));
    expect(data!.changes.single.categoryId, 'food');
    expect(data.changes.single.categoryName, 'Alimentação');
    expect(data.changes.single.difference, 140);
    expect(data.changes.single.increased, isTrue);
  });

  test('same category has explanatory decrease without any spending judgment',
      () {
    final data = comparison(
      [category('food', 'Alimentação', 380)],
      [category('food', 'Alimentação', 210)],
    );
    expect(data?.changes.single.difference, -170);
    expect(data?.changes.single.increased, isFalse);
  });

  test('a new or removed category is not presumed to be a zero month', () {
    final data = comparison(
      [category('food', 'Alimentação', 380)],
      [category('new', 'Nova categoria', 250)],
    );
    expect(data?.commonCategories, 0);
    expect(data?.changes, isEmpty);
  });

  test('failed historical query is unknown, not no recorded activity', () {
    expect(comparison(null, []), isNull);
    expect(comparison([], null), isNull);
    const unavailable = Panorama360Data();
    expect(unavailable.categoryChanges, isNull);
    expect(unavailable.hasAnyData, isFalse);
    final verifiedEmpty = Panorama360Data(
      closedEarlierBudgets: const [],
      closedLaterBudgets: const [],
      referenceDate: DateTime(2026, 9, 29),
    );
    expect(verifiedEmpty.categoryChanges?.commonCategories, 0);
    expect(verifiedEmpty.hasAnyData, isTrue);
  });

  test('two verified months of identical spending are explicitly unchanged',
      () {
    final data = comparison(
      [category('rent', 'Moradia', 1200)],
      [category('rent', 'Moradia', 1200)],
    );
    expect(data?.commonCategories, 1);
    expect(data?.changes, isEmpty);
  });

  test('duplicate same-parent IDs and invalid negative amounts fail closed',
      () {
    final data = comparison(
      [
        category('duplicate', 'Repetida', 100),
        category('duplicate', 'Repetida', 80),
        category('negative', 'Estorno líquido', -80),
        category('normal', 'Apenas comum', 90),
      ],
      [
        category('duplicate', 'Repetida', 130),
        category('negative', 'Estorno líquido', 20),
        category('normal', 'Apenas comum', 125),
      ],
    );
    expect(data?.commonCategories, 1);
    expect(data?.changes.single.categoryId, 'normal');
    expect(data?.changes.single.difference, 35);
  });

  test('up to three largest changes ranked by absolute value, including falls',
      () {
    final data = comparison(
      [
        category('a', 'A', 100),
        category('b', 'B', 150),
        category('c', 'C', 0),
        category('d', 'D', 100),
      ],
      [
        category('a', 'A', 140),
        category('b', 'B', 10),
        category('c', 'C', 90),
        category('d', 'D', 170),
      ],
    );
    expect(data?.commonCategories, 4);
    expect(data?.changes.map((e) => e.categoryId), ['b', 'c', 'd']);
    expect(data?.changes.first.difference, -140);
  });

  test('reference date compares prior two COMPLETE months across year boundary',
      () {
    final data = comparison(
      [category('x', 'Fictícia', 300)],
      [category('x', 'Fictícia', 200)],
      referenceDate: DateTime(2027, 1, 3),
    );
    expect(data?.earlierMonth, DateTime(2026, 11));
    expect(data?.laterMonth, DateTime(2026, 12));
  });

  test('unbudgeted parent still compares recorded actual when returned by RPC',
      () {
    final data = comparison(
      [category('x', 'Sem teto', 120, planned: 0)],
      [category('x', 'Sem teto', 80, planned: 0)],
    );
    expect(data?.changes.single.difference, -40);
  });

  test('scope is not inferred from category names or renamed categories', () {
    final data = comparison(
      [category('space-A-category', 'Mercado', 100)],
      [category('space-B-category', 'Mercado', 300)],
    );
    expect(data?.commonCategories, 0);
    expect(data?.changes, isEmpty);
    // Backend RLS and the caller's identical spaceId are still required:
    // these pure tests cannot prove multi-user authorization.
  });
}
