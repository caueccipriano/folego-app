import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_detail.dart';
import 'folego_repository.dart';

extension FolegoRepositoryTransactionDetail on FolegoRepository {
  Future<TransactionDetail> getTransactionDetail({
    required String spaceId,
    required String eventId,
  }) async {
    final client = Supabase.instance.client;
    final eventRows = List<Map<String, dynamic>>.from(
      await client
          .from('financial_events')
          .select('''
            id,space_id,event_type,description,amount,occurred_at,
            competence_date,category_id,status,source,metadata,
            category:categories(id,name,parent_id),
            financial_impacts(
              dimension,amount,account_id,
              account:accounts(id,name,type)
            )
          ''')
          .eq('space_id', spaceId)
          .eq('id', eventId)
          .limit(1),
    );
    if (eventRows.isEmpty) throw StateError('Lançamento não encontrado.');

    final event = eventRows.first;
    final metadata = _detailMap(event['metadata']) ?? const <String, dynamic>{};
    final category = _detailMap(event['category']);
    String? parentName;
    final parentId = category?['parent_id'] as String?;
    if (parentId != null) {
      final rows = List<Map<String, dynamic>>.from(
        await client.from('categories').select('name').eq('space_id', spaceId).eq('id', parentId).limit(1),
      );
      if (rows.isNotEmpty) parentName = rows.first['name'] as String?;
    }

    final impacts = _detailMaps(event['financial_impacts']).map((impact) {
      final account = _detailMap(impact['account']);
      return TransactionDetailAccountImpact(
        dimension: impact['dimension'] as String,
        amount: _detailNumber(impact['amount']),
        accountId: impact['account_id'] as String?,
        accountName: account?['name'] as String?,
        accountType: account?['type'] as String?,
      );
    }).toList(growable: false);

    final eventType = event['event_type'] as String;
    final legacy = metadata['legacy_exception'] == true;
    final legacyKind = metadata['legacy_exception_kind'] as String?;
    final legacyCopy = _legacyCopy(legacyKind);

    String? purchaseId;
    String? cardId;
    String? cardName;
    String? merchant;
    DateTime? purchaseAt;
    int? installmentsCount;
    String? purchaseStatus;
    List<TransactionDetailInstallment> installments = const [];
    var purchaseFinancialEditable = false;
    var purchaseReversible = false;
    String? purchaseRestriction;

    if (eventType == 'card_purchase') {
      final rows = List<Map<String, dynamic>>.from(
        await client
            .from('card_purchases')
            .select('''
              id,card_id,merchant,purchase_at,installments_count,status,
              card:credit_cards(id,name),
              card_installments(
                id,invoice_id,installment_number,total_installments,amount,
                competence_date,status,
                invoice:card_invoices(id,reference_month,closing_date,due_date,status)
              )
            ''')
            .eq('space_id', spaceId)
            .eq('event_id', eventId)
            .limit(1),
      );
      if (rows.isNotEmpty) {
        final purchase = rows.first;
        purchaseId = purchase['id'] as String?;
        cardId = purchase['card_id'] as String?;
        final card = _detailMap(purchase['card']);
        cardName = card?['name'] as String?;
        merchant = purchase['merchant'] as String?;
        purchaseAt = _detailDate(purchase['purchase_at']);
        installmentsCount = (purchase['installments_count'] as num?)?.toInt();
        purchaseStatus = purchase['status'] as String?;
        final rawInstallments = _detailMaps(purchase['card_installments'])
          ..sort((a, b) => (a['installment_number'] as num).toInt().compareTo((b['installment_number'] as num).toInt()));
        installments = rawInstallments.map((item) {
          final invoice = _detailMap(item['invoice']);
          return TransactionDetailInstallment(
            id: item['id'] as String,
            number: (item['installment_number'] as num).toInt(),
            total: (item['total_installments'] as num).toInt(),
            amount: _detailNumber(item['amount']),
            competenceDate: _detailDate(item['competence_date'])!,
            status: item['status'] as String,
            invoiceId: item['invoice_id'] as String?,
            invoiceReferenceMonth: _detailDate(invoice?['reference_month']),
            invoiceClosingDate: _detailDate(invoice?['closing_date']),
            invoiceDueDate: _detailDate(invoice?['due_date']),
            invoiceStatus: invoice?['status'] as String?,
          );
        }).toList(growable: false);

        var hasPayment = false;
        for (final invoiceId in installments.map((e) => e.invoiceId).whereType<String>().toSet()) {
          final payments = List<Map<String, dynamic>>.from(
            await client
                .from('card_payments')
                .select('id')
                .eq('space_id', spaceId)
                .eq('invoice_id', invoiceId)
                .neq('status', 'cancelled')
                .limit(1),
          );
          if (payments.isNotEmpty) {
            hasPayment = true;
            break;
          }
        }
        final allInvoicesOpen = installments.isNotEmpty && installments.every((e) => e.invoiceStatus == 'open');
        final installmentsMutable = installments.every((e) => e.status != 'paid' && e.status != 'refunded' && e.status != 'cancelled');
        purchaseFinancialEditable = !legacy && purchaseStatus == 'confirmed' && allInvoicesOpen && installmentsMutable && !hasPayment;
        purchaseReversible = purchaseFinancialEditable;
        if (!purchaseFinancialEditable) {
          purchaseRestriction = hasPayment
              ? 'valor e categoria ficam protegidos porque uma fatura relacionada já recebeu pagamento.'
              : !allInvoicesOpen
                  ? 'valor e categoria ficam protegidos porque há fatura fechada ou paga.'
                  : 'esta compra possui histórico de parcelas que não pode ser reescrito.';
        }
      }
    }

    String? paymentId;
    String? paymentInvoiceId;
    String? paymentAccountId;
    String? paymentAccountName;
    String? paymentType;
    String? paymentStatus;
    DateTime? paymentPaidAt;
    String? paymentInvoiceStatus;
    DateTime? paymentInvoiceDueDate;
    var paymentReversible = false;
    String? paymentRestriction;

    if (eventType == 'card_payment' && !legacy) {
      final rows = List<Map<String, dynamic>>.from(
        await client
            .from('card_payments')
            .select('''
              id,invoice_id,account_id,amount,paid_at,payment_type,status,
              account:accounts(id,name),
              invoice:card_invoices(
                id,card_id,reference_month,due_date,status,
                card:credit_cards(id,name)
              )
            ''')
            .eq('space_id', spaceId)
            .eq('event_id', eventId)
            .limit(1),
      );
      if (rows.isNotEmpty) {
        final payment = rows.first;
        final account = _detailMap(payment['account']);
        final invoice = _detailMap(payment['invoice']);
        final card = _detailMap(invoice?['card']);
        paymentId = payment['id'] as String?;
        paymentInvoiceId = payment['invoice_id'] as String?;
        paymentAccountId = payment['account_id'] as String?;
        paymentAccountName = account?['name'] as String?;
        paymentType = payment['payment_type'] as String?;
        paymentStatus = payment['status'] as String?;
        paymentPaidAt = _detailDate(payment['paid_at']);
        paymentInvoiceStatus = invoice?['status'] as String?;
        paymentInvoiceDueDate = _detailDate(invoice?['due_date']);
        cardId = invoice?['card_id'] as String?;
        cardName = card?['name'] as String?;

        var hasLaterCarryover = false;
        final reference = invoice?['reference_month']?.toString();
        if (cardId != null && reference != null) {
          final laterRows = List<Map<String, dynamic>>.from(
            await client
                .from('card_invoices')
                .select('id,opening_balance')
                .eq('space_id', spaceId)
                .eq('card_id', cardId!)
                .gt('reference_month', reference)
                .neq('opening_balance', 0)
                .limit(1),
          );
          hasLaterCarryover = laterRows.isNotEmpty;
        }
        paymentReversible = paymentStatus == 'confirmed' && !hasLaterCarryover;
        if (!paymentReversible) {
          paymentRestriction = hasLaterCarryover
              ? 'este pagamento afetou saldo carregado para uma fatura posterior e não pode ser revertido automaticamente.'
              : 'este pagamento já não está confirmado.';
        }
      }
    }

    String? recurringItemId;
    String? recurringItemName;
    String? occurrenceId;
    DateTime? recurringDueDate;
    final occurrenceRows = List<Map<String, dynamic>>.from(
      await client
          .from('recurring_occurrences')
          .select('id,due_date,recurring_item_id,recurring_item:recurring_items(id,name)')
          .eq('space_id', spaceId)
          .eq('event_id', eventId)
          .limit(1),
    );
    if (occurrenceRows.isNotEmpty) {
      final occurrence = occurrenceRows.first;
      final recurring = _detailMap(occurrence['recurring_item']);
      occurrenceId = occurrence['id'] as String?;
      recurringDueDate = _detailDate(occurrence['due_date']);
      recurringItemId = occurrence['recurring_item_id'] as String?;
      recurringItemName = recurring?['name'] as String?;
    }

    String? reflectionType;
    String? reflectionNote;
    final reflectionRows = List<Map<String, dynamic>>.from(
      await client
          .from('transaction_reflections')
          .select('reflection_type,note')
          .eq('space_id', spaceId)
          .eq('event_id', eventId)
          .limit(1),
    );
    if (reflectionRows.isNotEmpty) {
      reflectionType = reflectionRows.first['reflection_type'] as String?;
      reflectionNote = reflectionRows.first['note'] as String?;
    }

    String? debtName;
    String? debtCreditor;
    if (eventType == 'debt_payment') {
      final debtRows = List<Map<String, dynamic>>.from(
        await client
            .from('debt_installments')
            .select('debt:debts(name,creditor)')
            .eq('space_id', spaceId)
            .eq('payment_event_id', eventId)
            .limit(1),
      );
      if (debtRows.isNotEmpty) {
        final debt = _detailMap(debtRows.first['debt']);
        debtName = debt?['name'] as String?;
        debtCreditor = debt?['creditor'] as String?;
      }
    }

    return TransactionDetail(
      id: event['id'] as String,
      spaceId: event['space_id'] as String,
      eventType: eventType,
      description: event['description'] as String,
      amount: _detailNumber(event['amount']),
      occurredAt: _detailDate(event['occurred_at'])!,
      competenceDate: _detailDate(event['competence_date']),
      status: event['status'] as String,
      source: event['source'] as String,
      categoryId: event['category_id'] as String?,
      categoryName: category?['name'] as String?,
      categoryParentName: parentName,
      impacts: impacts,
      legacyException: legacy,
      legacyKind: legacyKind,
      legacyTitle: legacyCopy.$1,
      legacyMessage: legacyCopy.$2,
      cardPurchaseId: purchaseId,
      cardId: cardId,
      cardName: cardName,
      cardMerchant: merchant,
      cardPurchaseAt: purchaseAt,
      cardInstallmentsCount: installmentsCount,
      cardPurchaseStatus: purchaseStatus,
      installments: installments,
      cardPurchaseFinancialEditable: purchaseFinancialEditable,
      cardPurchaseReversible: purchaseReversible,
      cardPurchaseRestriction: purchaseRestriction,
      cardPaymentId: paymentId,
      cardPaymentInvoiceId: paymentInvoiceId,
      cardPaymentAccountId: paymentAccountId,
      cardPaymentAccountName: paymentAccountName,
      cardPaymentType: paymentType,
      cardPaymentStatus: paymentStatus,
      cardPaymentPaidAt: paymentPaidAt,
      cardPaymentInvoiceStatus: paymentInvoiceStatus,
      cardPaymentInvoiceDueDate: paymentInvoiceDueDate,
      cardPaymentReversible: paymentReversible,
      cardPaymentRestriction: paymentRestriction,
      recurringItemId: recurringItemId,
      recurringItemName: recurringItemName,
      recurringOccurrenceId: occurrenceId,
      recurringDueDate: recurringDueDate,
      reflectionType: reflectionType,
      reflectionNote: reflectionNote,
      debtName: debtName,
      debtCreditor: debtCreditor,
    );
  }
}

(String?, String?) _legacyCopy(String? kind) {
  switch (kind) {
    case 'one_sided_transfer':
      return ('transferência histórica', 'conta de origem não disponível no histórico');
    case 'card_payment_missing_invoice':
      return ('pagamento histórico', 'fatura original não disponível');
    case 'financing_inflow_missing_liability_details':
      return ('entrada de financiamento', 'detalhes da obrigação não disponíveis no histórico');
    default:
      return (null, null);
  }
}

List<Map<String, dynamic>> _detailMaps(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

Map<String, dynamic>? _detailMap(dynamic value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

double _detailNumber(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _detailDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
