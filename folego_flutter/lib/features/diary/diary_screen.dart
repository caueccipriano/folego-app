import 'package:flutter/widgets.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../data/repositories/folego_repository.dart';
import 'diary_screen_base.dart' as base;

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.active = true,
  });

  final FolegoRepository repository;
  final String spaceId;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return RealtimeRefreshView(
      domain: AppRealtimeDomain.diary,
      identity: spaceId,
      active: active,
      builder: (key) => base.DiaryScreen(
        key: key,
        repository: repository,
        spaceId: spaceId,
        active: active,
      ),
    );
  }
}
