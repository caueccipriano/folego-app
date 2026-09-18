import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notifications/notification_adapter_factory.dart';
import '../../core/notifications/notification_runtime.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_notifications.dart';
import '../../shared/widgets/responsive_navigation_shell.dart';
import '../home/home_screen.dart';
import '../plan/flexible_budget_navigation_scope.dart';
import '../plan/flexible_budget_screen.dart';
import '../plan/plan_screen.dart';
import '../plan/projection_navigation_scope.dart';
import '../profile/profile_screen.dart';
import '../transactions/transactions_screen.dart';
import '../wallet/wallet_screen.dart';

int homeIndexForPushRoute(String? route) {
  if (route == null || route.isEmpty || route == '/' || route == '/agenda') {
    return 0;
  }
  if (route.startsWith('/transactions')) return 1;
  if (route.startsWith('/plan')) return 2;
  if (route.startsWith('/wallet')) return 3;
  if (route.startsWith('/profile')) return 4;
  return 0;
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.space,
    required this.repository,
    this.realtimeEventSource,
  });

  final FinancialSpace space;
  final FolegoRepository repository;
  final AppRealtimeEventSource? realtimeEventSource;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  int _projectionRequestToken = 0;
  late final RealtimeInvalidationCoordinator _realtimeCoordinator;
  late final RealtimeSessionController _realtimeSession;
  late final NotificationService _notificationService;
  late final NotificationRuntimeController _notificationRuntime;
  late final RealtimeRefreshBinding _notificationRealtimeBinding;

  @override
  void initState() {
    super.initState();
    _index = homeIndexForPushRoute(Uri.base.queryParameters['push_route']);
    _realtimeCoordinator = RealtimeInvalidationCoordinator();
    _realtimeSession = RealtimeSessionController(
      coordinator: _realtimeCoordinator,
      eventSource:
          widget.realtimeEventSource ??
          SupabaseRealtimeEventSource(Supabase.instance.client),
    );
    _notificationService = NotificationService(
      adapter: createNotificationSchedulerAdapter(Supabase.instance.client),
      loadPreferences: widget.repository.getNotificationPreferences,
      loadUpcoming: (spaceId, preferences, horizonDays) =>
          widget.repository.getNotificationUpcomingEvents(
        spaceId,
        preferences: preferences,
        horizonDays: horizonDays,
      ),
    );
    _notificationRuntime = NotificationRuntimeController(_notificationService);
    _notificationRealtimeBinding = _realtimeCoordinator.bind(
      domain: AppRealtimeDomain.notifications,
      onRefresh: _syncActiveNotifications,
    );
    AppRealtimeRegistry.attach(_realtimeCoordinator);
    NotificationServiceRegistry.attach(_notificationService);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_activateSpace(widget.space.id));
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.space.id != widget.space.id) {
      unawaited(_switchSpace(widget.space.id));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncActiveNotifications());
    }
  }

  Future<void> _activateSpace(String spaceId) async {
    await _realtimeSession.switchSpace(spaceId);
    try {
      await _notificationRuntime.activateSpace(spaceId);
    } catch (_) {
      // Notification scheduling is additive. Agenda and the rest of the app
      // remain usable if the adapter/backend is temporarily unavailable.
    }
  }

  Future<void> _switchSpace(String spaceId) async {
    await _activateSpace(spaceId);
    if (!mounted) return;
    _realtimeCoordinator.invalidateAll();
  }

  Future<void> _syncActiveNotifications() async {
    try {
      await _notificationRuntime.onAppResumed();
    } catch (_) {
      // Best-effort sync; never block app resume or financial navigation.
    }
  }

  void _openProjection() {
    setState(() {
      _index = 2;
      _projectionRequestToken += 1;
    });
  }

  Future<void> _openFlexibleBudget() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FlexibleBudgetScreen(
          repository: widget.repository,
          spaceId: widget.space.id,
        ),
      ),
    );
    if (!mounted) return;
    _realtimeCoordinator.invalidateDomains({
      AppRealtimeDomain.home,
      AppRealtimeDomain.plan,
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationRealtimeBinding.dispose();
    NotificationServiceRegistry.detach(_notificationService);
    _notificationRuntime.dispose();
    AppRealtimeRegistry.detach(_realtimeCoordinator);
    unawaited(_realtimeSession.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(space: widget.space, repository: widget.repository),
      TransactionsScreen(
        repository: widget.repository,
        space: widget.space,
      ),
      PlanScreen(
        repository: widget.repository,
        spaceId: widget.space.id,
        projectionRequestToken: _projectionRequestToken,
      ),
      WalletScreen(repository: widget.repository, spaceId: widget.space.id),
      ProfileScreen(
        client: Supabase.instance.client,
        repository: widget.repository,
        spaceId: widget.space.id,
      ),
    ];

    return ProjectionNavigationScope(
      onOpen: _openProjection,
      child: FlexibleBudgetNavigationScope(
        onOpen: () => unawaited(_openFlexibleBudget()),
        child: ResponsiveNavigationShell(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          if (_index == value) return;
          setState(() => _index = value);
        },
        pages: pages,
        ),
      ),
    );
  }
}
