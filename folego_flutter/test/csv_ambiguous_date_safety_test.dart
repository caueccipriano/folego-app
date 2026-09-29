import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/features/transactions/statement_import_parser.dart';

CsvImportDocument _fictional(String content) =>
    parseCsvImport(Uint8List.fromList(utf8.encode(content)));

void main() {
  group('ambiguous international transaction dates fail closed', () {
    for (final ambiguous in <String>[
      '05/06/2026',
      '06/05/2026',
      '11-12-2026',
      '12.11.26',
    ]) {
      test('automatic date parsing refuses ambiguous $ambiguous', () {
        expect(
          () => parseCsvDate(ambiguous, CsvDateFormat.auto),
          throwsA(
            isA<StatementImportParseException>().having(
              (error) => error.message,
              'human-readable correction',
              contains('selecione manualmente'),
            ),
          ),
        );
      });
    }

    test('explicit DMY and MDY produce different verified financial dates',
        () {
      final dmy = parseCsvDate('05/06/2026', CsvDateFormat.dmy);
      final mdy = parseCsvDate('05/06/2026', CsvDateFormat.mdy);
      expect(dmy.localDate, '2026-06-05');
      expect(mdy.localDate, '2026-05-06');
    });

    test('identical month and day need no user choice', () {
      final same = parseCsvDate('05/05/2026', CsvDateFormat.auto);
      expect(same.localDate, '2026-05-05');
    });

    test('known DMY/MDY and ISO remain recognized automatically', () {
      expect(
        parseCsvDate('26/09/2026', CsvDateFormat.auto).localDate,
        '2026-09-26',
      );
      expect(
        parseCsvDate('09/26/2026', CsvDateFormat.auto).localDate,
        '2026-09-26',
      );
      expect(
        parseCsvDate('2026-09-26', CsvDateFormat.auto).localDate,
        '2026-09-26',
      );
    });

    test('invalid or impossible dates are rejected instead of normalized',
        () {
      expect(
        () => parseCsvDate('31/02/2026', CsvDateFormat.dmy),
        throwsFormatException,
      );
      expect(
        () => parseCsvDate('13/14/2026', CsvDateFormat.auto),
        throwsFormatException,
      );
    });

    test('unreviewed ambiguous CSV cannot create ANY staging candidates',
        () {
      final document = _fictional(
        'Data;Descrição;Valor\n'
        '15/09/2026;Primeira compra fictícia;-25,00\n'
        '05/06/2026;Compra ambígua fictícia;-99,00\n',
      );
      expect(document.suggestedMapping.isComplete, isTrue);
      expect(
        () => document.buildCandidates(
          mapping: document.suggestedMapping,
          sourceKind: StatementImportSourceKind.account,
        ),
        throwsA(isA<StatementImportParseException>()),
      );
      // After a HUMAN date-format choice, all rows must preserve the
      // intended date; no partial import was written by buildCandidates.
      final rows = document.buildCandidates(
        mapping: document.suggestedMapping.copyWith(
          dateFormat: CsvDateFormat.dmy,
        ),
        sourceKind: StatementImportSourceKind.account,
      );
      expect(rows, hasLength(2));
      expect(rows[0].localDate, '2026-09-15');
      expect(rows[1].localDate, '2026-06-05');
      expect(rows[1].amountMinor, 9900);
    });

    test('US choice applies consistently across an entire synthetic CSV',
        () {
      final document = _fictional(
        'Date,Description,Amount\n'
        '09/15/2026,Fictional unambiguous row,-25.00\n'
        '05/06/2026,Fictional ambiguous row,-99.00\n',
      );
      final rows = document.buildCandidates(
        mapping: document.suggestedMapping.copyWith(
          dateFormat: CsvDateFormat.mdy,
        ),
        sourceKind: StatementImportSourceKind.account,
      );
      expect(rows[0].localDate, '2026-09-15');
      expect(rows[1].localDate, '2026-05-06');
    });

    test('verified source date never controls amount sign or account type',
        () {
      final document = _fictional(
        'Data;Descrição;Valor\n'
        '05/06/2026;Compra fictícia;-35,90\n',
      );
      final row = document.buildCandidates(
        mapping: document.suggestedMapping.copyWith(
          dateFormat: CsvDateFormat.dmy,
          decimalFormat: CsvDecimalFormat.brazilian,
        ),
        sourceKind: StatementImportSourceKind.account,
      ).single;
      expect(row.direction, StatementImportDirection.debit);
      expect(row.finalType, StatementImportFinalType.expense);
      expect(row.amountMinor, 3590);
    });
  });
}
