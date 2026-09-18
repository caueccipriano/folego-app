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
    this.projectionOpenToken,
  });

  final FolegoRepository repository;
  final String spaceId;

  /// Changes when another area (for example Home) asks to open
  /// Planejamento > Projeção directly.
  final Object? projectionOpenToken;

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
    if (oldWidget.projectionOpenToken != widget.projectionOpenToken &&
        widget.projectionOpenToken != null) {
      _projection = true;
    }
  }

  void _openProjection() {
    if (_projection) return;
    setState(() => _projection = true);
  }

  void _openSummary() {
    if (!_projection) return;
    setState(() => _projection = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_projection) {
      return ProjectionScreen(
        repository: widget.repository,
        spaceId: widget.spaceId,
        onBack: _openSummary,
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
            onProjectionRequested: _openProjection,
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
