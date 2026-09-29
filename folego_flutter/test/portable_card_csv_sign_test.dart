import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/features/transactions/statement_import_parser.dart';

CsvImportDocument _fictional(String body) => parseCsvImport(
      Uint8List.fromList(utf8.encode(
        'Data;Descrição;Valor\n$body',
      )),
    );

CsvImportMapping _asDmy(CsvImportDocument doc) =>
    doc.suggestedMapping.copyWith(
      dateFormat: CsvDateFormat.dmy,
      decimalFormat: CsvDecimalFormat.brazilian,
    );

void main() {
  test('default preserves existing negative-card-purchase semantics', () {
    final doc = _fictional(
      '29/09/2026;COMPRA FICTÍCIA;-95,50\n'
      '29/09/2026;ESTORNO FICTÍCIO;20,00\n',
    );
    final mapping = _asDmy(doc);
    expect(mapping.cardSignConvention, CsvCardSignConvention.purchasesNegative);
    final rows = doc.buildCandidates(
      mapping: mapping,
      sourceKind: StatementImportSourceKind.card,
    );
    expect(rows.first.amountMinor, 9550);
    expect(rows.first.direction, StatementImportDirection.debit);
    expect(rows.first.finalType, StatementImportFinalType.cardPurchase);
    expect(rows.last.direction, StatementImportDirection.credit);
    expect(rows.last.candidateType, StatementImportCandidateType.refundCandidate);
    expect(rows.last.finalType, isNull);
  });

  test('explicit positive-card-purchase convention reverses ONLY signed CSV',
      () {
    final doc = _fictional(
      '29/09/2026;COMPRA FICTÍCIA;95,50\n'
      '29/09/2026;ESTORNO FICTÍCIO;-20,00\n',
    );
    final mapping = _asDmy(doc).copyWith(
      cardSignConvention: CsvCardSignConvention.purchasesPositive,
    );
    final rows = doc.buildCandidates(
      mapping: mapping,
      sourceKind: StatementImportSourceKind.card,
    );
    expect(rows.first.amountMinor, 9550);
    expect(rows.first.direction, StatementImportDirection.debit);
    expect(rows.first.finalType, StatementImportFinalType.cardPurchase);
    expect(rows.last.amountMinor, 2000);
    expect(rows.last.direction, StatementImportDirection.credit);
    expect(rows.last.candidateType, StatementImportCandidateType.refundCandidate);
    expect(rows.last.finalType, isNull);
    expect(mapping.toJson()['card_sign_convention'], 'purchasesPositive');
  });

  test('card payments stay in human review regardless of sign selection', () {
    final doc = _fictional(
      '29/09/2026;PAGAMENTO DA FATURA;-300,00\n',
    );
    final row = doc.buildCandidates(
      mapping: _asDmy(doc).copyWith(
        cardSignConvention: CsvCardSignConvention.purchasesPositive,
      ),
      sourceKind: StatementImportSourceKind.card,
    ).single;
    expect(row.candidateType, StatementImportCandidateType.cardPaymentCandidate);
    expect(row.finalType, isNull);
  });

  test('card CSV separate debit/credit columns must never reverse directions',
      () {
    final doc = parseCsvImport(
      Uint8List.fromList(utf8.encode(
        'Data;Descrição;Débito;Crédito\n'
        '29/09/2026;COMPRA DE TESTE;95,50;\n'
        '29/09/2026;ESTORNO DE TESTE;;20,00\n',
      )),
    );
    final mapping = _asDmy(doc).copyWith(
      cardSignConvention: CsvCardSignConvention.purchasesPositive,
    );
    expect(mapping.amountColumn, isNull);
    final rows = doc.buildCandidates(
      mapping: mapping,
      sourceKind: StatementImportSourceKind.card,
    );
    expect(rows.first.direction, StatementImportDirection.debit);
    expect(rows.first.finalType, StatementImportFinalType.cardPurchase);
    expect(rows.last.direction, StatementImportDirection.credit);
    expect(rows.last.finalType, isNull);
  });

  test('bank and benefit CSV are unaffected by a card-specific preference',
      () {
    final doc = _fictional(
      '29/09/2026;DESPESA FICTÍCIA;-30,00\n'
      '29/09/2026;RECEITA FICTÍCIA;60,00\n',
    );
    final mapping = _asDmy(doc).copyWith(
      cardSignConvention: CsvCardSignConvention.purchasesPositive,
    );
    final accountRows = doc.buildCandidates(
      mapping: mapping,
      sourceKind: StatementImportSourceKind.account,
    );
    expect(accountRows.map((row) => row.direction), [
      StatementImportDirection.debit,
      StatementImportDirection.credit,
    ]);
    expect(accountRows.map((row) => row.finalType), [
      StatementImportFinalType.expense,
      StatementImportFinalType.income,
    ]);
    final benefitRows = doc.buildCandidates(
      mapping: mapping,
      sourceKind: StatementImportSourceKind.benefit,
    );
    expect(benefitRows.map((row) => row.finalType), [
      StatementImportFinalType.benefitExpense,
      StatementImportFinalType.benefitCredit,
    ]);
  });

  test('CSV copyWith preserves sign convention during other mapping edits', () {
    final doc = _fictional('29/09/2026;COMPRA FICTÍCIA;95,50\n');
    final positive = _asDmy(doc).copyWith(
      cardSignConvention: CsvCardSignConvention.purchasesPositive,
    );
    final edited = positive.copyWith(decimalFormat: CsvDecimalFormat.american);
    expect(edited.cardSignConvention, CsvCardSignConvention.purchasesPositive);
    expect(edited.toJson()['card_sign_convention'], 'purchasesPositive');
    expect(edited.toJson()['amount_column'], doc.suggestedMapping.amountColumn);
  });
}
