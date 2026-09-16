import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../data/repositories/folego_repository.dart';
import 'upcoming_events_screen_base.dart' as base;

/// Responsive shell for the financial agenda.
///
/// The canonical agenda implementation remains in [base.UpcomingEventsScreen];
/// desktop only tightens control density and keeps the timeline at its existing
/// comfortable list width instead of stretching mobile cards across the page.
class UpcomingEventsScreenWeb2 extends StatelessWidget {
  const UpcomingEventsScreenWeb2({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  Widget build(BuildContext context) {
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;
    final child = base.UpcomingEventsScreen(
      repository: repository,
      spaceId: spaceId,
    );

    if (!desktop) return child;

    return Theme(
      data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
      child: KeyedSubtree(
        key: const ValueKey('agenda-desktop-layout'),
        child: child,
      ),
    );
  }
}
