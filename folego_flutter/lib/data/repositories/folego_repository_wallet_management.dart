import 'package:supabase_flutter/supabase_flutter.dart';

import 'folego_repository.dart';

/// CRUD administrativo da Carteira 3.0.
///
/// Saldo nunca é escrito diretamente: criação usa opening_balance no ledger e
/// edição altera somente metadados do instrumento. Arquivamento é validado no
/// backend e preserva todo o histórico.
extension FolegoRepositoryWalletManagement on FolegoRepository {
  Future<String> createWalletAccount({
    required String spaceId,
    required String name,
    required String type,
    num openingBalance = 0,
    DateTime? balanceDate,
    String? institution,
    bool? availableForSpending,
  }) async {
    final data = await Supabase.instance.client.rpc(
      'create_wallet_account',
      params: {
        'p_space_id': spaceId,
        'p_name': name.trim(),
        'p_opening_balance': openingBalance,
        'p_balance_date': _date(balanceDate ?? DateTime.now()),
        'p_institution': _nullable(institution),
        'p_type': type,
        'p_available_for_spending': availableForSpending,
      },
    );
    return data as String;
  }

  Future<void> updateWalletAccount({
    required String spaceId,
    required String accountId,
    required String name,
    required String type,
    String? institution,
    required bool availableForSpending,
  }) async {
    await Supabase.instance.client.rpc(
      'update_wallet_account',
      params: {
        'p_space_id': spaceId,
        'p_account_id': accountId,
        'p_name': name.trim(),
        'p_institution': _nullable(institution),
        'p_type': type,
        'p_available_for_spending': availableForSpending,
      },
    );
  }

  Future<void> archiveWalletAccount({
    required String spaceId,
    required String accountId,
  }) async {
    await Supabase.instance.client.rpc(
      'archive_wallet_account',
      params: {'p_space_id': spaceId, 'p_account_id': accountId},
    );
  }

  Future<String> createWalletCard({
    required String spaceId,
    required String name,
    required int closingDay,
    required int dueDay,
    required String paymentAccountId,
    String? issuer,
    String? brand,
    String? lastFour,
    num? personalLimit,
    num? issuerLimit,
  }) async {
    final data = await Supabase.instance.client.rpc(
      'create_wallet_card',
      params: {
        'p_space_id': spaceId,
        'p_name': name.trim(),
        'p_closing_day': closingDay,
        'p_due_day': dueDay,
        'p_payment_account_id': paymentAccountId,
        'p_issuer': _nullable(issuer),
        'p_brand': _nullable(brand),
        'p_last_four': _nullable(lastFour),
        'p_personal_limit': personalLimit,
        'p_issuer_limit': issuerLimit,
      },
    );
    return data as String;
  }

  Future<void> updateWalletCard({
    required String spaceId,
    required String cardId,
    required String name,
    required int closingDay,
    required int dueDay,
    required String paymentAccountId,
    String? issuer,
    String? brand,
    String? lastFour,
    num? personalLimit,
  }) async {
    await Supabase.instance.client.rpc(
      'update_wallet_card',
      params: {
        'p_space_id': spaceId,
        'p_card_id': cardId,
        'p_name': name.trim(),
        'p_closing_day': closingDay,
        'p_due_day': dueDay,
        'p_payment_account_id': paymentAccountId,
        'p_issuer': _nullable(issuer),
        'p_brand': _nullable(brand),
        'p_last_four': _nullable(lastFour),
        'p_personal_limit': personalLimit,
      },
    );
  }

  Future<void> archiveWalletCard({
    required String spaceId,
    required String cardId,
  }) async {
    await Supabase.instance.client.rpc(
      'archive_wallet_card',
      params: {'p_space_id': spaceId, 'p_card_id': cardId},
    );
  }
}

String _date(DateTime date) {
  final local = date.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String? _nullable(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
