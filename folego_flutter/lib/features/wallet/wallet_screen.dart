import 'package:flutter/widgets.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../data/repositories/folego_repository.dart';
import 'wallet_screen_base.dart' as base;

class WalletScreen extends StatelessWidget {
  const WalletScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  Widget build(BuildContext context) {
    return RealtimeRefreshView(
      domain: AppRealtimeDomain.wallet,
      identity: spaceId,
      builder: (key) => base.WalletScreen(
        key: key,
        repository: repository,
        spaceId: spaceId,
      ),
    );
  }
}
