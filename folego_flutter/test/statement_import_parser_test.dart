import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/features/transactions/statement_import_parser.dart';

void main() {
  group('CSV import parser', () {
    test('detecta vírgula, cabeçalho, data BR e decimal BR', () {
      final doc = parseCsvImport(Uint8List.fromList(utf8.encode('Data,Descrição,Valor\n16/09/2026,UBER,"-35,90"\n')));
      expect(doc.delimiter, ',');
      expect(doc.hasHeader, isTrue);
      final mapping = doc.suggestedMapping.copyWith(decimalFormat: CsvDecimalFormat.brazilian, dateFormat: CsvDateFormat.dmy);
      final rows = doc.buildCandidates(mapping: mapping, sourceKind: StatementImportSourceKind.account);
      expect(rows.single.amountMinor, 3590);
      expect(rows.single.direction, StatementImportDirection.debit);
      expect(rows.single.finalType, StatementImportFinalType.expense);
      expect(rows.single.localDate, '2026-09-16');
    });

    test('detecta ponto e vírgula e decimal brasileiro com milhares', () {
      final doc = parseCsvImport(Uint8List.fromList(utf8.encode('data;descricao;valor\n16/09/2026;SALARIO;1.234,56\n')));
      expect(doc.delimiter, ';');
      final mapping = doc.suggestedMapping.copyWith(decimalFormat: CsvDecimalFormat.brazilian, dateFormat: CsvDateFormat.dmy);
      final row = doc.buildCandidates(mapping: mapping, sourceKind: StatementImportSourceKind.account).single;
      expect(row.amountMinor, 123456);
      expect(row.direction, StatementImportDirection.credit);
      expect(row.finalType, StatementImportFinalType.income);
    });

    test('detecta tab, data ISO e decimal americano', () {
      final doc = parseCsvImport(Uint8List.fromList(utf8.encode('date\tdescription\tamount\n2026-09-16\tMARKET\t-1,234.56\n')));
      expect(doc.delimiter, '\t');
      final mapping = doc.suggestedMapping.copyWith(decimalFormat: CsvDecimalFormat.american, dateFormat: CsvDateFormat.iso);
      final row = doc.buildCandidates(mapping: mapping, sourceKind: StatementImportSourceKind.account).single;
      expect(row.amountMinor, 123456);
      expect(row.direction, StatementImportDirection.debit);
    });

    test('suporta débito e crédito separados', () {
      final doc = parseCsvImport(Uint8List.fromList(utf8.encode('data;descricao;debito;credito\n16/09/2026;CAFE;12,50;\n17/09/2026;RENDA;;50,00\n')));
      final mapping = doc.suggestedMapping.copyWith(decimalFormat: CsvDecimalFormat.brazilian, dateFormat: CsvDateFormat.dmy);
      final rows = doc.buildCandidates(mapping: mapping, sourceKind: StatementImportSourceKind.account);
      expect(rows.map((e) => e.direction), [StatementImportDirection.debit, StatementImportDirection.credit]);
    });

    test('suporta Latin-1 e ignora linhas vazias', () {
      final bytes = Uint8List.fromList(latin1.encode('data;descrição;valor\n16/09/2026;Café;-10,00\n\n'));
      final doc = parseCsvImport(bytes);
      expect(doc.encoding, 'latin-1');
      expect(doc.rows.length, 1);
      expect(doc.examplesFor(doc.suggestedMapping.descriptionColumn), contains('Café'));
    });

    test('arquivo vazio e CSV malformed falham amigavelmente', () {
      expect(() => parseCsvImport(Uint8List(0)), throwsA(isA<StatementImportParseException>()));
      expect(() => parseCsvRows('data,"descrição\n16/09/2026,teste', ','), throwsA(isA<StatementImportParseException>()));
    });

    test('saldo inicial nunca é classificado como receita', () {
      final classification = classifyStatementRow(
        sourceKind: StatementImportSourceKind.account,
        direction: StatementImportDirection.credit,
        description: 'SALDO INICIAL',
      );
      expect(classification.candidateType, StatementImportCandidateType.unknown);
      expect(classification.finalType, isNull);
    });

    test('PIX genérico não vira transferência automaticamente', () {
      final classification = classifyStatementRow(
        sourceKind: StatementImportSourceKind.account,
        direction: StatementImportDirection.debit,
        description: 'PIX JOAO DA SILVA',
      );
      expect(classification.finalType, StatementImportFinalType.expense);
    });

    test('transferência própria, fatura e refund ficam em revisão', () {
      final own = classifyStatementRow(sourceKind: StatementImportSourceKind.account, direction: StatementImportDirection.debit, description: 'TRANSFERENCIA ENTRE CONTAS');
      final payment = classifyStatementRow(sourceKind: StatementImportSourceKind.account, direction: StatementImportDirection.debit, description: 'PGTO FATURA VISA');
      final refund = classifyStatementRow(sourceKind: StatementImportSourceKind.card, direction: StatementImportDirection.credit, description: 'ESTORNO LOJA');
      expect(own.candidateType, StatementImportCandidateType.transferCandidate);
      expect(own.finalType, isNull);
      expect(payment.candidateType, StatementImportCandidateType.cardPaymentCandidate);
      expect(payment.finalType, isNull);
      expect(refund.candidateType, StatementImportCandidateType.refundCandidate);
      expect(refund.finalType, isNull);
    });

    test('cartão não inventa parcelamento e benefício preserva dimensão', () {
      final card = classifyStatementRow(sourceKind: StatementImportSourceKind.card, direction: StatementImportDirection.debit, description: 'LOJA 1/10');
      final benefit = classifyStatementRow(sourceKind: StatementImportSourceKind.benefit, direction: StatementImportDirection.debit, description: 'ALMOCO');
      expect(card.finalType, StatementImportFinalType.cardPurchase);
      expect(benefit.finalType, StatementImportFinalType.benefitExpense);
    });
  });

  group('OFX import parser', () {
    Uint8List fixture(String name) => File('test/fixtures/import/$name').readAsBytesSync();

    test('SGML extrai FITID, NAME, MEMO, conta, moeda e offset', () {
      final doc = parseOfxImport(fixture('statement_sgml.ofx'), StatementImportSourceKind.account);
      expect(doc.currency, 'BRL');
      expect(doc.bankId, '001');
      expect(doc.accountId, '123456-7');
      expect(doc.accountType, 'CHECKING');
      expect(doc.candidates.length, 2);
      expect(doc.candidates.first.externalId, 'FIT-SGML-001');
      expect(doc.candidates.first.description, contains('UBER *TRIP'));
      expect(doc.candidates.first.description, contains('Corrida fictícia'));
      expect(doc.candidates.first.amountMinor, 3590);
      expect(doc.candidates.first.direction, StatementImportDirection.debit);
      expect(doc.candidates.first.occurredAt.isUtc, isTrue);
    });

    test('XML de cartão extrai compras e deixa crédito para revisão', () {
      final doc = parseOfxImport(fixture('statement_xml.ofx'), StatementImportSourceKind.card);
      expect(doc.isCreditCardStatement, isTrue);
      expect(doc.candidates.length, 2);
      expect(doc.candidates.first.externalId, 'FIT-XML-001');
      expect(doc.candidates.first.finalType, StatementImportFinalType.cardPurchase);
      expect(doc.candidates.last.finalType, isNull);
      expect(doc.candidates.last.candidateType, StatementImportCandidateType.refundCandidate);
    });

    test('OFX inválido falha amigavelmente', () {
      expect(() => parseOfxImport(fixture('invalid.ofx'), StatementImportSourceKind.account), throwsA(isA<StatementImportParseException>()));
    });
  });
}
