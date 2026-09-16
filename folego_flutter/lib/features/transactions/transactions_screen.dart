import 'package:flutter/widgets.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../data/repositories/folego_repository.dart';
import 'transactions_screen_base.dart' as base;

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key, required this.repository});

  final FolegoRepository repository;

  @override
  Widget build(BuildContext context) {
    return RealtimeRefreshView(
      domain: AppRealtimeDomain.transactions,
      identity: 'transactions',
      builder: (key) => base.TransactionsScreen(
        key: key,
        repository: repository,
      ),
    );
  }
}
