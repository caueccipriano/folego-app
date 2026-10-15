import 'package:flutter/material.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../data/repositories/folego_repository.dart';
import 'flexible_budget_screen.dart';
import 'plan_screen_web2.dart' as base;
import 'projection_screen.dart';
import 'spending_behavior_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.projectionOpenToken,
    this.disableInsightsForTesting = false,
  });

  final FolegoRepository repository;
  final String spaceId;

  /// Changes when another area (for example Home) asks to open
  /// Planejamento > Projeção directly.
  final Object? projectionOpenToken;

  @visibleForTesting
  final bool disableInsightsForTesting;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool _projection = false;
  bool _startWithPurchase = false;

  @override
  void didUpdateWidget(covariant PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      _projection = false;
      _startWithPurchase = false;
    }
    if (oldWidget.projectionOpenToken != widget.projectionOpenToken &&
        widget.projectionOpenToken != null) {
      _projection = true;
    }
  }

  void _openProjection() {
    if (_projection) return;
    setState(() {
      _startWithPurchase = false;
      _projection = true;
    });
  }

  void _openPurchaseProjection() {
    setState(() {
      _startWithPurchase = true;
      _projection = true;
    });
  }

  void _openSpendingBehavior(DateTime month) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => SpendingBehaviorScreen(
        repository: widget.repository,
        spaceId: widget.spaceId,
        periodMonth: month,
      ),
    ));
  }

  void _openSummary() {
    if (!_projection) return;
    setState(() {
      _projection = false;
      _startWithPurchase = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_projection) {
      return ProjectionScreen(
        repository: widget.repository,
        spaceId: widget.spaceId,
        onBack: _openSummary,
        startWithPurchase: _startWithPurchase,
      );
    }

    return RealtimeRefreshView(
      domain: AppRealtimeDomain.plan,
      identity: widget.spaceId,
      builder: (refreshToken) => base.PlanScreen(
        repository: widget.repository,
        spaceId: widget.spaceId,
        refreshToken: refreshToken,
        disableInsightsForTesting: widget.disableInsightsForTesting,
        onProjectionRequested: _openProjection,
        onPurchaseSimulationRequested: _openPurchaseProjection,
        onSpendingBehaviorRequested: _openSpendingBehavior,
        onFlexibleBudgetRequested: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FlexibleBudgetScreen(
              repository: widget.repository,
              spaceId: widget.spaceId,
            ),
          ),
        ),
      ),
    );
  }
}
