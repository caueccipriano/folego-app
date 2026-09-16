import 'package:flutter/widgets.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../data/repositories/folego_repository.dart';
import 'plan_screen_web2.dart' as base;

class PlanScreen extends StatelessWidget {
  const PlanScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  Widget build(BuildContext context) {
    return RealtimeRefreshView(
      domain: AppRealtimeDomain.plan,
      identity: spaceId,
      builder: (refreshToken) => base.PlanScreen(
        repository: repository,
        spaceId: spaceId,
        refreshToken: refreshToken,
      ),
    );
  }
}
