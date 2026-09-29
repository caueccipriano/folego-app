import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/statement_import_screen.dart';

class _FakeRepo extends Fake implements FolegoRepository {}

Future<void> _openAmbiguousCsv(
  WidgetTester tester, {
  required Future<String> Function(
    List<StatementImportCandidate>,
    Map<String, dynamic>,
  ) onStage,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
    home: StatementImportScreen(
      repository: _FakeRepo(),
      spaceId: 'fictional-test-space',
      bootstrapOverride: () async => const StatementImportBootstrap(
        paymentAccounts: [
          AccountItem(
            id: 'fake-account',
            name: 'Conta fictícia',
            type: 'checking',
          ),
        ],
        benefitAccounts: [],
        cards: [],
        expenseCategories: [],
        incomeCategories: [],
        invoices: [],
      ),
      pickOverride: () async => StatementImportPickedFile(
        name: 'fictional-ambiguous-dates.csv',
        bytes: Uint8List.fromList(utf8.encode(
          'Data;Descrição;Valor\n'
          '03/04/2026;Compra fictícia;-10,00\n'
          '04/05/2026;Outra compra fictícia;-20,00\n',
        )),
      ),
      stageOverride: ({
        required fileType,
        required sourceKind,
        required sourceAccountId,
        required sourceCardId,
        required sourceInstitution,
        required fingerprint,
        required configuration,
        required candidates,
      }) async {
        expect(fileType, StatementImportFileType.csv);
        expect(sourceKind, StatementImportSourceKind.account);
        expect(sourceAccountId, 'fake-account');
        expect(sourceCardId, isNull);
        return onStage(candidates, configuration);
      },
      rowsLoaderOverride: (_) async => const <StatementImportRow>[],
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('statement-import-destination-account')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conta fictícia').last);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('statement-import-destination-continue')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('statement-import-csv-mapping')),
      findsOneWidget);
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder target, {
  double delta = 200,
}) async {
  final list = find.descendant(
    of: find.byKey(const ValueKey('statement-import-csv-mapping')),
    matching: find.byType(Scrollable),
  ).first;
  await tester.scrollUntilVisible(target, delta, scrollable: list);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ambiguous dates require manual selection before any staging',
      (tester) async {
    var stageCalls = 0;
    await _openAmbiguousCsv(tester, onStage: (rows, config) async {
      stageCalls++;
      return 'fictional-batch';
    });

    expect(find.textContaining('datas ambíguas'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('statement-import-ambiguous-date-guidance')),
      findsWidgets,
    );

    final stage = find.byKey(const ValueKey('statement-import-stage-csv'));
    await _scrollTo(tester, stage);
    await tester.tap(stage);
    await tester.pumpAndSettle();

    expect(stageCalls, 0);
    expect(find.textContaining('datas ambíguas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit DD/MM selection makes the real wizard stage dates',
      (tester) async {
    var stageCalls = 0;
    await _openAmbiguousCsv(tester, onStage: (rows, config) async {
      stageCalls++;
      expect(rows, hasLength(2));
      expect(rows.map((item) => item.localDate),
          ['2026-04-03', '2026-05-04']);
      expect(rows.first.amountMinor, 1000);
      expect((config['mapping'] as Map<String, dynamic>)['date_format'],
          'dmy');
      return 'fictional-batch';
    });

    final dateField =
        find.byKey(const ValueKey('statement-import-csv-date-format'));
    await _scrollTo(tester, dateField);
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DD/MM/AAAA').last);
    await tester.pumpAndSettle();

    final stage = find.byKey(const ValueKey('statement-import-stage-csv'));
    await _scrollTo(tester, stage);
    await tester.tap(stage);
    await tester.pumpAndSettle();

    expect(stageCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
