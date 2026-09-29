import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/features/transactions/statement_import_parser.dart';

Uint8List _fictionalCsv(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('date import never assigns ambiguous transactions to wrong months', () {
    test('09/10 in automatic mode requires explicit human date order', () {
      expect(
        () => parseCsvDate('09/10/2026', CsvDateFormat.auto),
        throwsA(
          isA<StatementImportParseException>().having(
            (error) => error.message,
            'reason',
            contains('DD/MM/AAAA ou MM/DD/AAAA'),
          ),
        ),
      );
    });

    test('first and last months differ between explicit locales', () {
      final pt = parseCsvDate('09/10/2026', CsvDateFormat.dmy);
      final en = parseCsvDate('09/10/2026', CsvDateFormat.mdy);
      expect(pt.value.month, 10);
      expect(pt.value.day, 9);
      expect(en.value.month, 9);
      expect(en.value.day, 10);
    });

    test('unambiguous 14/09 is safely day-first automatically', () {
      final date = parseCsvDate('14/09/2026', CsvDateFormat.auto);
      expect(date.value.month, 9);
      expect(date.value.day, 14);
    });

    test('unambiguous 09/14 is safely month-first automatically', () {
      final date = parseCsvDate('09/14/2026', CsvDateFormat.auto);
      expect(date.value.month, 9);
      expect(date.value.day, 14);
    });

    test('same month and day have one identical interpretation', () {
      final date = parseCsvDate('10/10/2026', CsvDateFormat.auto);
      expect(date.value.month, 10);
      expect(date.value.day, 10);
    });

    test('ISO remains unambiguous and supported by autodetection', () {
      final date = parseCsvDate('2026-10-09', CsvDateFormat.auto);
      expect(date.value.month, 10);
      expect(date.value.day, 9);
    });

    test('incorrect explicit ISO and calendar-invalid dates still fail', () {
      expect(
        () => parseCsvDate('09/10/2026', CsvDateFormat.iso),
        throwsFormatException,
      );
      expect(
        () => parseCsvDate('31/02/2026', CsvDateFormat.dmy),
        throwsFormatException,
      );
      expect(
        () => parseCsvDate('09/14/2026', CsvDateFormat.dmy),
        throwsFormatException,
      );
    });

    test('do not guess two different dates that are both <= 12', () {
      for (final text in <String>[
        '01/12/2026',
        '12/01/2026',
        '03.04.2026',
        '04-03-26',
      ]) {
        expect(
          () => parseCsvDate(text, CsvDateFormat.auto),
          throwsA(isA<StatementImportParseException>()),
          reason: text,
        );
      }
    });

    test('mixed month formats do not stage partial rows or mutate the ledger',
        () {
      final document = parseCsvImport(_fictionalCsv(
        'Data;Descrição;Valor\n'
        '14/09/2026;ALIMENTO FICTÍCIO;-12,50\n'
        '09/10/2026;SEGUNDA DESPESA FICTÍCIA;-32,50\n',
      ));
      final guessed = document.suggestedMapping.copyWith(
        decimalFormat: CsvDecimalFormat.brazilian,
      );
      expect(document.hasAmbiguousDateValues(guessed), isTrue);
      expect(
        document.hasAmbiguousDateValues(
          guessed.copyWith(dateFormat: CsvDateFormat.dmy),
        ),
        isFalse,
      );
      expect(
        () => document.buildCandidates(
          mapping: guessed,
          sourceKind: StatementImportSourceKind.account,
        ),
        throwsA(isA<StatementImportParseException>()),
      );
      final confirmed = document.buildCandidates(
        mapping: guessed.copyWith(dateFormat: CsvDateFormat.dmy),
        sourceKind: StatementImportSourceKind.account,
      );
      expect(confirmed, hasLength(2));
      expect(confirmed[0].occurredAt.month, 9);
      expect(confirmed[1].occurredAt.month, 10);
      expect(confirmed.map((row) => row.direction), [
        StatementImportDirection.debit,
        StatementImportDirection.debit,
      ]);
    });

    test('bank and card sign conventions do not interfere with date consent',
        () {
      final document = parseCsvImport(_fictionalCsv(
        'Data;Descrição;Valor\n'
        '09/10/2026;COMPRA FICTÍCIA;35,90\n',
      ));
      final mapping = document.suggestedMapping.copyWith(
        decimalFormat: CsvDecimalFormat.brazilian,
        cardSignConvention: CsvCardSignConvention.purchasesPositive,
      );
      expect(
        () => document.buildCandidates(
          mapping: mapping,
          sourceKind: StatementImportSourceKind.card,
        ),
        throwsA(isA<StatementImportParseException>()),
      );
      final confirmed = document.buildCandidates(
        mapping: mapping.copyWith(dateFormat: CsvDateFormat.mdy),
        sourceKind: StatementImportSourceKind.card,
      ).single;
      expect(confirmed.occurredAt.month, 9);
      expect(confirmed.occurredAt.day, 10);
      expect(confirmed.direction, StatementImportDirection.debit);
      expect(confirmed.finalType, StatementImportFinalType.cardPurchase);
    });
  });
}
