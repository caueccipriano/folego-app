import '../../data/models/account_item.dart';
import '../../data/models/statement_import.dart';

/// Client-side review safeguards. The server remains the source of truth for
/// financial operations, authorization, duplicate detection and idempotence.
String? validateStatementImportReconciliation({
  required StatementImportRow row,
  required StatementImportSourceKind sourceKind,
  required String? sourceId,
  required List<AccountItem> paymentAccounts,
  required List<StatementImportInvoiceOption> invoices,
}) {
  if (!row.selected) return null;
  final kind = row.finalType;
  if (kind == null) return 'escolha o tipo financeiro';

  final allowed = switch (sourceKind) {
    StatementImportSourceKind.account => const [
      StatementImportFinalType.expense,
      StatementImportFinalType.income,
      StatementImportFinalType.transfer,
      StatementImportFinalType.cardPayment,
    ],
    StatementImportSourceKind.card => const [
      StatementImportFinalType.cardPurchase,
      StatementImportFinalType.cardPayment,
    ],
    StatementImportSourceKind.benefit => const [
      StatementImportFinalType.benefitExpense,
      StatementImportFinalType.benefitCredit,
    ],
  };
  if (!allowed.contains(kind)) {
    return 'tipo financeiro incompatível com a origem do extrato';
  }

  final requiredDirection = switch (kind) {
    StatementImportFinalType.expense ||
    StatementImportFinalType.cardPurchase ||
    StatementImportFinalType.benefitExpense => StatementImportDirection.debit,
    StatementImportFinalType.income ||
    StatementImportFinalType.benefitCredit => StatementImportDirection.credit,
    StatementImportFinalType.cardPayment =>
      sourceKind == StatementImportSourceKind.card
        ? StatementImportDirection.credit
        : StatementImportDirection.debit,
    StatementImportFinalType.transfer => null,
  };
  if (requiredDirection != null && row.direction != requiredDirection) {
    return 'confira o sentido do valor: débito e crédito não correspondem ao tipo escolhido';
  }

  if (kind == StatementImportFinalType.transfer) {
    final counterpart = row.counterpartAccountId;
    if (counterpart == null || counterpart.isEmpty) {
      return 'transferência exige a outra conta';
    }
    if (counterpart == sourceId) {
      return 'transferência precisa envolver duas contas diferentes';
    }
    if (!paymentAccounts.any(
      (account) => account.id == counterpart && account.isPaymentAccount,
    )) {
      return 'selecione outra conta bancária válida';
    }
  }

  if (kind == StatementImportFinalType.cardPayment) {
    final invoiceId = row.invoiceId;
    if (invoiceId == null || invoiceId.isEmpty) {
      return 'pagamento de cartão exige uma fatura';
    }
    final invoiceValid = invoices.any(
      (invoice) =>
          invoice.id == invoiceId &&
          (sourceKind != StatementImportSourceKind.card ||
              invoice.cardId == sourceId),
    );
    if (!invoiceValid) {
      return 'a fatura escolhida não corresponde ao cartão deste extrato';
    }
    if (sourceKind == StatementImportSourceKind.card) {
      final accountId = row.counterpartAccountId;
      if (accountId == null ||
          !paymentAccounts.any(
            (account) =>
                account.id == accountId && account.isPaymentAccount,
          )) {
        return 'selecione uma conta bancária válida para pagar a fatura';
      }
    }
  }

  return null;
}

/// Human approval required for decisions whose cash side effects can be
/// recorded twice by a second statement (or already exist in the ledger).
/// This does not prove two records are duplicates; it makes the risk explicit.
class StatementImportRiskSummary {
  const StatementImportRiskSummary({
    required this.transfers,
    required this.cardPayments,
    required this.possibleRefunds,
    required this.duplicateOverrides,
  });

  final int transfers;
  final int cardPayments;
  final int possibleRefunds;
  final int duplicateOverrides;

  bool get requiresConfirmation =>
      transfers > 0 ||
      cardPayments > 0 ||
      possibleRefunds > 0 ||
      duplicateOverrides > 0;
}

/// Only selected rows matter: ignored entries cannot create financial impacts.
/// Distinct risks may overlap, e.g. one possible refund is also a duplicate.
StatementImportRiskSummary summarizeSensitiveStatementImport(
  List<StatementImportRow> rows,
) {
  final included = rows.where(
    (row) => row.selected && row.status != StatementImportRowStatus.imported,
  );
  var transfers = 0;
  var cardPayments = 0;
  var possibleRefunds = 0;
  var duplicateOverrides = 0;
  for (final row in included) {
    if (row.finalType == StatementImportFinalType.transfer) transfers++;
    if (row.finalType == StatementImportFinalType.cardPayment) cardPayments++;
    if (row.candidateType == StatementImportCandidateType.refundCandidate) {
      possibleRefunds++;
    }
    if (row.duplicateState != StatementImportDuplicateState.unique) {
      duplicateOverrides++;
    }
  }
  return StatementImportRiskSummary(
    transfers: transfers,
    cardPayments: cardPayments,
    possibleRefunds: possibleRefunds,
    duplicateOverrides: duplicateOverrides,
  );
}

/// Bulk actions never turn an unreviewed possible duplicate into a new
/// expense, income or transfer. Explicit single-row approvals are preserved.
List<StatementImportRow> includeOnlySafeStatementRows({
  required List<StatementImportRow> rows,
  required StatementImportSourceKind sourceKind,
  required String? sourceId,
  required List<AccountItem> paymentAccounts,
  required List<StatementImportInvoiceOption> invoices,
}) => rows.map((row) {
  if (row.status != StatementImportRowStatus.staged) return row;
  if (row.duplicateState == StatementImportDuplicateState.exactDuplicate ||
      row.duplicateState == StatementImportDuplicateState.alreadyImported) {
    return row.copyWith(decision: StatementImportDecision.ignore);
  }
  if (row.duplicateState != StatementImportDuplicateState.unique) {
    return row; // Potential duplicate: requires a deliberate row-level choice.
  }
  final included = row.copyWith(decision: StatementImportDecision.include);
  if (validateStatementImportReconciliation(
        row: included,
        sourceKind: sourceKind,
        sourceId: sourceId,
        paymentAccounts: paymentAccounts,
        invoices: invoices,
      ) != null) {
    return row;
  }
  return included;
}).toList(growable: false);
