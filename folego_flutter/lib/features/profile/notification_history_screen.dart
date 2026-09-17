import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/layout/app_scroll_gutter.dart';
import '../../core/notifications/notification_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_notifications.dart';

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
  List<NotificationHistoryItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.getNotificationHistory(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
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
      appBar: AppBar(title: const Text('histórico de alertas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.warning, size: 38),
                        const SizedBox(height: 12),
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('tentar de novo'),
                        ),
                      ],
                    ),
                  ),
                )
              : AppContentContainer.list(
                  fillHeight: true,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            padding: AppScrollGutter.padding(
                              context,
                              top: 80,
                              bottom: 60,
                            ),
                            children: [
                              const Icon(AppIcons.notifications, size: 42),
                              const SizedBox(height: 14),
                              Text(
                                'nenhum alerta enviado ainda',
                                textAlign: TextAlign.center,
                                style: AppTypography.section(context, fontSize: 17),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'quando o Fôlego te avisar sobre limites, vencimentos ou o resumo diário, ele aparece aqui.',
                                textAlign: TextAlign.center,
                                style: AppTypography.body(
                                  context,
                                  fontSize: 12,
                                  color: AppColors.secondaryText(brightness),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            key: const ValueKey('notification-history-list'),
                            padding: AppScrollGutter.padding(
                              context,
                              top: 16,
                              bottom: 48,
                            ),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Material(
                                color: AppColors.surface(brightness),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(color: AppColors.border(brightness)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        _iconFor(item.kind),
                                        size: 21,
                                        color: AppColors.primaryPurple(brightness),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: AppTypography.section(
                                                context,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (item.body.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                item.body,
                                                style: AppTypography.body(
                                                  context,
                                                  fontSize: 11,
                                                  color: AppColors.secondaryText(brightness),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 7),
                                            Text(
                                              _when(context, item.deliveredAt),
                                              style: AppTypography.label(
                                                context,
                                                fontSize: 10,
                                                color: AppColors.secondaryText(brightness),
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
    );
  }
}
