import 'package:flutter/material.dart';

import '../../core/notifications/notification_models.dart';
import '../../core/notifications/notification_runtime.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_notifications.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.service,
  });

  final FolegoRepository repository;
  final String spaceId;
  final NotificationService? service;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationPreferences? _preferences;
  NotificationPermissionStatus _permission =
      NotificationPermissionStatus.notDetermined;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late final NotificationService _service;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        NotificationServiceRegistry.current ??
        NotificationService(
          adapter: const WebSafeNoopNotificationAdapter(),
          loadPreferences: widget.repository.getNotificationPreferences,
          loadUpcoming: (spaceId, preferences, horizonDays) =>
              widget.repository.getNotificationUpcomingEvents(
                spaceId,
                preferences: preferences,
                horizonDays: horizonDays,
              ),
        );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        widget.repository.getNotificationPreferences(widget.spaceId),
        _service.getPermissionStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _preferences = values[0] as NotificationPreferences;
        _permission = values[1] as NotificationPermissionStatus;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'não consegui carregar suas preferências de notificação';
      });
    }
  }

  Future<void> _save(NotificationPreferences next) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _preferences = next;
    });
    try {
      final saved = await widget.repository.saveNotificationPreferences(next);
      await _service.syncUpcoming(widget.spaceId);
      if (!mounted) return;
      setState(() => _preferences = saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'não consegui salvar essa preferência');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleMaster(bool enabled) async {
    final current = _preferences;
    if (current == null) return;
    if (enabled) {
      final permission = await _service.requestPermission();
      if (!mounted) return;
      setState(() => _permission = permission);
      if (permission != NotificationPermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_permissionMessage(permission))),
        );
        return;
      }
    }
    await _save(current.copyWith(financialRemindersEnabled: enabled));
  }

  Future<void> _pickTime() async {
    final current = _preferences;
    if (current == null) return;
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.preferredHour,
        minute: current.preferredMinute,
      ),
    );
    if (value == null || !mounted) return;
    await _save(
      current.copyWith(
        preferredHour: value.hour,
        preferredMinute: value.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      appBar: AppBar(title: const Text('notificações')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _preferences == null
              ? _errorState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    _statusCard(brightness),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: AppTypography.body(
                          context,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SwitchListTile.adaptive(
                      key: const ValueKey('notifications-master-toggle'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('lembretes financeiros'),
                      subtitle: const Text(
                        'faturas, dívidas, recorrências, assinaturas e entradas previstas',
                      ),
                      value: _preferences!.financialRemindersEnabled,
                      onChanged: _saving ? null : _toggleMaster,
                    ),
                    const Divider(),
                    _toggle(
                      title: 'faturas',
                      value: _preferences!.invoicesEnabled,
                      onChanged: (value) =>
                          _save(_preferences!.copyWith(invoicesEnabled: value)),
                    ),
                    _toggle(
                      title: 'dívidas e parcelas',
                      value: _preferences!.debtsEnabled,
                      onChanged: (value) =>
                          _save(_preferences!.copyWith(debtsEnabled: value)),
                    ),
                    _toggle(
                      title: 'recorrências',
                      value: _preferences!.recurrencesEnabled,
                      onChanged: (value) => _save(
                        _preferences!.copyWith(recurrencesEnabled: value),
                      ),
                    ),
                    _toggle(
                      title: 'assinaturas',
                      value: _preferences!.subscriptionsEnabled,
                      onChanged: (value) => _save(
                        _preferences!.copyWith(subscriptionsEnabled: value),
                      ),
                    ),
                    _toggle(
                      title: 'entradas previstas',
                      value: _preferences!.expectedIncomeEnabled,
                      onChanged: (value) => _save(
                        _preferences!.copyWith(expectedIncomeEnabled: value),
                      ),
                    ),
                    _toggle(
                      title: 'itens atrasados',
                      value: _preferences!.overdueEnabled,
                      onChanged: (value) =>
                          _save(_preferences!.copyWith(overdueEnabled: value)),
                    ),
                    const SizedBox(height: 18),
                    Text('quando avisar', style: AppTypography.section(context)),
                    const SizedBox(height: 10),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('no dia')),
                        ButtonSegment(value: 1, label: Text('1 dia antes')),
                        ButtonSegment(value: 3, label: Text('3 dias antes')),
                      ],
                      selected: <int>{_preferences!.reminderOffsetDays},
                      onSelectionChanged: _saving
                          ? null
                          : (value) => _save(
                                _preferences!.copyWith(
                                  reminderOffsetDays: value.first,
                                ),
                              ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(AppIcons.calendar),
                      title: const Text('horário preferido'),
                      subtitle: Text(
                        '${_preferences!.preferredHour.toString().padLeft(2, '0')}:${_preferences!.preferredMinute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(AppIcons.chevronRight),
                      enabled: !_saving,
                      onTap: _saving ? null : _pickTime,
                    ),
                  ],
                ),
    );
  }

  Widget _toggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: value,
        onChanged: _saving ? null : onChanged,
      );

  Widget _statusCard(Brightness brightness) {
    final unsupported = _permission == NotificationPermissionStatus.unsupported;
    final denied = _permission == NotificationPermissionStatus.denied;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              AppIcons.notifications,
              color: AppColors.primaryPurple(brightness),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unsupported
                        ? 'adapter nativo ainda não disponível neste build'
                        : denied
                            ? 'permissão de notificação bloqueada'
                            : 'lembretes financeiros preparados',
                    style: AppTypography.section(context, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unsupported
                        ? 'as preferências já ficam prontas no backend, mas este build usa um adapter seguro sem notificações locais.'
                        : 'o Fôlego agenda apenas lembretes do seu próprio espaço e não inclui valores no texto da notificação.',
                    style: AppTypography.body(
                      context,
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
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.warning, size: 40),
              const SizedBox(height: 12),
              Text(_error ?? 'não consegui abrir notificações'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('tentar de novo')),
            ],
          ),
        ),
      );
}

String _permissionMessage(NotificationPermissionStatus status) => switch (status) {
      NotificationPermissionStatus.unsupported =>
        'notificações locais ainda não estão disponíveis neste build',
      NotificationPermissionStatus.denied =>
        'a permissão de notificações está bloqueada no dispositivo',
      NotificationPermissionStatus.notDetermined =>
        'a permissão de notificações ainda não foi concedida',
      NotificationPermissionStatus.granted => 'notificações ativadas',
    };
