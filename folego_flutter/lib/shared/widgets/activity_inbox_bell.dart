import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_notifications.dart';
import '../../features/profile/notification_history_screen.dart';

class ActivityInboxBell extends StatefulWidget {
  const ActivityInboxBell({
    super.key,
    required this.repository,
    required this.spaceId,
    this.unreadLoader,
    this.authenticatedUserId,
    this.onOpen,
  });
  final FolegoRepository repository;
  final String spaceId;
  final Future<int> Function(String spaceId)? unreadLoader;
  final String? Function()? authenticatedUserId;
  final Future<void> Function(BuildContext context)? onOpen;
  @override
  State<ActivityInboxBell> createState() => _ActivityInboxBellState();
}

class _ActivityInboxBellState extends State<ActivityInboxBell>
    with WidgetsBindingObserver {
  Timer? _timer;
  RealtimeChannel? _channel;
  int _unread = 0, _generation = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  String? _currentUserId() {
    if (widget.authenticatedUserId != null) {
      return widget.authenticatedUserId!();
    }
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      // Demo screens and repository tests may not initialize Supabase.
      return null;
    }
  }

  void _start() {
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
    final user = _currentUserId();
    if (user == null || widget.unreadLoader != null) return;
    _channel = Supabase.instance.client
        .channel(
          'activity-inbox:$user:${widget.spaceId}:${identityHashCode(this)}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification_history',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user,
          ),
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'financial_activity_read_state',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void didUpdateWidget(covariant ActivityInboxBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.repository != widget.repository ||
        oldWidget.unreadLoader != widget.unreadLoader ||
        oldWidget.authenticatedUserId != widget.authenticatedUserId) {
      _generation++;
      _unread = 0;
      _timer?.cancel();
      _channel?.unsubscribe();
      _start();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final spaceId = widget.spaceId;
    final user = _currentUserId();
    try {
      if (user == null && widget.unreadLoader == null) {
        if (mounted) setState(() => _unread = 0);
        return;
      }
      final count =
          await (widget.unreadLoader?.call(spaceId) ??
              widget.repository.getNotificationUnreadCount(spaceId));
      if (!mounted ||
          generation != _generation ||
          spaceId != widget.spaceId ||
          user != _currentUserId()) {
        return;
      }
      setState(() {
        _unread = count;
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'não foi possível atualizar os avisos');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('activity-inbox-bell'),
    tooltip: _error ?? 'notificações · $_unread não lidas',
    style: IconButton.styleFrom(
      minimumSize: const Size(42, 42),
      backgroundColor: AppColors.surface(Theme.of(context).brightness),
      foregroundColor: AppColors.secondaryText(Theme.of(context).brightness),
    ),
    icon: Badge(
      isLabelVisible: _unread > 0,
      label: Text(_unread > 99 ? '99+' : '$_unread'),
      child: const Icon(AppIcons.notifications, size: 19),
    ),
    onPressed: () async {
      if (widget.onOpen != null) {
        await widget.onOpen!(context);
        if (mounted) await _load();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationHistoryScreen(
            repository: widget.repository,
            spaceId: widget.spaceId,
          ),
        ),
      );
      if (mounted) await _load();
    },
  );
}
