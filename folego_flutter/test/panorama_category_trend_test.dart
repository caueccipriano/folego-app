import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/budget_overview_item.dart';
import 'package:folego/features/panorama/panorama_360_data.dart';
import 'package:folego/features/panorama/panorama_category_trend.dart';

BudgetOverviewItem category(
  String id, {
  String name = 'Categoria fictícia',
  String? parent,
  double actual = 0,
  double planned = 0,
}) => BudgetOverviewItem(
      categoryId: id,
      categoryName: name,
      parentId: parent,
      essential: false,
      plannedAmount: planned,
      actualAmount: actual,
      remainingAmount: planned - actual,
      warningThreshold: .7,
      criticalThreshold: .9,
      usageRatio: planned <= 0 ? 0 : actual / planned,
      status: 'ok',
    );

PanoramaCategoryMonth month(int year, int month, List<BudgetOverviewItem> rows) =>
    PanoramaCategoryMonth(periodMonth: DateTime(year, month), categories: rows);

PanoramaCategoryTrend? trend(
  PanoramaCategoryMonth? a,
  PanoramaCategoryMonth? b, {
  DateTime? referenceDate,
}) => PanoramaCategoryTrend.tryFrom(
      earlier: a,
      later: b,
      referenceDate: referenceDate ?? DateTime(2026, 9, 29),
    );

void main() {
  test('only matched parent IDs; never add parent and child actuals twice', () {
    final result = trend(
      month(2026, 7, [
        category('groceries', name: 'Alimentação', actual: 110, planned: 200),
        category('sub', parent: 'groceries', actual: 105, planned: 150),
        category('only-july', actual: 70),
      ]),
      month(2026, 8, [
        category('groceries', name: 'Comida', actual: 170, planned: 0),
        category('sub', parent: 'groceries', actual: 166),
        category('only-august', actual: 400),
      ]),
    );
    expect(result, isNotNull);
    expect(result!.allComparableCount, 1);
    expect(result.largestChanges, hasLength(1));
    expect(result.largestChanges.single.categoryId, 'groceries');
    expect(result.largestChanges.single.currentName, 'Comida');
    expect(result.largestChanges.single.delta, 60);
  });

  test('missing month is UNKNOWN, not a fabricated zero or zero delta', () {
    final july = month(2026, 7, [category('a', actual: 100)]);
    expect(trend(july, null), isNull);
    expect(trend(null, month(2026, 8, [])), isNull);
    expect(
      Panorama360Data(
        referenceDate: DateTime(2026, 9, 29),
        closedEarlierCategories: july,
      ).categoryTrend,
      isNull,
    );
  });

  test('two loaded empty months are verified but have no comparable category', () {
    final result = trend(month(2026, 7, []), month(2026, 8, []));
    expect(result, isNotNull);
    expect(result!.allComparableCount, 0);
    expect(result.largestChanges, isEmpty);
    expect(
      Panorama360Data(
        referenceDate: DateTime(2026, 9, 29),
        closedEarlierCategories: month(2026, 7, []),
        closedLaterCategories: month(2026, 8, []),
      ).hasAnyData,
      isTrue,
    );
  });

  test('same amounts are comparable without claiming an unrecorded change', () {
    final result = trend(
      month(2026, 7, [category('a', actual: 55)]),
      month(2026, 8, [category('a', actual: 55)]),
    );
    expect(result?.allComparableCount, 1);
    expect(result?.largestChanges, isEmpty);
  });

  test('largest absolute recorded movements display first, no verdict/ratio', () {
    final result = trend(
      month(2026, 7, [
        category('a', actual: 100),
        category('b', actual: 600),
        category('c', actual: 20),
        category('d', actual: 35),
      ]),
      month(2026, 8, [
        category('a', actual: 150),
        category('b', actual: 200),
        category('c', actual: 160),
        category('d', actual: 45),
      ]),
    );
    expect(result!.allComparableCount, 4);
    expect(result.largestChanges.map((e) => e.categoryId), ['b', 'c', 'a']);
    expect(result.largestChanges.first.delta, -400);
  });

  test('deleted, new or reparented categories never have assumed zero', () {
    final result = trend(
      month(2026, 7, [
        category('old', actual: 999),
        category('child', parent: 'family', actual: 500),
      ]),
      month(2026, 8, [
        category('new', actual: 22),
        category('child', actual: 500),
      ]),
    );
    expect(result?.allComparableCount, 0);
    expect(result?.largestChanges, isEmpty);
  });

  test('duplicate parent IDs and invalid actuals are dropped rather than summed',
      () {
    final result = trend(
      month(2026, 7, [
        category('dupe', actual: 500),
        category('dupe', actual: 900),
        category('broken', actual: double.nan),
        category('clean', actual: -10),
      ]),
      month(2026, 8, [
        category('dupe', actual: 300),
        category('broken', actual: 300),
        category('clean', actual: 20),
      ]),
    );
    expect(result?.allComparableCount, 1);
    expect(result?.largestChanges.single.categoryId, 'clean');
    expect(result?.largestChanges.single.delta, 30);
  });

  test('stale, incomplete, skipped or wrong year comparisons fail closed', () {
    expect(
      trend(
        month(2026, 7, [category('a', actual: 30)]),
        month(2026, 9, [category('a', actual: 100)]),
      ),
      isNull,
    );
    expect(
      trend(month(2026, 6, []), month(2026, 8, [])),
      isNull,
    );
    expect(
      trend(
        month(2026, 11, [category('a', actual: 20)]),
        month(2026, 12, [category('a', actual: 25)]),
        referenceDate: DateTime(2027, 1),
      )?.largestChanges.single.delta,
      5,
    );
  });
}
