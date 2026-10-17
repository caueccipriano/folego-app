import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/category_tag.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/profile/financial_organization_data_source.dart';
import 'package:folego/features/profile/financial_organization_screen.dart';

class _FakeRepository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOrganizationDataSource implements FinancialOrganizationDataSource {
  final requestedCategorySpaceIds = <String>[];
  final requestedMarkerSpaceIds = <String>[];
  final a = Completer<List<CategoryItem>>();
  final b = Completer<List<CategoryItem>>();

  @override
  Future<FinancialSpace> getPrimarySpace() =>
      throw StateError('active financial space must be passed in');

  @override
  Future<List<CategoryItem>> listCategories(String spaceId) {
    requestedCategorySpaceIds.add(spaceId);
    return spaceId == 'space-a' ? a.future : b.future;
  }

  @override
  Future<List<CategoryTag>> listMarkers(String spaceId) async {
    requestedMarkerSpaceIds.add(spaceId);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('organization reads the selected space and ignores delayed data from another',
      (tester) async {
    tester.view.physicalSize = const Size(430, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dataSource = _FakeOrganizationDataSource();
    final repository = _FakeRepository();

    Widget app(String spaceId) => MaterialApp(
          home: FinancialOrganizationScreen(
            repository: repository,
            spaceId: spaceId,
            dataSource: dataSource,
          ),
        );

    await tester.pumpWidget(app('space-a'));
    await tester.pump();
    expect(dataSource.requestedCategorySpaceIds, contains('space-a'));

    await tester.pumpWidget(app('space-b'));
    await tester.pump();
    await tester.pump();
    expect(dataSource.requestedCategorySpaceIds, contains('space-b'));

    // Finish the first space *after* the user navigates to another.
    dataSource.a.complete(const [
      CategoryItem(
        id: 'cat-a',
        name: 'Categoria exclusiva A',
        essential: false,
        kind: 'expense',
      ),
    ]);
    await tester.pump();
    expect(find.text('Categoria exclusiva A'), findsNothing);

    dataSource.b.complete(const [
      CategoryItem(
        id: 'cat-b',
        name: 'Categoria exclusiva B',
        essential: false,
        kind: 'expense',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Categoria exclusiva B'), findsOneWidget);
    expect(find.text('Categoria exclusiva A'), findsNothing);
    expect(dataSource.requestedMarkerSpaceIds,
        containsAll(['space-a', 'space-b']));
  });
}
