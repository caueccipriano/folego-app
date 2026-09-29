import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/features/transactions/statement_import_parser.dart';

CsvImportDocument _csv(String text) =>
    parseCsvImport(Uint8List.fromList(utf8.encode(text)));

List<StatementImportCandidate> _candidates(
  CsvImportDocument document, {
  CsvDateFormat? dateFormat,
}) => document.buildCandidates(
      sourceKind: StatementImportSourceKind.account,
      mapping: document.suggestedMapping.copyWith(
        dateFormat: dateFormat,
        decimalFormat: CsvDecimalFormat.brazilian,
      ),
    );

void main() {
  group('same-column CSV date conventions are safe for all accounts', () {
    test('autodetect refuses 03/04 when every date has two possible meanings',
        () {
      final doc = _csv(
        'Data;Descrição;Valor\n'
        '03/04/2026;Despesa fictícia;-10,00\n'
        '04/05/2026;Outro gasto fictício;-20,00\n',
      );
      expect(doc.autoDateWarning(doc.suggestedMapping),
          contains('datas ambíguas'));
      expect(
        () => _candidates(doc),
        throwsA(isA<StatementImportParseException>()),
      );
    });

    test('both explicit date choices yield distinct months with same money',
        () {
      final doc = _csv(
        'Data;Descrição;Valor\n'
        '03/04/2026;Despesa fictícia;-10,00\n',
      );
      final dmy = _candidates(doc, dateFormat: CsvDateFormat.dmy).single;
      final mdy = _candidates(doc, dateFormat: CsvDateFormat.mdy).single;
      expect(dmy.localDate, '2026-04-03');
      expect(mdy.localDate, '2026-03-04');
      expect(dmy.amountMinor, mdy.amountMinor);
      expect(dmy.finalType, StatementImportFinalType.expense);
      expect(mdy.finalType, StatementImportFinalType.expense);
      expect(doc.autoDateWarning(doc.suggestedMapping.copyWith(
        dateFormat: CsvDateFormat.mdy,
      )), isNull);
    });

    test('same file with 27/09 disambiguates 03/04 as DD/MM', () {
      final doc = _csv(
        'Data;Descrição;Valor\n'
        '27/09/2026;Primeiro exemplo;-10,00\n'
        '03/04/2026;Outro exemplo;-20,00\n',
      );
      expect(doc.autoDateWarning(doc.suggestedMapping), isNull);
      final rows = _candidates(doc);
      expect(rows.map((row) => row.localDate),
          ['2026-09-27', '2026-04-03']);
    });

    test('same file with 09/27 disambiguates 03/04 as MM/DD', () {
      final doc = _csv(
        'Date;Description;Amount\n'
        '09/27/2026;Fictional entry;-10,00\n'
        '03/04/2026;Another fictional entry;-20,00\n',
      );
      expect(doc.autoDateWarning(doc.suggestedMapping), isNull);
      final rows = _candidates(doc);
      expect(rows.map((row) => row.localDate),
          ['2026-09-27', '2026-03-04']);
    });

    test('mixed DD/MM and MM/DD evidence fails before any candidate is made',
        () {
      final doc = _csv(
        'Data;Descrição;Valor\n'
        '27/09/2026;Fictício um;-10,00\n'
        '09/27/2026;Fictício dois;-20,00\n',
      );
      expect(doc.autoDateWarning(doc.suggestedMapping),
          contains('mistura formatos'));
      expect(
        () => _candidates(doc),
        throwsA(isA<StatementImportParseException>()),
      );
    });

    test('ISO mixed with slash-date format fails safe', () {
      final doc = _csv(
        'Data;Descrição;Valor\n'
        '2026-09-27;Fictício um;-10,00\n'
        '03/04/2026;Fictício dois;-20,00\n',
      );
      expect(doc.autoDateWarning(doc.suggestedMapping),
          contains('mistura formatos'));
      expect(
        () => _candidates(doc),
        throwsA(isA<StatementImportParseException>()),
      );
    });

    test('all ISO dates remain valid without a manual question', () {
      final doc = _csv(
        'Date;Description;Amount\n'
        '2026-09-27;Fictitious one;-10,00\n'
        '2026-04-03;Fictitious two;-20,00\n',
      );
      expect(doc.autoDateWarning(doc.suggestedMapping), isNull);
      expect(_candidates(doc).map((e) => e.localDate),
          ['2026-09-27', '2026-04-03']);
    });

    test('same-number day/month is invariant under either locale', () {
      final doc = _csv(
        'Data;Descrição;Valor\n'
        '03/03/2026;Despesa fictícia;-10,00\n',
      );
      expect(doc.autoDateWarning(doc.suggestedMapping), isNull);
      expect(_candidates(doc).single.localDate, '2026-03-03');
    });

    test('standalone parseCsvDate never guesses different-month ambiguity',
        () {
      expect(
        () => parseCsvDate('03/04/2026', CsvDateFormat.auto),
        throwsA(isA<StatementImportParseException>()),
      );
      expect(parseCsvDate('03/04/2026', CsvDateFormat.dmy).localDate,
          '2026-04-03');
      expect(parseCsvDate('03/04/2026', CsvDateFormat.mdy).localDate,
          '2026-03-04');
    });

    test('changing mapped date column rechecks ambiguity for THAT column',
        () {
      final doc = _csv(
        'Data;Data do lançamento;Descrição;Valor\n'
        '27/09/2026;03/04/2026;Fictício um;-10,00\n'
        '28/09/2026;04/05/2026;Fictício dois;-20,00\n',
      );
      // Conflicting date candidates are already unmapped by the previous
      // generic import safety task; only deliberate mapping can continue.
      expect(doc.suggestedMapping.dateColumn, isNull);
      final dateIndex0 = doc.suggestedMapping.copyWith(dateColumn: 0);
      final dateIndex1 = doc.suggestedMapping.copyWith(dateColumn: 1);
      expect(doc.autoDateWarning(dateIndex0), isNull);
      expect(doc.autoDateWarning(dateIndex1), contains('datas ambíguas'));
      expect(
        doc.buildCandidates(
          sourceKind: StatementImportSourceKind.account,
          mapping: dateIndex0.copyWith(
            decimalFormat: CsvDecimalFormat.brazilian,
          ),
        ).length,
        2,
      );
      expect(
        () => doc.buildCandidates(
          sourceKind: StatementImportSourceKind.account,
          mapping: dateIndex1.copyWith(
            decimalFormat: CsvDecimalFormat.brazilian,
          ),
        ),
        throwsA(isA<StatementImportParseException>()),
      );
    });
  });
}
