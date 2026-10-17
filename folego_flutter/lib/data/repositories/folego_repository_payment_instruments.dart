import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_item.dart';
import '../models/credit_card_item.dart';
import 'folego_repository.dart';

const int cardPurchaseMinInstallments = 1;
const int cardPurchaseMaxInstallments = 120;

extension FolegoRepositoryPaymentInstruments on FolegoRepository {
  Future<List<AccountItem>> listPaymentAccounts(String spaceId) async {
    final response = await Supabase.instance.client
        .from('accounts')
        .select('id,name,type')
        .eq('space_id', spaceId)
        .eq('active', true)
        .neq('type', AccountItem.benefitType)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .map(AccountItem.fromJson)
        .where((account) => account.isPaymentAccount)
        .toList();
  }

  Future<List<AccountItem>> listBenefitAccounts(String spaceId) async {
    final response = await Supabase.instance.client
        .from('accounts')
        .select('id,name,type')
        .eq('space_id', spaceId)
        .eq('active', true)
        .eq('type', AccountItem.benefitType)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .map(AccountItem.fromJson)
        .where((account) => account.isBenefit)
        .toList();
  }

  Future<List<CreditCardItem>> listActiveCreditCards(String spaceId) async {
    final response = await Supabase.instance.client
        .from('credit_cards')
        .select('id,name,issuer,brand,last_four,active')
        .eq('space_id', spaceId)
        .eq('active', true)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .map(CreditCardItem.fromJson)
        .where((card) => card.active)
        .toList();
  }

  Future<String> registerCardPurchase({
    required String spaceId,
    required String cardId,
    required num totalAmount,
    required String description,
    int installmentsCount = cardPurchaseMinInstallments,
    String? categoryId,
    DateTime? purchaseAt,
    String? merchant,
  }) async {
    if (installmentsCount < cardPurchaseMinInstallments ||
        installmentsCount > cardPurchaseMaxInstallments) {
      throw ArgumentError.value(
        installmentsCount,
        'installmentsCount',
        'Deve estar entre $cardPurchaseMinInstallments e $cardPurchaseMaxInstallments.',
      );
    }

    final data = await Supabase.instance.client.rpc(
      'register_card_purchase',
      params: {
        'p_space_id': spaceId,
        'p_card_id': cardId,
        'p_total_amount': totalAmount,
        'p_description': description,
        'p_installments_count': installmentsCount,
        'p_category_id': categoryId,
        'p_purchase_at': (purchaseAt ?? DateTime.now()).toIso8601String(),
        'p_merchant': merchant?.trim().isEmpty == true ? null : merchant?.trim(),
        'p_source': 'app',
        'p_external_id': null,
      },
    );

    return data as String;
  }

  Future<String> registerBenefit({
    required String spaceId,
    required String accountId,
    required num amount,
    required String description,
    required bool isCredit,
    String? categoryId,
    DateTime? occurredAt,
  }) async {
    final data = await Supabase.instance.client.rpc(
      'register_benefit_at',
      params: {
        'p_space_id': spaceId,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_description': description,
        'p_is_credit': isCredit,
        'p_category_id': categoryId,
        'p_occurred_at': (occurredAt ?? DateTime.now()).toIso8601String(),
      },
    );

    return data as String;
  }
}
