import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/privacy/financial_privacy.dart';
import '../../data/models/financial_space.dart';
import '../transactions/transaction_detail_sheet_v2.dart';
import '../transactions/transactions_screen.dart';
import 'capture_review_screen.dart';
import '../../core/layout/app_scroll_gutter.dart';
import '../../core/notifications/notification_history_cache.dart';
import '../../core/notifications/notification_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_notifications.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_page_header.dart';

typedef NotificationHistoryLoader =
    Future<List<NotificationHistoryItem>> Function(String spaceId);

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.cache,
    this.authenticatedUserId,
    this.historyLoader,
    this.notificationReadWriter,
  });

  final FolegoRepository repository;
  final String spaceId;
  final NotificationHistoryCache? cache;
  final String? Function()? authenticatedUserId;
  final NotificationHistoryLoader? historyLoader;
  final Future<void> Function(String spaceId, String stableKey)?
  notificationReadWriter;

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  late final NotificationHistoryCache _cache;
  int _loadGeneration = 0;
  Timer? _refreshTimer;
  RealtimeChannel? _channel;
  String _filter = 'todas';

  List<NotificationHistoryItem> _items = const [];
  bool _loading = true;
  bool _usingOfflineCache = false;
  bool _markingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cache = widget.cache ?? NotificationHistoryCache();
    _load();
    if (widget.historyLoader == null) _subscribe();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(quiet: true),
    );
  }

  @override
  void didUpdateWidget(covariant NotificationHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        !identical(oldWidget.repository, widget.repository) ||
        oldWidget.authenticatedUserId != widget.authenticatedUserId ||
        oldWidget.historyLoader != widget.historyLoader) {
      _channel?.unsubscribe();
      if (widget.historyLoader == null) _subscribe();
      _load();
    }
  }

  void _subscribe() {
    final user = _currentUserId();
    if (user == null) return;
    _channel = Supabase.instance.client
        .channel(
          'activity-center:$user:${widget.spaceId}:${identityHashCode(this)}',
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
          callback: (_) => _load(quiet: true),
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
          callback: (_) => _load(quiet: true),
        )
        .subscribe();
  }

  String? _currentUserId() {
    final injected = widget.authenticatedUserId;
    return injected == null
        ? Supabase.instance.client.auth.currentUser?.id
        : injected();
  }

  bool _isCurrentLoad(
    int generation,
    String spaceId,
    String userId,
    FolegoRepository repository,
  ) {
    return mounted &&
        _loadGeneration == generation &&
        widget.spaceId == spaceId &&
        identical(widget.repository, repository) &&
        _currentUserId() == userId;
  }

  Future<void> _load({bool quiet = false}) async {
    final generation = ++_loadGeneration;
    final spaceId = widget.spaceId;
    final repository = widget.repository;
    final historyLoader = widget.historyLoader;
    final userId = _currentUserId();

    // Clear the previous user's data before waiting on any asynchronous work.
    if (!quiet) {
      setState(() {
        _items = const [];
        _loading = true;
        _usingOfflineCache = false;
        _error = null;
      });
    }

    if (userId == null || userId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _items = const [];
        _error = 'entre na sua conta para consultar o histórico';
      });
      return;
    }

    try {
      final items = await (historyLoader == null
          ? repository.getNotificationHistory(spaceId)
          : historyLoader(spaceId));
      if (!_isCurrentLoad(generation, spaceId, userId, repository)) return;

      try {
        await _cache.save(spaceId, items, userId: userId);
      } catch (_) {
        // Cache is best-effort and must never block the online experience.
      }
      if (!_isCurrentLoad(generation, spaceId, userId, repository)) return;

      setState(() {
        _items = items;
        _usingOfflineCache = false;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!_isCurrentLoad(generation, spaceId, userId, repository)) return;

      List<NotificationHistoryItem> cached = const [];
      try {
        cached = await _cache.load(spaceId, userId: userId);
      } catch (_) {
        // Local storage may be unavailable; never fall back to another user.
      }
      if (!_isCurrentLoad(generation, spaceId, userId, repository)) return;

      if (cached.isNotEmpty) {
        setState(() {
          _items = cached;
          _loading = false;
          _usingOfflineCache = true;
        });
        return;
      }

      setState(() {
        _loading = false;
        _error = 'não consegui carregar seu histórico de alertas';
      });
    }
  }

  IconData _iconFor(String kind) => switch (kind) {
    'invoice' || 'cardLimitThreshold' => AppIcons.creditCard,
    'debtInstallment' => AppIcons.debt,
    'recurrence' || 'subscription' => AppIcons.recurring,
    'recurringIncome' => AppIcons.income,
    'overdue' => AppIcons.warning,
    'dailySummary' => AppIcons.calendar,
    _ => AppIcons.notifications,
  };

  String _when(BuildContext context, DateTime value) {
    final local = value.toUtc().subtract(const Duration(hours: 3));
    final date = MaterialLocalizations.of(context).formatShortDate(local);
    final time = TimeOfDay.fromDateTime(local).format(context);
    return '$date · $time · São Paulo';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _markRead(NotificationHistoryItem item) async {
    if (_usingOfflineCache || !item.isUnread) return;
    try {
      final writer = widget.notificationReadWriter;
      if (writer == null) {
        await widget.repository.markNotificationRead(
          widget.spaceId,
          item.readKey,
        );
      } else {
        await writer(widget.spaceId, item.readKey);
      }
      await _load(quiet: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('não consegui marcar como lida. tente novamente.'),
          ),
        );
      }
    }
  }

  Future<void> _markLoadedAsRead() async {
    if (_markingAll || _loading || _error != null || _usingOfflineCache) return;
    final userId = _currentUserId();
    final spaceId = widget.spaceId;
    if (userId == null) return;
    final keys = _items.where((item) => item.isUnread)
        .map((item) => item.readKey).toSet().toList();
    if (keys.isEmpty || keys.length > 100) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('marcar avisos como lidos?'),
        content: Text(
          'Marcar ${keys.length} aviso(s) exibidos como lidos. '
          'Comprovantes e lançamentos pendentes continuam exigindo revisão. '
          'Isso não cria nem altera movimentos financeiros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('marcar como lidos'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || spaceId != widget.spaceId ||
        userId != _currentUserId()) {
        return;
      }
    setState(() => _markingAll = true);
    try {
      final writer = widget.notificationReadWriter;
      if (writer == null) {
        await widget.repository.markNotificationsReadBatch(spaceId, keys);
      } else {
        for (final key in keys) {
          if (!mounted || widget.spaceId != spaceId ||
              userId != _currentUserId()) {
        return;
      }
          await writer(spaceId, key);
        }
      }
      if (!mounted || widget.spaceId != spaceId ||
          userId != _currentUserId()) {
        return;
      }
      await _load(quiet: true);
      if (!mounted || widget.spaceId != spaceId ||
          userId != _currentUserId()) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('avisos exibidos marcados como lidos. pendências continuam abertas.'),
      ));
    } catch (_) {
      if (mounted && widget.spaceId == spaceId &&
          userId == _currentUserId()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('não consegui concluir. atualize e tente novamente.'),
        ));
        await _load(quiet: true);
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(NotificationHistoryItem item) async {
    if (_usingOfflineCache) return;
    await _markRead(item);
    if (!mounted) return;
    final uri = Uri.tryParse(item.route);
    final segments = uri?.pathSegments ?? const <String>[];
    final payloadEvent = item.payload['event_id']?.toString();
    final capture =
        item.payload['capture_id']?.toString() ??
        (segments.length == 2 && segments.first == 'captures'
            ? segments[1]
            : null);
    if (capture != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CaptureReviewScreen(
            repository: widget.repository,
            spaceId: widget.spaceId,
            captureId: capture,
          ),
        ),
      );
    } else if (payloadEvent != null ||
        (segments.length == 2 &&
            segments.first == 'transactions' &&
            segments[1] != 'classification')) {
      await showTransactionDetail(
        context: context,
        space: FinancialSpace(id: widget.spaceId, name: 'Minhas finanças'),
        repository: widget.repository,
        eventId: payloadEvent ?? segments[1],
      );
    } else if (item.route.startsWith('/transactions')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransactionsScreen(
            repository: widget.repository,
            space: FinancialSpace(id: widget.spaceId, name: 'Minhas finanças'),
            initialPushRoute: '/transactions/classification',
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  FinancialPrivacy.hidden.value ? 'valores ocultos' : item.body,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('fechar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (mounted) await _load(quiet: true);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final filtered =
        _items
            .where(
              (item) => switch (_filter) {
                'novas' => item.isUnread,
                'pendentes' => item.needsReview,
                _ => true,
              },
            )
            .toList()
          ..sort((a, b) {
            int group(NotificationHistoryItem item) => item.needsReview
                ? 1
                : item.isUnread
                ? 0
                : 2;
            final result = group(a).compareTo(group(b));
            return result != 0
                ? result
                : b.deliveredAt.compareTo(a.deliveredAt);
          });
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: SafeArea(
        child: AppContentContainer.list(
          fillHeight: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                child: AppPageHeader(
                  title: 'notificações',
                  subtitle: 'novidades e o que precisa da sua atenção',
                  leading: IconButton(
                    tooltip: 'voltar',
                    icon: const Icon(AppIcons.back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  trailing: IconButton(
                    tooltip: 'atualizar',
                    icon: const Icon(Icons.refresh),
                    onPressed: _load,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: ['todas', 'novas', 'pendentes']
                    .map(
                      (filter) => ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    )
                    .toList(),
              ),
              if (!_loading && _error == null && !_usingOfflineCache &&
                  _items.any((item) => item.isUnread))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('activity-mark-loaded-read'),
                    onPressed: _markingAll ? null : _markLoadedAsRead,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('marcar avisos exibidos como lidos'),
                  ),
                ),
              if (_usingOfflineCache)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('sem conexão · mostrando a última cópia salva'),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: _loading
                    ? const AppLoadingState(label: 'organizando seu histórico')
                    : _error != null
                    ? AppErrorState(
                        title: 'não consegui carregar seu histórico',
                        description: _error,
                        onRetry: _load,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: filtered.isEmpty
                            ? ListView(
                                padding: AppScrollGutter.padding(
                                  context,
                                  top: 70,
                                  bottom: 60,
                                ),
                                children: const [
                                  AppEmptyState(
                                    icon: AppIcons.notifications,
                                    title: 'nenhum alerta enviado ainda',
                                    description: 'novos lançamentos e comprovantes para revisar aparecem aqui',
                                  ),
                                ],
                              )
                            : ListView.builder(
                                key: const ValueKey(
                                  'notification-history-list',
                                ),
                                padding: AppScrollGutter.padding(
                                  context,
                                  top: 8,
                                  bottom: 48,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final group = item.needsReview
                                      ? 'pendentes de revisão'
                                      : item.isUnread
                                      ? 'novas'
                                      : 'anteriores';
                                  final previous = index == 0
                                      ? null
                                      : filtered[index - 1];
                                  final previousGroup = previous == null
                                      ? null
                                      : previous.needsReview
                                      ? 'pendentes de revisão'
                                      : previous.isUnread
                                      ? 'novas'
                                      : 'anteriores';
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (previousGroup != group)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: Text(
                                            group,
                                            style: AppTypography.section(
                                              context,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      Card(
                                        color: AppColors.surface(brightness),
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.compactCard,
                                          ),
                                          side: BorderSide(
                                            color: item.isUnread
                                                ? AppColors.primaryPurple(
                                                    brightness,
                                                  )
                                                : AppColors.border(brightness),
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.compactCard,
                                          ),
                                          onTap: () => _open(item),
                                          child: Padding(
                                            padding: const EdgeInsets.all(15),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  item.needsReview
                                                      ? AppIcons.warning
                                                      : _iconFor(item.kind),
                                                  size: 21,
                                                  color:
                                                      AppColors.primaryPurple(
                                                        brightness,
                                                      ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item.title,
                                                        style:
                                                            AppTypography.section(
                                                              context,
                                                              fontSize: 14,
                                                            ),
                                                      ),
                                                      if (item
                                                          .body
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 5,
                                                        ),
                                                        Text(
                                                          FinancialPrivacy
                                                                  .hidden
                                                                  .value
                                                              ? 'valores ocultos'
                                                              : item.body,
                                                          style: AppTypography.body(
                                                            context,
                                                            fontSize: 12,
                                                            color:
                                                                AppColors.secondaryText(
                                                                  brightness,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                      if (item.payload['review_reason'] !=
                                                          null)
                                                        Text(
                                                          captureReviewReason(
                                                            item.payload['review_reason']
                                                                ?.toString(),
                                                            item.payload['difference'],
                                                          ),
                                                        ),
                                                      if (item.payload['suggested_category'] !=
                                                          null)
                                                        Text(
                                                          'sugestão: ${item.payload['suggested_category']}',
                                                        ),
                                                      const SizedBox(height: 7),
                                                      Text(
                                                        _when(
                                                          context,
                                                          item.deliveredAt,
                                                        ),
                                                        style:
                                                            AppTypography.label(
                                                              context,
                                                              fontSize: 10,
                                                            ),
                                                      ),
                                                      TextButton(
                                                        onPressed:
                                                            _usingOfflineCache
                                                            ? null
                                                            : () => _open(item),
                                                        child: Text(
                                                          item.kind == 'captureNeedsReview'
                                                              ? 'conferir comprovante'
                                                              : item.needsReview
                                                              ? 'revisar e classificar'
                                                              : 'abrir aviso',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (item.isUnread)
                                                  IconButton(
                                                    tooltip: 'marcar como lida',
                                                    icon: const Icon(
                                                      Icons.done,
                                                    ),
                                                    onPressed:
                                                        _usingOfflineCache
                                                        ? null
                                                        : () => _markRead(item),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
