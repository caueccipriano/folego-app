import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/features/transactions/statement_import_parser.dart';

CsvImportDocument _fictional(String csv) =>
    parseCsvImport(Uint8List.fromList(utf8.encode(csv)));

List<StatementImportCandidate> _rows(
  String csv, {
  StatementImportSourceKind source = StatementImportSourceKind.card,
  CsvCardSignConvention choice = CsvCardSignConvention.purchasesNegative,
}) {
  final doc = _fictional(csv);
  return doc.buildCandidates(
    sourceKind: source,
    mapping: doc.suggestedMapping.copyWith(
      decimalFormat: CsvDecimalFormat.brazilian,
      dateFormat: CsvDateFormat.dmy,
      cardSignConvention: choice,
    ),
  );
}

void main() {
  const positiveConvention = CsvCardSignConvention.purchasesPositive;

  test('signed negative card purchase remains expense, not a refund', () {
    final rows = _rows(
      'Data;Descrição;Valor\n'
      '28/09/2026;COMPRA FICTÍCIA;-35,90\n'
      '29/09/2026;ESTORNO FICTÍCIO;8,90\n',
    );
    expect(rows[0].amountMinor, 3590);
    expect(rows[0].direction, StatementImportDirection.debit);
    expect(rows[0].finalType, StatementImportFinalType.cardPurchase);
    expect(rows[1].direction, StatementImportDirection.credit);
    expect(rows[1].candidateType, StatementImportCandidateType.refundCandidate);
    expect(rows[1].finalType, isNull); // still explicitly reviewed
  });

  test('explicit positive purchase flips sign but preserves absolute money', () {
    final rows = _rows(
      'Data;Descrição;Valor\n'
      '28/09/2026;COMPRA FICTÍCIA;35,90\n'
      '29/09/2026;ESTORNO FICTÍCIO;-8,90\n',
      choice: positiveConvention,
    );
    expect(rows[0].amountMinor, 3590);
    expect(rows[0].direction, StatementImportDirection.debit);
    expect(rows[0].finalType, StatementImportFinalType.cardPurchase);
    expect(rows[1].amountMinor, 890);
    expect(rows[1].direction, StatementImportDirection.credit);
    expect(rows[1].candidateType, StatementImportCandidateType.refundCandidate);
    expect(rows[1].finalType, isNull);
  });

  test('positive purchase sign never auto-confirms credit card bill payments', () {
    final rows = _rows(
      'Data;Descrição;Valor\n'
      '28/09/2026;PAGAMENTO FATURA FICTÍCIA;-450,00\n',
      choice: positiveConvention,
    );
    expect(rows.single.direction, StatementImportDirection.credit);
    expect(rows.single.candidateType,
        StatementImportCandidateType.cardPaymentCandidate);
    expect(rows.single.finalType, isNull);
  });

  test('account debits and credits never reverse from a card-only selection', () {
    final rows = _rows(
      'Data;Descrição;Valor\n'
      '28/09/2026;DESPESA FICTÍCIA;-35,90\n'
      '29/09/2026;SALÁRIO FICTÍCIO;1200,00\n',
      choice: positiveConvention,
      source: StatementImportSourceKind.account,
    );
    expect(rows[0].direction, StatementImportDirection.debit);
    expect(rows[0].finalType, StatementImportFinalType.expense);
    expect(rows[1].direction, StatementImportDirection.credit);
    expect(rows[1].finalType, StatementImportFinalType.income);
  });

  test('benefit credit and debit are unaffected by card polarity', () {
    final rows = _rows(
      'Data;Descrição;Valor\n'
      '28/09/2026;REFEIÇÃO FICTÍCIA;-31,00\n'
      '29/09/2026;CRÉDITO BENEFÍCIO;250,00\n',
      choice: positiveConvention,
      source: StatementImportSourceKind.benefit,
    );
    expect(rows[0].finalType, StatementImportFinalType.benefitExpense);
    expect(rows[1].finalType, StatementImportFinalType.benefitCredit);
  });

  test('explicit split debit/credit headings must never be reversed', () {
    final doc = _fictional(
      'Data;Descrição;Débito;Crédito\n'
      '28/09/2026;COMPRA FICTÍCIA;35,90;\n'
      '29/09/2026;ESTORNO FICTÍCIO;;8,90\n',
    );
    expect(doc.suggestedMapping.amountColumn, isNull);
    final rows = doc.buildCandidates(
      sourceKind: StatementImportSourceKind.card,
      mapping: doc.suggestedMapping.copyWith(
        decimalFormat: CsvDecimalFormat.brazilian,
        dateFormat: CsvDateFormat.dmy,
        cardSignConvention: positiveConvention,
      ),
    );
    expect(rows[0].direction, StatementImportDirection.debit);
    expect(rows[0].finalType, StatementImportFinalType.cardPurchase);
    expect(rows[1].direction, StatementImportDirection.credit);
    expect(rows[1].finalType, isNull);
  });

  test('mapping persists audited signed-card interpretation in stage config', () {
    final doc = _fictional(
      'Data;Descrição;Valor\n'
      '28/09/2026;COMPRA FICTÍCIA;35,90\n',
    );
    expect(doc.suggestedMapping.cardSignConvention,
        CsvCardSignConvention.unselected);
    final chosen = doc.suggestedMapping.copyWith(
      cardSignConvention: positiveConvention,
    );
    expect(chosen.toJson()['card_sign_convention'], 'purchasesPositive');
    expect(chosen.amountColumn, 2);
    expect(chosen.isComplete, isTrue);
  });

  test('direct signed-card parser is fail-closed until sign is explicitly set', () {
    final doc = _fictional(
      'Data;Descrição;Valor\n'
      '28/09/2026;COMPRA FICTÍCIA;35,90\n',
    );
    final unmapped = doc.suggestedMapping.copyWith(
      dateFormat: CsvDateFormat.dmy,
      decimalFormat: CsvDecimalFormat.brazilian,
    );
    expect(unmapped.cardSignConvention, CsvCardSignConvention.unselected);
    expect(
      () => doc.buildCandidates(
        sourceKind: StatementImportSourceKind.card,
        mapping: unmapped,
      ),
      throwsA(isA<StatementImportParseException>()),
    );
    expect(
      doc.buildCandidates(
        sourceKind: StatementImportSourceKind.account,
        mapping: unmapped,
      ).single.finalType,
      StatementImportFinalType.income,
    );
    final confirmed = doc.buildCandidates(
      sourceKind: StatementImportSourceKind.card,
      mapping: unmapped.copyWith(
        cardSignConvention: CsvCardSignConvention.purchasesPositive,
      ),
    );
    expect(confirmed.single.direction, StatementImportDirection.debit);
    expect(confirmed.single.finalType, StatementImportFinalType.cardPurchase);
  });

  test('without positive opt-in a positive signed card amount stays for review', () {
    final rows = _rows(
      'Data;Descrição;Valor\n'
      '28/09/2026;COMPRA FICTÍCIA;35,90\n',
    );
    expect(rows.single.direction, StatementImportDirection.credit);
    expect(rows.single.candidateType,
        StatementImportCandidateType.refundCandidate);
    expect(rows.single.finalType, isNull);
  });

  test('zero amount and ambiguous currency remain rejected even after choice',
      () {
    expect(
      () => _rows(
        'Data;Descrição;Valor\n'
        '28/09/2026;COMPRA FICTÍCIA;0\n',
        choice: positiveConvention,
      ),
      throwsA(isA<StatementImportParseException>()),
    );
    final doc = _fictional(
      'Data;Descrição;Valor\n'
      '28/09/2026;COMPRA FICTÍCIA;1.234\n',
    );
    expect(
      () => doc.buildCandidates(
        sourceKind: StatementImportSourceKind.card,
        mapping: doc.suggestedMapping.copyWith(
          cardSignConvention: positiveConvention,
        ),
      ),
      throwsA(isA<StatementImportParseException>()),
    );
  });
}
