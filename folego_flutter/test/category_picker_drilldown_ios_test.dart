import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/shared/widgets/category_search_picker.dart';

void main() {
  const parent = CategoryItem(
    id: 'beauty', name: 'Beleza & Cuidados', essential: false,
    kind: 'expense',
  );
  const hair = CategoryItem(
    id: 'hair', name: 'Cabelo', essential: false,
    kind: 'expense', parentId: 'beauty',
    parentName: 'Beleza & Cuidados',
  );
  const other = CategoryItem(
    id: 'transport', name: 'Transporte', essential: false,
    kind: 'expense',
  );
  const gas = CategoryItem(
    id: 'gas', name: 'Combustível', essential: false,
    kind: 'expense', parentId: 'transport', parentName: 'Transporte',
  );

  testWidgets('expense picker opens parent before choosing a subcategory',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CategoryItem? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CategorySearchPicker(
          categories: const [parent, hair, other, gas],
          eventType: 'expense',
          drillDown: true,
          onSelected: (item) => chosen = item,
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('category-option-beauty')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-option-hair')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('category-option-beauty')));
    await tester.pump();
    expect(find.byKey(const ValueKey('category-option-hair')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-option-transport')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('category-option-hair')));
    expect(chosen?.id, 'hair');
    expect(tester.takeException(), isNull);
  });

  testWidgets('search finds a subcategory across parent groups',
      (tester) async {
    CategoryItem? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CategorySearchPicker(
          categories: const [parent, hair, other, gas],
          eventType: 'expense',
          drillDown: true,
          onSelected: (item) => chosen = item,
        ),
      ),
    ));
    await tester.enterText(
        find.byKey(const ValueKey('category-search-field')), 'combustível');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-option-gas')));
    expect(chosen?.id, 'gas');
  });

  test('iPhone category modal covers the underlying edit form', () {
    final source =
        File('lib/features/transactions/transaction_edit_sheet.dart')
            .readAsStringSync();
    expect(source, contains('backgroundColor: AppColors.surface('));
    expect(source, contains('barrierColor:'));
    expect(source, contains('height * .94'));
    expect(source, contains('drillDown: !_isIncome'));
  });
}
