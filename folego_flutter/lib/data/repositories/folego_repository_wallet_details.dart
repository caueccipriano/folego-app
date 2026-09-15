import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet_detail.dart';
import 'folego_repository.dart';

extension FolegoRepositoryWalletDetails on FolegoRepository {
  Future<List<WalletMovement>> listWalletMovements({
    required String spaceId,
    required String accountId,
    required String dimension,
    int limit = 6,
  }) async {
    if (dimension != 'cash' && dimension != 'benefit') {
      throw ArgumentError.value(
        dimension,
        'dimension',
        'A dimensão da carteira deve ser cash ou benefit.',
      );
    }

    final response = await Supabase.instance.client
        .from('financial_events')
        .select('''
          id,
          event_type,
          description,
          amount,
          occurred_at,
          status,
          category:categories(
            id,
            name
          ),
          financial_impacts!inner(
            id,
            dimension,
            amount,
            account_id,
            effective_date
          )
        ''')
        .eq('space_id', spaceId)
        .eq('financial_impacts.account_id', accountId)
        .eq('financial_impacts.dimension', dimension)
        .neq('status', 'ignored')
        .neq('status', 'cancelled')
        .order('occurred_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response)
        .map(WalletMovement.fromEventJson)
        .toList(growable: false);
  }

  Future<List<WalletCardPurchaseLine>> listCardInvoicePurchases({
    required String spaceId,
    required String cardId,
    required String invoiceId,
    int limit = 40,
  }) async {
    final response = await Supabase.instance.client
        .from('card_installments')
        .select('''
          id,
          invoice_id,
          installment_number,
          total_installments,
          amount,
          competence_date,
          status,
          purchase:card_purchases!inner(
            id,
            card_id,
            description,
            merchant,
            purchase_at,
            total_amount,
            installments_count,
            category:categories(
              id,
              name
            )
          )
        ''')
        .eq('space_id', spaceId)
        .eq('invoice_id', invoiceId)
        .eq('purchase.card_id', cardId)
        .neq('status', 'cancelled')
        .neq('status', 'refunded')
        .order('competence_date', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response)
        .map(WalletCardPurchaseLine.fromInstallmentJson)
        .toList(growable: false);
  }

  Future<List<WalletCardInstallmentLine>> listCardUpcomingInstallments({
    required String spaceId,
    required String cardId,
    String? currentInvoiceId,
    int limit = 40,
  }) async {
    var query = Supabase.instance.client
        .from('card_installments')
        .select('''
          id,
          invoice_id,
          installment_number,
          total_installments,
          amount,
          competence_date,
          status,
          invoice:card_invoices(
            id,
            due_date,
            status
          ),
          purchase:card_purchases!inner(
            id,
            card_id,
            description,
            merchant,
            purchase_at,
            total_amount,
            installments_count,
            category:categories(
              id,
              name
            )
          )
        ''')
        .eq('space_id', spaceId)
        .eq('purchase.card_id', cardId)
        .neq('status', 'cancelled')
        .neq('status', 'refunded')
        .neq('status', 'paid');

    if (currentInvoiceId != null) {
      query = query.neq('invoice_id', currentInvoiceId);
    }

    final response = await query
        .order('competence_date', ascending: true)
        .limit(limit);

    final lines = List<Map<String, dynamic>>.from(response)
        .map(WalletCardInstallmentLine.fromJson)
        .where((item) => item.isOutstanding)
        .toList(growable: false);

    final firstByPurchase = <String, WalletCardInstallmentLine>{};
    for (final line in lines) {
      firstByPurchase.putIfAbsent(line.purchaseId, () => line);
    }

    final result = firstByPurchase.values.toList(growable: false)
      ..sort((a, b) {
        final aDate = a.invoiceDueDate ?? a.competenceDate;
        final bDate = b.invoiceDueDate ?? b.competenceDate;
        return aDate.compareTo(bDate);
      });
    return result;
  }

  Future<List<WalletDebtInstallment>> listDebtInstallments({
    required String spaceId,
    required String debtId,
  }) async {
    final response = await Supabase.instance.client
        .from('debt_installments')
        .select('''
          id,
          installment_number,
          due_date,
          planned_amount,
          paid_amount,
          status
        ''')
        .eq('space_id', spaceId)
        .eq('debt_id', debtId)
        .neq('status', 'cancelled')
        .order('due_date', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .map(WalletDebtInstallment.fromJson)
        .toList(growable: false);
  }

  Future<List<WalletInstallmentPosition>> listWalletInstallmentPositions({
    required String spaceId,
    int limit = 60,
  }) async {
    final response = await Supabase.instance.client
        .from('card_purchases')
        .select('''
          id,
          description,
          merchant,
          purchase_at,
          total_amount,
          installments_count,
          status,
          category:categories(
            id,
            name
          ),
          card:credit_cards!inner(
            id,
            name
          ),
          card_installments(
            id,
            installment_number,
            total_installments,
            amount,
            competence_date,
            status,
            invoice:card_invoices(
              id,
              due_date,
              status
            )
          )
        ''')
        .eq('space_id', spaceId)
        .gt('installments_count', 1)
        .neq('status', 'cancelled')
        .neq('status', 'refunded')
        .order('purchase_at', ascending: false)
        .limit(limit);

    final positions = List<Map<String, dynamic>>.from(response)
        .map(WalletInstallmentPosition.fromPurchaseJson)
        .toList(growable: false);

    return sortWalletInstallmentPositions(positions);
  }
}
