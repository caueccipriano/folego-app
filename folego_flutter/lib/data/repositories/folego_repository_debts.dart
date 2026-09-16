import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/debt_detail.dart';
import 'folego_repository.dart';

extension FolegoRepositoryDebts on FolegoRepository {
  Future<String> createDebtV2({
    required String spaceId,
    required DebtDraft draft,
  }) async {
    final error = draft.validate();
    if (error != null) throw ArgumentError(error);
    final data = await Supabase.instance.client.rpc(
      'create_debt_v2',
      params: _debtParams(spaceId: spaceId, draft: draft),
    );
    return data as String;
  }

  Future<void> updateDebtV2({
    required String spaceId,
    required String debtId,
    required DebtDraft draft,
  }) async {
    final error = draft.validate();
    if (error != null) throw ArgumentError(error);
    await Supabase.instance.client.rpc(
      'update_debt_v2',
      params: {
        ..._debtParams(spaceId: spaceId, draft: draft),
        'p_debt_id': debtId,
      },
    );
  }

  Future<DebtDetail> getDebtDetail({
    required String spaceId,
    required String debtId,
  }) async {
    final data = await Supabase.instance.client.rpc(
      'get_debt_detail',
      params: {'p_space_id': spaceId, 'p_debt_id': debtId},
    );
    return DebtDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> archiveDebt({
    required String spaceId,
    required String debtId,
  }) async {
    await Supabase.instance.client.rpc(
      'archive_debt',
      params: {'p_space_id': spaceId, 'p_debt_id': debtId},
    );
  }

  Future<void> reopenDebt({
    required String spaceId,
    required String debtId,
  }) async {
    await Supabase.instance.client.rpc(
      'reopen_debt',
      params: {'p_space_id': spaceId, 'p_debt_id': debtId},
    );
  }

  Future<void> closeDebt({
    required String spaceId,
    required String debtId,
  }) async {
    await Supabase.instance.client.rpc(
      'close_debt',
      params: {'p_space_id': spaceId, 'p_debt_id': debtId},
    );
  }

  Future<String> payDebtInstallmentV2({
    required String spaceId,
    required String installmentId,
    required String accountId,
    required num amount,
    required DateTime paidAt,
  }) async {
    if (amount <= 0) throw ArgumentError('O valor deve ser maior que zero.');
    final data = await Supabase.instance.client.rpc(
      'pay_debt_installment_v2',
      params: {
        'p_space_id': spaceId,
        'p_installment_id': installmentId,
        'p_account_id': accountId,
        'p_amount': amount,
        'p_paid_at': paidAt.toIso8601String(),
      },
    );
    return data as String;
  }
}

Map<String, dynamic> _debtParams({
  required String spaceId,
  required DebtDraft draft,
}) {
  return {
    'p_space_id': spaceId,
    'p_name': draft.name.trim(),
    'p_creditor': draft.creditor.trim(),
    'p_original_amount': draft.originalAmount,
    'p_total_installments': draft.totalInstallments,
    'p_first_due': _debtDate(draft.firstDueDate),
    'p_payment_account_id': draft.paymentAccountId,
    'p_started_on': _debtDate(draft.startedOn),
    'p_interest_rate_monthly': draft.interestRateMonthly,
    'p_debt_type': draft.debtType,
    'p_notes': draft.notes?.trim().isEmpty == true ? null : draft.notes?.trim(),
  };
}

String? _debtDate(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
