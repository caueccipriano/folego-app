import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/credit_card_item.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/statement_import_screen.dart';

class _FakeRepo extends Fake implements FolegoRepository {}

StatementImportBootstrap _fixture(String owner) => StatementImportBootstrap(
      paymentAccounts: [
        AccountItem(
          id: 'fictional-$owner-account',
          name: 'Fictitious account $owner',
          type: 'checking',
        ),
      ],
      benefitAccounts: const <AccountItem>[],
      cards: const <CreditCardItem>[],
      expenseCategories: const <CategoryItem>[],
      incomeCategories: const <CategoryItem>[],
      invoices: const <StatementImportInvoiceOption>[],
    );

StatementImportPickedFile _file(String owner) => StatementImportPickedFile(
      name: 'fictional-$owner.csv',
      bytes: Uint8List.fromList(utf8.encode(
        'Data;Descrição;Valor\n'
        '29/09/2026;Synthetic $owner row;-35,90\n',
      )),
    );

void main() {
  testWidgets('stale A bootstrap NEVER populates reused B financial space',
      (tester) async {
    final repo = _FakeRepo();
    final aLoad = Completer<StatementImportBootstrap>();
    final bLoad = Completer<StatementImportBootstrap>();
    const reused = ValueKey('same-import-route');

    await tester.pumpWidget(MaterialApp(
      home: StatementImportScreen(
        key: reused,
        repository: repo,
        spaceId: 'synthetic-space-A',
        bootstrapOverride: () => aLoad.future,
        pickOverride: () async => _file('A'),
      ),
    ));
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      home: StatementImportScreen(
        key: reused,
        repository: repo,
        spaceId: 'synthetic-space-B',
        bootstrapOverride: () => bLoad.future,
        pickOverride: () async => _file('B'),
      ),
    ));

    aLoad.complete(_fixture('A'));
    await tester.pump();
    expect(find.text('Fictitious account A'), findsNothing);

    bLoad.complete(_fixture('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
    await tester.pumpAndSettle();

    expect(find.text('fictional-B.csv'), findsWidgets);
    expect(find.text('fictional-A.csv'), findsNothing);

    final dropdown = find.byKey(
      const ValueKey('statement-import-destination-account'),
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.text('Fictitious account B'), findsWidgets);
    expect(find.text('Fictitious account A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old A file-picker result is discarded after switching to B',
      (tester) async {
    final repo = _FakeRepo();
    final oldPicker = Completer<StatementImportPickedFile?>();
    const reused = ValueKey('same-import-route');

    await tester.pumpWidget(MaterialApp(
      home: StatementImportScreen(
        key: reused,
        repository: repo,
        spaceId: 'synthetic-space-A',
        bootstrapOverride: () async => _fixture('A'),
        pickOverride: () => oldPicker.future,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      home: StatementImportScreen(
        key: reused,
        repository: repo,
        spaceId: 'synthetic-space-B',
        bootstrapOverride: () async => _fixture('B'),
        pickOverride: () async => _file('B'),
      ),
    ));
    await tester.pumpAndSettle();

    oldPicker.complete(_file('A'));
    await tester.pumpAndSettle();
    expect(find.text('fictional-A.csv'), findsNothing);
    expect(
      find.byKey(const ValueKey('statement-import-pick-file')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
    await tester.pumpAndSettle();
    expect(find.text('fictional-B.csv'), findsWidgets);
    expect(find.text('fictional-A.csv'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('old A staging response cannot open its review in switched B',
      (tester) async {
    final repo = _FakeRepo();
    final oldStage = Completer<String>();
    var aStaged = 0;
    var staleARowsFetched = 0;
    const reused = ValueKey('same-import-route');

    await tester.pumpWidget(MaterialApp(
      home: StatementImportScreen(
        key: reused,
        repository: repo,
        spaceId: 'synthetic-space-A',
        bootstrapOverride: () async => _fixture('A'),
        pickOverride: () async => _file('A'),
        stageOverride: ({
          required fileType,
          required sourceKind,
          required sourceAccountId,
          required sourceCardId,
          required sourceInstitution,
          required fingerprint,
          required configuration,
          required candidates,
        }) {
          aStaged++;
          expect(sourceAccountId, 'fictional-A-account');
          expect(sourceCardId, isNull);
          return oldStage.future; // Fictional pending API response; NO server.
        },
        rowsLoaderOverride: (_) async {
          staleARowsFetched++;
          return const <StatementImportRow>[];
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fictitious account A').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('statement-import-destination-continue')),
    );
    await tester.pumpAndSettle();
    final mapping =
        find.byKey(const ValueKey('statement-import-csv-mapping'));
    await tester.drag(mapping, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statement-import-stage-csv')));
    await tester.pump(); // A's staging request is now pending.
    expect(aStaged, 1);

    await tester.pumpWidget(MaterialApp(
      home: StatementImportScreen(
        key: reused,
        repository: repo,
        spaceId: 'synthetic-space-B',
        bootstrapOverride: () async => _fixture('B'),
        pickOverride: () async => _file('B'),
      ),
    ));
    await tester.pumpAndSettle();
    oldStage.complete('old-A-batch-id');
    await tester.pumpAndSettle();

    expect(staleARowsFetched, 0);
    expect(find.text('fictional-A.csv'), findsNothing);
    expect(find.byKey(const ValueKey('statement-import-review-mobile')),
        findsNothing);
    expect(find.byKey(const ValueKey('statement-import-pick-file')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
    await tester.pumpAndSettle();
    expect(find.text('fictional-B.csv'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

}
