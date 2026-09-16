import 'package:flutter/widgets.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../data/repositories/folego_repository.dart';
import 'goals_screen_base.dart' as base;

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  Widget build(BuildContext context) {
    return RealtimeRefreshView(
      domain: AppRealtimeDomain.goals,
      identity: spaceId,
      builder: (key) => base.GoalsScreen(
        key: key,
        repository: repository,
        spaceId: spaceId,
      ),
    );
  }
}
