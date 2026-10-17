import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/transaction_filters.dart';
import 'package:folego/features/transactions/transaction_filter_sheet.dart';

void main() {
  testWidgets('filter sheet shows three review destinations without changing header',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opened = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showTransactionFilters(
            context: context,
            initial: TransactionFilters.empty(),
            options: TransactionFilterOptions.empty(),
            onOpenReviewHub: opened.add,
          ),
          child: const Text('filtros'),
        )),
      ),
    ));

    await tester.tap(find.text('filtros').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transactions-review-comments')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('transactions-review-pending')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('transactions-review-others')),
        findsOneWidget);

    final action = find.byKey(const ValueKey('transactions-review-comments'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(opened, [0]);
    expect(find.text('filtros'), findsOneWidget);
  });

  testWidgets('review links are omitted when parent has no callback',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TransactionFilterSheet(
          initial: TransactionFilters(),
          options: TransactionFilterOptions(),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('transactions-review-comments')),
        findsNothing);
  });
}
