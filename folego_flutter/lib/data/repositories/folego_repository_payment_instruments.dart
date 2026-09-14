import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_item.dart';
import '../models/credit_card_item.dart';
import 'folego_repository.dart';

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
}
