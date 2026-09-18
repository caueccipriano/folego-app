import 'package:flutter/material.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../core/theme/app_icons.dart';
import '../../data/repositories/folego_repository.dart';
import 'flexible_budget_screen.dart';
import 'plan_screen_web2.dart' as base;
import 'projection_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.projectionRequestToken = 0,
  });

  final FolegoRepository repository;
  final String spaceId;

  /// Changes when another area (for example Home) asks to open Projection.
  final int projectionRequestToken;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool _projection = false;

  @override
  void didUpdateWidget(covariant PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      _projection = false;
    }
    if (oldWidget.projectionRequestToken != widget.projectionRequestToken) {
      _projection = true;
    }
  }

  void _showProjection() {
    if (_projection) return;
    setState(() => _projection = true);
  }

  void _showSummary() {
    if (!_projection) return;
    setState(() => _projection = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_projection) {
      return ProjectionScreen(
        repository: widget.repository,
        spaceId: widget.spaceId,
        onBack: _showSummary,
      );
    }

    return Stack(
      children: [
        RealtimeRefreshView(
          domain: AppRealtimeDomain.plan,
          identity: widget.spaceId,
          builder: (refreshToken) => base.PlanScreen(
            repository: widget.repository,
            spaceId: widget.spaceId,
            refreshToken: refreshToken,
            onProjectionRequested: _showProjection,
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
                    repository: widget.repository,
                    spaceId: widget.spaceId,
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
