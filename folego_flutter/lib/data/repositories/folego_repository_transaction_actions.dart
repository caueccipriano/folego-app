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
}
