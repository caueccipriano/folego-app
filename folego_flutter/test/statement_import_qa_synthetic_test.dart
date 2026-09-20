import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/features/transactions/statement_import_parser.dart';

Uint8List _bytes(String value) => Uint8List.fromList(utf8.encode(value));

void main() {
  group('QA synthetic statement imports', () {
    test('conta BR mistura renda, gasto e itens sensíveis sem auto-confirmar', () {
      final doc = parseCsvImport(_bytes(
        'data;descricao;valor\n'
        '15/09/2026;SALARIO EMPRESA;6000,00\n'
        '15/09/2026;PIX JOAO;-120,50\n'
        '16/09/2026;TRANSFERENCIA ENTRE CONTAS;-500,00\n'
        '17/09/2026;PGTO FATURA VISA;-800,00\n'
        '18/09/2026;ESTORNO MERCADO;45,90\n'
        '19/09/2026;SALDO INICIAL;1000,00\n',
      ));
      final rows = doc.buildCandidates(
        mapping: doc.suggestedMapping.copyWith(
          decimalFormat: CsvDecimalFormat.brazilian,
          dateFormat: CsvDateFormat.dmy,
        ),
        sourceKind: StatementImportSourceKind.account,
      );

      expect(rows, hasLength(6));
      expect(rows[0].finalType, StatementImportFinalType.income);
      expect(rows[1].finalType, StatementImportFinalType.expense);
      expect(rows[2].candidateType, StatementImportCandidateType.transferCandidate);
      expect(rows[2].finalType, isNull);
      expect(rows[3].candidateType, StatementImportCandidateType.cardPaymentCandidate);
      expect(rows[3].finalType, isNull);
      expect(rows[4].candidateType, StatementImportCandidateType.refundCandidate);
      expect(rows[4].finalType, isNull);
      expect(rows[5].candidateType, StatementImportCandidateType.unknown);
      expect(rows[5].finalType, isNull);
    });

    test('cartao com compras negativas e estorno positivo fica conservador', () {
      final doc = parseCsvImport(_bytes(
        'date,description,amount\n'
        '2026-09-15,UBER *TRIP,-35.90\n'
        '2026-09-16,MERCADO CENTRAL,-245.67\n'
        '2026-09-17,ESTORNO LOJA,59.90\n',
      ));
      final rows = doc.buildCandidates(
        mapping: doc.suggestedMapping.copyWith(
          decimalFormat: CsvDecimalFormat.american,
          dateFormat: CsvDateFormat.iso,
        ),
        sourceKind: StatementImportSourceKind.card,
      );

      expect(rows, hasLength(3));
      expect(rows[0].finalType, StatementImportFinalType.cardPurchase);
      expect(rows[1].finalType, StatementImportFinalType.cardPurchase);
      expect(rows[2].candidateType, StatementImportCandidateType.refundCandidate);
      expect(rows[2].finalType, isNull);
    });

    test('beneficio preserva credito e gasto como dimensao propria', () {
      final doc = parseCsvImport(_bytes(
        'data;descricao;debito;credito\n'
        '01/09/2026;CREDITO VR;;620,00\n'
        '02/09/2026;ALMOCO;31,00;\n'
        '03/09/2026;PADARIA;12,50;\n',
      ));
      final rows = doc.buildCandidates(
        mapping: doc.suggestedMapping.copyWith(
          decimalFormat: CsvDecimalFormat.brazilian,
          dateFormat: CsvDateFormat.dmy,
        ),
        sourceKind: StatementImportSourceKind.benefit,
      );

      expect(rows.map((e) => e.finalType), [
        StatementImportFinalType.benefitCredit,
        StatementImportFinalType.benefitExpense,
        StatementImportFinalType.benefitExpense,
      ]);
    });

    test('CSV com aspas, acentos e ponto e virgula dentro da descricao', () {
      final doc = parseCsvImport(_bytes(
        'data;descricao;valor\n'
        '15/09/2026;"Restaurante São João; almoço";-89,90\n',
      ));
      final row = doc.buildCandidates(
        mapping: doc.suggestedMapping.copyWith(
          decimalFormat: CsvDecimalFormat.brazilian,
          dateFormat: CsvDateFormat.dmy,
        ),
        sourceKind: StatementImportSourceKind.account,
      ).single;

      expect(row.description, 'Restaurante São João; almoço');
      expect(row.amountMinor, 8990);
      expect(row.finalType, StatementImportFinalType.expense);
    });

    test('limite exato de 2000 linhas é aceito', () {
      final buffer = StringBuffer('data;descricao;valor\n');
      for (var i = 0; i < 2000; i++) {
        buffer.writeln('15/09/2026;COMPRA $i;-1,00');
      }
      final doc = parseCsvImport(_bytes(buffer.toString()));
      final rows = doc.buildCandidates(
        mapping: doc.suggestedMapping.copyWith(
          decimalFormat: CsvDecimalFormat.brazilian,
          dateFormat: CsvDateFormat.dmy,
        ),
        sourceKind: StatementImportSourceKind.account,
      );
      expect(rows, hasLength(2000));
    });

    test('2001 linhas são recusadas antes de qualquer lançamento', () {
      final buffer = StringBuffer('data;descricao;valor\n');
      for (var i = 0; i < 2001; i++) {
        buffer.writeln('15/09/2026;COMPRA $i;-1,00');
      }
      expect(
        () => parseCsvImport(_bytes(buffer.toString())),
        throwsA(isA<StatementImportParseException>()),
      );
    });

    test('valor zero é rejeitado e não vira lançamento silencioso', () {
      final doc = parseCsvImport(_bytes(
        'data;descricao;valor\n'
        '15/09/2026;AJUSTE;0,00\n',
      ));
      expect(
        () => doc.buildCandidates(
          mapping: doc.suggestedMapping.copyWith(
            decimalFormat: CsvDecimalFormat.brazilian,
            dateFormat: CsvDateFormat.dmy,
          ),
          sourceKind: StatementImportSourceKind.account,
        ),
        throwsA(isA<StatementImportParseException>()),
      );
    });
  });
}
