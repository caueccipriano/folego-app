import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/features/transactions/statement_import_parser.dart';

Uint8List _fictionalCsv(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('universal CSV suggestions — no private bank/provider exports', () {
    test('Portuguese headings, BRL symbol and account running balance', () {
      final doc = parseCsvImport(_fictionalCsv(
        'Data da Transação;Descrição;Valor (R\$);Saldo após transação;Categoria\n'
        '27/09/2026;Compra fictícia;-125,90;1.234,56;Alimentação\n',
      ));
      expect(doc.hasHeader, isTrue);
      expect(doc.suggestedMapping.dateColumn, 0);
      expect(doc.suggestedMapping.descriptionColumn, 1);
      expect(doc.suggestedMapping.amountColumn, 2);
      expect(doc.suggestedMapping.balanceColumn, 3);
      expect(doc.suggestedMapping.categoryColumn, 4);
      final rows = doc.buildCandidates(
        mapping: doc.suggestedMapping.copyWith(
          dateFormat: CsvDateFormat.dmy,
          decimalFormat: CsvDecimalFormat.brazilian,
        ),
        sourceKind: StatementImportSourceKind.account,
      );
      expect(rows, hasLength(1));
      expect(rows.single.amountMinor, 12590);
      expect(rows.single.direction, StatementImportDirection.debit);
      expect(rows.single.originalFields['balance_after'], '1.234,56');
      expect(rows.single.originalFields['file_category'], 'Alimentação');
    });

    test('split Portuguese debit/credit headings map without treating balance as cash', () {
      final doc = parseCsvImport(_fictionalCsv(
        'Data do lançamento;Histórico;Débito;Crédito;Saldo\n'
        '28/09/2026;Despesa de teste;10,00;;500,00\n'
        '29/09/2026;Receita de teste;;60,00;560,00\n',
      ));
      final mapping = doc.suggestedMapping;
      expect(mapping.dateColumn, 0);
      expect(mapping.descriptionColumn, 1);
      expect(mapping.amountColumn, isNull);
      expect(mapping.debitColumn, 2);
      expect(mapping.creditColumn, 3);
      expect(mapping.balanceColumn, 4);
      final rows = doc.buildCandidates(
        mapping: mapping.copyWith(
          dateFormat: CsvDateFormat.dmy,
          decimalFormat: CsvDecimalFormat.brazilian,
        ),
        sourceKind: StatementImportSourceKind.account,
      );
      expect(rows.map((r) => r.amountMinor), [1000, 6000]);
      expect(rows.map((r) => r.direction), [
        StatementImportDirection.debit,
        StatementImportDirection.credit,
      ]);
    });

    test('English generic export headers still map ISO dates and signed money', () {
      final doc = parseCsvImport(_fictionalCsv(
        'Transaction Date,Details,Amount,Running Balance,Merchant\n'
        '2026-09-29,Fictional example,-53.40,600.20,Example\n',
      ));
      expect(doc.suggestedMapping.dateColumn, 0);
      expect(doc.suggestedMapping.descriptionColumn, 1);
      expect(doc.suggestedMapping.amountColumn, 2);
      final row = doc.buildCandidates(
        mapping: doc.suggestedMapping,
        sourceKind: StatementImportSourceKind.account,
      ).single;
      expect(row.amountMinor, 5340);
      expect(row.direction, StatementImportDirection.debit);
    });

    test('duplicate plausible signed money columns FAIL CLOSED', () {
      final mapping = suggestCsvMapping([
        'Data',
        'Descrição',
        'Valor (R\$)',
        'Valor',
        'Saldo',
      ]);
      expect(mapping.dateColumn, 0);
      expect(mapping.amountColumn, isNull);
      expect(mapping.debitColumn, isNull);
      expect(mapping.creditColumn, isNull);
      expect(mapping.isComplete, isFalse);
    });

    test('two distinct transaction date columns require manual selection', () {
      final mapping = suggestCsvMapping([
        'Data da compra',
        'Data da transação',
        'Descrição',
        'Valor',
      ]);
      expect(mapping.dateColumn, isNull);
      expect(mapping.isComplete, isFalse);
    });

    test('one purchase date is not silently replaced by payment date', () {
      final mapping = suggestCsvMapping([
        'Data da compra',
        'Data do pagamento',
        'Estabelecimento',
        'Valor da transação',
      ]);
      expect(mapping.dateColumn, 0);
      expect(mapping.descriptionColumn, 2);
      expect(mapping.amountColumn, 3);
    });

    test('a balance, installment and tax column are NOT transaction amounts', () {
      final mapping = suggestCsvMapping([
        'Data',
        'Descrição',
        'Valor da parcela',
        'Valor dos juros',
        'Saldo',
      ]);
      expect(mapping.amountColumn, isNull);
      expect(mapping.hasValueMapping, isFalse);
      expect(mapping.isComplete, isFalse);
    });

    test('two equally plausible debit labels demand manual mapping', () {
      final mapping = suggestCsvMapping([
        'Data',
        'Descrição',
        'Débito',
        'Saída',
        'Crédito',
      ]);
      expect(mapping.amountColumn, isNull);
      expect(mapping.debitColumn, isNull);
      expect(mapping.creditColumn, isNull);
      expect(mapping.isComplete, isFalse);
    });

    test('signed amount takes precedence over split debit/credit without summing them', () {
      final mapping = suggestCsvMapping([
        'Data',
        'Descrição',
        'Valor',
        'Débito',
        'Crédito',
      ]);
      expect(mapping.amountColumn, 2);
      expect(mapping.debitColumn, isNull);
      expect(mapping.creditColumn, isNull);
    });
  });

  group('ambiguous currencies never silently alter imported money', () {
    for (final suspicious in ['1.234', '1,234']) {
      test('auto detection rejects fictional ambiguous $suspicious', () {
        expect(
          () => parseMoneyMinor(suspicious, CsvDecimalFormat.auto),
          throwsA(isA<StatementImportParseException>()),
        );
      });
    }

    test('explicit locale choice correctly changes interpretation', () {
      expect(parseMoneyMinor('1.234', CsvDecimalFormat.brazilian), 123400);
      expect(parseMoneyMinor('1.234', CsvDecimalFormat.american), 123);
      expect(parseMoneyMinor('1,234', CsvDecimalFormat.brazilian), 123);
      expect(parseMoneyMinor('1,234', CsvDecimalFormat.american), 123400);
    });

    test('auto still accepts conventional unambiguous money examples', () {
      expect(parseMoneyMinor('-1.234,56', CsvDecimalFormat.auto), -123456);
      expect(parseMoneyMinor('-1,234.56', CsvDecimalFormat.auto), -123456);
      expect(parseMoneyMinor('-35,90', CsvDecimalFormat.auto), -3590);
      expect(parseMoneyMinor('-35.90', CsvDecimalFormat.auto), -3590);
    });

    test('ambiguous amount in CSV cannot produce a staged candidate', () {
      final doc = parseCsvImport(_fictionalCsv(
        'Data;Descrição;Valor\n'
        '29/09/2026;Valor ambíguo;-1.234\n',
      ));
      expect(
        () => doc.buildCandidates(
          mapping: doc.suggestedMapping,
          sourceKind: StatementImportSourceKind.account,
        ),
        throwsA(isA<StatementImportParseException>()),
      );
      expect(
        doc.buildCandidates(
          mapping: doc.suggestedMapping.copyWith(
            dateFormat: CsvDateFormat.dmy,
            decimalFormat: CsvDecimalFormat.brazilian,
          ),
          sourceKind: StatementImportSourceKind.account,
        ).single.amountMinor,
        123400,
      );
    });
  });
}
