import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
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

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final NotificationHistoryCache _cache = NotificationHistoryCache();

  List<NotificationHistoryItem> _items = const [];
  bool _loading = true;
  bool _usingOfflineCache = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _usingOfflineCache = false;
      _error = null;
    });

    try {
      final items =
          await widget.repository.getNotificationHistory(widget.spaceId);

      try {
        await _cache.save(widget.spaceId, items);
      } catch (_) {
        // Cache is best-effort and must never block the online experience.
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      final cached = await _cache.load(widget.spaceId);
      if (!mounted) return;

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
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatShortDate(local);
    final time = TimeOfDay.fromDateTime(local).format(context);
    return '$date · $time';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

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
                  title: 'histórico de alertas',
                  subtitle: 'avisos que o Fôlego já enviou para você',
                  leading: IconButton(
                    tooltip: 'voltar',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(AppIcons.back),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const AppLoadingState(label: 'organizando seu histórico')
                    : _error != null
                        ? AppErrorState(
                            title: 'não consegui carregar seu histórico',
                            description: _error,
                            onRetry: _load,
                          )
                        : Column(
                            children: [
                              if (_usingOfflineCache)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(brightness),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.control,
                                    ),
                                    border: Border.all(
                                      color: AppColors.border(brightness),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        AppIcons.warning,
                                        size: 17,
                                        color: AppColors.secondaryText(brightness),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'sem conexão · mostrando a última cópia salva',
                                          style: AppTypography.label(
                                            context,
                                            fontSize: 10,
                                            color: AppColors.secondaryText(brightness),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_usingOfflineCache) const SizedBox(height: 10),
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: _load,
                                  child: _items.isEmpty
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
                                              description:
                                                  'quando o Fôlego te avisar sobre limites, vencimentos ou o resumo diário, ele aparece aqui',
                                            ),
                                          ],
                                        )
                                      : ListView.separated(
                                          key: const ValueKey(
                                            'notification-history-list',
                                          ),
                                          padding: AppScrollGutter.padding(
                                            context,
                                            top: 8,
                                            bottom: 48,
                                          ),
                                          itemCount: _items.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final item = _items[index];
                                            return Material(
                                              color: AppColors.surface(brightness),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  AppRadii.compactCard,
                                                ),
                                                side: BorderSide(
                                                  color: AppColors.border(
                                                    brightness,
                                                  ),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(15),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      _iconFor(item.kind),
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
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            item.title,
                                                            style:
                                                                AppTypography.section(
                                                              context,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          if (item.body.isNotEmpty) ...[
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              item.body,
                                                              style:
                                                                  AppTypography.body(
                                                                context,
                                                                fontSize: 11,
                                                                color: AppColors
                                                                    .secondaryText(
                                                                  brightness,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
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
                                                              color: AppColors
                                                                  .secondaryText(
                                                                brightness,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
