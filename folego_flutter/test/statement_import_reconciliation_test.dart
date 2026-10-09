import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/features/transactions/statement_import_reconciliation.dart';

void main() {
  const accounts = [
    AccountItem(id: 'cash-a', name: 'Conta A', type: 'checking'),
    AccountItem(id: 'cash-b', name: 'Conta B', type: 'checking'),
  ];
  const invoices = [
    StatementImportInvoiceOption(
      id: 'invoice-a',
      cardId: 'card-a',
      cardName: 'Cartão A',
      dueDate: null,
      status: 'open',
    ),
  ];

  StatementImportRow row({
    String id = 'row-1',
    StatementImportDuplicateState duplicate = StatementImportDuplicateState.unique,
    StatementImportDecision decision = StatementImportDecision.review,
    StatementImportFinalType? finalType = StatementImportFinalType.expense,
    StatementImportRowStatus status = StatementImportRowStatus.staged,
    StatementImportDirection direction = StatementImportDirection.debit,
    String? counterpart,
    String? invoice,
  }) => StatementImportRow(
    id: id,
    batchId: 'batch-test',
    rowNumber: 1,
    occurredAt: DateTime(2026, 10, 9),
    description: 'Compra fictícia',
    amount: 35.90,
    direction: direction,
    candidateType: StatementImportCandidateType.expense,
    finalType: finalType,
    duplicateState: duplicate,
    decision: decision,
    status: status,
    counterpartAccountId: counterpart,
    invoiceId: invoice,
  );

  String? validate(
    StatementImportRow value, {
    StatementImportSourceKind source = StatementImportSourceKind.account,
    String sourceId = 'cash-a',
  }) => validateStatementImportReconciliation(
    row: value,
    sourceKind: source,
    sourceId: sourceId,
    paymentAccounts: accounts,
    invoices: invoices,
  );

  List<StatementImportRow> safeBulk(List<StatementImportRow> rows) =>
      includeOnlySafeStatementRows(
        rows: rows,
        sourceKind: StatementImportSourceKind.account,
        sourceId: 'cash-a',
        paymentAccounts: accounts,
        invoices: invoices,
      );

  test('bulk include never silently selects potential duplicates', () {
    final rows = safeBulk([
      row(id: 'new'),
      row(id: 'maybe', duplicate: StatementImportDuplicateState.possibleDuplicate),
      row(id: 'exact', duplicate: StatementImportDuplicateState.exactDuplicate),
      row(id: 'imported', status: StatementImportRowStatus.imported,
        decision: StatementImportDecision.include),
    ]);
    expect(rows.map((r) => r.decision), [
      StatementImportDecision.include,
      StatementImportDecision.review,
      StatementImportDecision.ignore,
      StatementImportDecision.include,
    ]);
    expect(rows.last.status, StatementImportRowStatus.imported);
  });

  test('explicit approval of a possible duplicate is not undone by bulk action', () {
    final rows = safeBulk([
      row(duplicate: StatementImportDuplicateState.possibleDuplicate,
        decision: StatementImportDecision.include),
    ]);
    expect(rows.single.selected, isTrue);
  });

  test('cannot silently bulk include transfers without valid counterpart', () {
    final noCounterpart = row(finalType: StatementImportFinalType.transfer);
    final selfCounterpart = row(
      finalType: StatementImportFinalType.transfer, counterpart: 'cash-a');
    final valid = row(
      finalType: StatementImportFinalType.transfer, counterpart: 'cash-b');
    expect(safeBulk([noCounterpart, selfCounterpart]).every(
      (candidate) => !candidate.selected,
    ), isTrue);
    expect(validate(selfCounterpart.copyWith(decision: StatementImportDecision.include)),
      contains('diferentes'));
    expect(validate(valid.copyWith(decision: StatementImportDecision.include)), isNull);
    expect(safeBulk([valid]).single.selected, isTrue);
  });

  test('card invoice payment must have matching card, bank and direction', () {
    final valid = row(
      finalType: StatementImportFinalType.cardPayment,
      direction: StatementImportDirection.credit,
      counterpart: 'cash-a',
      invoice: 'invoice-a',
      decision: StatementImportDecision.include,
    );
    expect(validate(valid, source: StatementImportSourceKind.card,
      sourceId: 'card-a'), isNull);
    expect(validate(valid, source: StatementImportSourceKind.card,
      sourceId: 'card-b'), contains('não corresponde'));
    expect(validate(valid.copyWith(clearCounterpart: true),
      source: StatementImportSourceKind.card, sourceId: 'card-a'),
      contains('conta bancária'));
    expect(validate(row(
      finalType: StatementImportFinalType.cardPayment,
      direction: StatementImportDirection.debit,
      decision: StatementImportDecision.include,
      invoice: 'invoice-a',
      counterpart: 'cash-a'),
      source: StatementImportSourceKind.card, sourceId: 'card-a'),
      contains('sentido'));
  });

  test('bank invoice payment is debit; mismatched source type is blocked', () {
    final payment = row(
      finalType: StatementImportFinalType.cardPayment,
      invoice: 'invoice-a',
      direction: StatementImportDirection.debit,
      decision: StatementImportDecision.include,
    );
    expect(validate(payment), isNull);
    expect(validate(payment.copyWith(clearInvoice: true)), contains('fatura'));
    expect(validate(payment, source: StatementImportSourceKind.benefit),
      contains('incompatível'));
  });

  test('credits and expenses cannot be silently flipped to wrong direction', () {
    final expense = row(direction: StatementImportDirection.credit,
      decision: StatementImportDecision.include);
    expect(validate(expense), contains('sentido'));
    final salary = row(finalType: StatementImportFinalType.income,
      direction: StatementImportDirection.credit,
      decision: StatementImportDecision.include);
    expect(validate(salary), isNull);
    expect(safeBulk([expense]).single.selected, isFalse);
  });
}
