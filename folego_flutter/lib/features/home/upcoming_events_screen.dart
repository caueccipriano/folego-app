import 'package:flutter/widgets.dart';

import '../../data/repositories/folego_repository.dart';
import 'upcoming_events_screen_web2.dart';

class UpcomingEventsScreen extends StatelessWidget {
  const UpcomingEventsScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.initialSourceId,
    this.initialDate,
  });

  final FolegoRepository repository;
  final String spaceId;
  final String? initialSourceId;
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) {
    return UpcomingEventsScreenWeb2(
      repository: repository,
      spaceId: spaceId,
      initialSourceId: initialSourceId,
      initialDate: initialDate,
    );
  }
}
