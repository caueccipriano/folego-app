import 'package:supabase_flutter/supabase_flutter.dart';

import 'folego_repository.dart';

extension FolegoRepositoryTransactionActions on FolegoRepository {
  Future<void> cancelSimpleTransaction({
    required String spaceId,
    required String eventId,
  }) async {
    await Supabase.instance.client.rpc(
      'cancel_simple_transaction',
      params: {'p_space_id': spaceId, 'p_event_id': eventId},
    );
  }

  Future<void> updateCardPurchase({
    required String spaceId,
    required String eventId,
    required num totalAmount,
    required String description,
    required String? categoryId,
    required String merchant,
    required String cardId,
    required DateTime purchaseAt,
  }) async {
    await Supabase.instance.client.rpc(
      'update_card_purchase',
      params: {
        'p_space_id': spaceId,
        'p_event_id': eventId,
        'p_total_amount': totalAmount,
        'p_description': description,
        'p_category_id': categoryId,
        'p_merchant': merchant,
        'p_card_id': cardId,
        'p_purchase_at': purchaseAt.toIso8601String(),
      },
    );
  }

  Future<void> cancelCardPurchase({required String spaceId, required String eventId}) async {
    await Supabase.instance.client.rpc(
      'cancel_card_purchase',
      params: {'p_space_id': spaceId, 'p_event_id': eventId},
    );
  }

  Future<void> updateBenefitExpense({
    required String spaceId,
    required String eventId,
    required String accountId,
    required num amount,
    required String description,
    required String? categoryId,
    required DateTime occurredAt,
  }) async {
    await Supabase.instance.client.rpc(
      'update_benefit_expense',
      params: {
        'p_space_id': spaceId,
        'p_event_id': eventId,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_description': description,
        'p_category_id': categoryId,
        'p_occurred_at': occurredAt.toIso8601String(),
      },
    );
  }

  Future<void> cancelBenefitExpense({required String spaceId, required String eventId}) async {
    await Supabase.instance.client.rpc(
      'cancel_benefit_expense',
      params: {'p_space_id': spaceId, 'p_event_id': eventId},
    );
  }

  Future<void> updateTransferTransaction({
    required String spaceId,
    required String eventId,
    required String sourceAccountId,
    required String destinationAccountId,
    required num amount,
    required String description,
    required DateTime occurredAt,
  }) async {
    await Supabase.instance.client.rpc(
      'update_transfer_transaction',
      params: {
        'p_space_id': spaceId,
        'p_event_id': eventId,
        'p_source_account_id': sourceAccountId,
        'p_destination_account_id': destinationAccountId,
        'p_amount': amount,
        'p_description': description,
        'p_occurred_at': occurredAt.toIso8601String(),
      },
    );
  }

  Future<void> cancelTransferTransaction({required String spaceId, required String eventId}) async {
    await Supabase.instance.client.rpc(
      'cancel_transfer_transaction',
      params: {'p_space_id': spaceId, 'p_event_id': eventId},
    );
  }

  Future<void> reverseCardPayment({required String spaceId, required String eventId}) async {
    await Supabase.instance.client.rpc(
      'reverse_card_payment',
      params: {'p_space_id': spaceId, 'p_event_id': eventId},
    );
  }
}
