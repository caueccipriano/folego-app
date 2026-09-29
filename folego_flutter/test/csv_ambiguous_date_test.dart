import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/statement_import_parser.dart';
import 'package:folego/features/transactions/statement_import_screen.dart';

class _FictionalRepository extends Fake implements FolegoRepository {}

CsvImportDocument _file(String csv) =>
    parseCsvImport(Uint8List.fromList(utf8.encode(csv)));

void main() {
  group('day/month ambiguity must be resolved before financial staging', () {
    test('auto refuses two distinct valid interpretations, never guesses BR',
        () {
      for (final text in ['03/04/2026', '03-04-26', '03.04.2026']) {
        expect(
          () => parseCsvDate(text, CsvDateFormat.auto),
          throwsA(isA<StatementImportParseException>()),
          reason: text,
        );
      }
    });

    test('explicit BR/US formats yield distinct, auditable local dates', () {
      expect(
        parseCsvDate('03/04/2026', CsvDateFormat.dmy).localDate,
        '2026-04-03',
      );
      expect(
        parseCsvDate('03/04/2026', CsvDateFormat.mdy).localDate,
        '2026-03-04',
      );
      expect(
        parseCsvDate('2026-04-03', CsvDateFormat.iso).localDate,
        '2026-04-03',
      );
    });

    test('auto permits unambiguous, identical and ISO dates', () {
      expect(parseCsvDate('16/04/2026', CsvDateFormat.auto).localDate,
          '2026-04-16');
      expect(parseCsvDate('04/16/2026', CsvDateFormat.auto).localDate,
          '2026-04-16');
      expect(parseCsvDate('04/04/2026', CsvDateFormat.auto).localDate,
          '2026-04-04');
      expect(parseCsvDate('2026-04-03', CsvDateFormat.auto).localDate,
          '2026-04-03');
    });

    test('per-file scan warns when ANY actual data date is ambiguous', () {
      final doc = _file(
        'Data;Descrição;Valor\n'
        '16/04/2026;Fictício;-10,00\n'
        '03/04/2026;Fictício 2;-25,00\n',
      );
      expect(doc.hasAmbiguousDateSamples(doc.suggestedMapping.dateColumn),
          isTrue);
      expect(doc.hasAmbiguousDateSamples(null), isFalse);
      expect(doc.hasAmbiguousDateSamples(99), isFalse);
      final unambiguous = _file(
        'Data;Descrição;Valor\n'
        '16/04/2026;Fictício;-10,00\n'
        '2026-04-03;Fictício 2;-25,00\n',
      );
      expect(
        unambiguous.hasAmbiguousDateSamples(
          unambiguous.suggestedMapping.dateColumn,
        ),
        isFalse,
      );
    });

    test('unknown date format blocks all CSV candidate staging, not one row',
        () {
      final doc = _file(
        'Data;Descrição;Valor\n'
        '16/04/2026;Fictício 1;-10,00\n'
        '03/04/2026;Fictício 2;-25,00\n',
      );
      expect(
        () => doc.buildCandidates(
          mapping: doc.suggestedMapping,
          sourceKind: StatementImportSourceKind.account,
        ),
        throwsA(isA<StatementImportParseException>()),
      );

      final br = doc.buildCandidates(
        mapping: doc.suggestedMapping.copyWith(dateFormat: CsvDateFormat.dmy),
        sourceKind: StatementImportSourceKind.account,
      );
      expect(br, hasLength(2));
      expect(br.last.localDate, '2026-04-03');
      // The first row's 16/04 is invalid under MDY: a mixed-format file
      // must fail rather than silently flip dates per row.
      expect(
        () => doc.buildCandidates(
          mapping: doc.suggestedMapping.copyWith(dateFormat: CsvDateFormat.mdy),
          sourceKind: StatementImportSourceKind.account,
        ),
        throwsA(isA<StatementImportParseException>()),
      );
    });
  });

  testWidgets('phone wizard warns and cannot stage ambiguous date without choice',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var staged = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatementImportScreen(
        repository: _FictionalRepository(),
        spaceId: 'fictional-space',
        bootstrapOverride: () async => const StatementImportBootstrap(
          paymentAccounts: [
            AccountItem(id: 'fictional-account', name: 'Conta fictícia', type: 'checking'),
          ],
          benefitAccounts: [],
          cards: [],
          expenseCategories: [],
          incomeCategories: [],
          invoices: [],
        ),
        pickOverride: () async => StatementImportPickedFile(
          name: 'date-fixture.csv',
          bytes: Uint8List.fromList(utf8.encode(
            'Data;Descrição;Valor\n'
            '03/04/2026;DESPESA FICTÍCIA;-35,90\n',
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
          staged++;
          expect(candidates.single.localDate, '2026-04-03');
          expect((configuration['mapping'] as Map<String, dynamic>)['date_format'],
              'dmy');
          return 'fictional-batch';
        },
        rowsLoaderOverride: (_) async => const [],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conta fictícia').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('statement-import-destination-continue')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Há datas que podem significar'), findsOneWidget);

    final wizard = find.descendant(
      of: find.byKey(const ValueKey('statement-import-csv-mapping')),
      matching: find.byType(Scrollable),
    ).first;
    final stage = find.byKey(const ValueKey('statement-import-stage-csv'));
    await tester.scrollUntilVisible(stage, 200, scrollable: wizard);
    await tester.tap(stage);
    await tester.pumpAndSettle();
    expect(staged, 0);
    expect(find.textContaining('data ambígua'), findsOneWidget);

    final dateFormat =
        find.byKey(const ValueKey('statement-import-date-format'));
    await tester.scrollUntilVisible(dateFormat, -180, scrollable: wizard);
    await tester.tap(dateFormat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DD/MM/AAAA').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(stage, 200, scrollable: wizard);
    await tester.tap(stage);
    await tester.pumpAndSettle();
    expect(staged, 1);
    expect(tester.takeException(), isNull);
  });
}
