import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_item.dart';
import 'folego_repository.dart';

/// Candidates are suggestions only. The RPC rechecks ownership, remaining
/// obligation, original cash impact and duplicate backing inside one transaction.
extension FolegoRepositoryPaymentRecognition on FolegoRepository {
  Future<List<TransactionItem>> paymentCandidates(
    String spaceId,
    double outstanding,
  ) async {
    final rows = await getTransactions(spaceId);
    final candidates = rows
        .where(
          (item) =>
              item.status == 'confirmed' &&
              item.eventType == 'expense' &&
              item.accountId != null &&
              item.amount > 0 &&
              item.amount <= outstanding + .001,
        )
        .toList();
    candidates.sort((a, b) {
      final aExact = (a.amount - outstanding).abs() < .005;
      final bExact = (b.amount - outstanding).abs() < .005;
      if (aExact != bExact) return aExact ? -1 : 1;
      return b.occurredAt.compareTo(a.occurredAt);
    });
    return candidates;
  }

  Future<void> recognizePayment({
    required String spaceId,
    required String eventId,
    required String targetKind,
    required String targetId,
  }) async {
    await Supabase.instance.client.rpc(
      'recognize_existing_payment',
      params: {
        'p_space_id': spaceId,
        'p_event_id': eventId,
        'p_target_kind': targetKind,
        'p_target_id': targetId,
      },
    );
  }

  Future<void> unlinkRecognizedPayment({
    required String spaceId,
    required String eventId,
  }) async {
    await Supabase.instance.client.rpc(
      'unlink_recognized_payment',
      params: {'p_space_id': spaceId, 'p_event_id': eventId},
    );
  }
}
