import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_export.dart';
import 'folego_repository.dart';

const int profileExportPageSize = 500;

extension FolegoRepositoryProfileExport on FolegoRepository {
  Future<List<ProfileExportRow>> listProfileExportRows({
    required String spaceId,
  }) async {
    final client = Supabase.instance.client;
    final rows = <ProfileExportRow>[];
    var offset = 0;

    while (true) {
      final response = await client
          .from('financial_events')
          .select('''
            space_id,
            event_type,
            description,
            amount,
            occurred_at,
            status,
            source,
            category:categories(
              name
            ),
            financial_impacts(
              dimension,
              account:accounts(
                name
              )
            ),
            card_purchases(
              card:credit_cards(
                name
              )
            ),
            card_payments(
              invoice:card_invoices(
                card:credit_cards(
                  name
                )
              )
            )
          ''')
          .eq('space_id', spaceId)
          .order('occurred_at', ascending: false)
          .range(offset, offset + profileExportPageSize - 1);

      final page = List<Map<String, dynamic>>.from(response);
      rows.addAll(
        parseProfileExportRows(
          page,
          expectedSpaceId: spaceId,
        ),
      );

      if (page.length < profileExportPageSize) {
        break;
      }

      offset += profileExportPageSize;
    }

    return rows;
  }
}
