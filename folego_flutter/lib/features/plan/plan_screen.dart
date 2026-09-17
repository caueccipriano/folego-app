import 'package:flutter/material.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../core/theme/app_icons.dart';
import '../../data/repositories/folego_repository.dart';
import 'flexible_budget_screen.dart';
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
    return Stack(
      children: [
        RealtimeRefreshView(
          domain: AppRealtimeDomain.plan,
          identity: spaceId,
          builder: (refreshToken) => base.PlanScreen(
            repository: repository,
            spaceId: spaceId,
            refreshToken: refreshToken,
          ),
        ),
        Positioned(
          right: 18,
          bottom: 92,
          child: SafeArea(
            child: FloatingActionButton.extended(
              key: const ValueKey('plan-open-flex-budget'),
              heroTag: 'plan-flex-budget',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FlexibleBudgetScreen(
                    repository: repository,
                    spaceId: spaceId,
                  ),
                ),
              ),
              icon: const Icon(AppIcons.plan, size: 19),
              label: const Text('teto flexível'),
            ),
          ),
        ),
      ],
    );
  }
}
