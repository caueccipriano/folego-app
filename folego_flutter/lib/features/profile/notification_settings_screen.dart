import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/layout/app_scroll_gutter.dart';
import '../../core/notifications/notification_models.dart';
import '../../core/notifications/notification_runtime.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_notifications.dart';
import 'notification_settings_data_source.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.service,
    this.dataSource,
  });

  final FolegoRepository repository;
  final String spaceId;
  final NotificationService? service;
  final NotificationSettingsDataSource? dataSource;

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
  String? _savingKey;
  String? _error;

  late final NotificationService _service;
  late final NotificationSettingsDataSource _dataSource;

  bool get _saving => _savingKey != null;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ??
        RepositoryNotificationSettingsDataSource(widget.repository);
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
        _dataSource.load(widget.spaceId),
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

  Future<void> _save(
    NotificationPreferences next, {
    required String key,
    required String label,
    String? successMessage,
  }) async {
    if (_saving) return;
    final previous = _preferences;
    if (previous == null) return;

    setState(() {
      _savingKey = key;
      _error = null;
      _preferences = next;
    });

    try {
      final saved = await _dataSource.save(next);
      if (!mounted) return;
      setState(() => _preferences = saved);

      // A preferência persistida é a fonte de verdade. A atualização dos
      // lembretes do dispositivo não deve transformar um save bem-sucedido em
      // falha visual; em ambientes sem entrega local, syncUpcoming é seguro.
      try {
        await _service.syncUpcoming(widget.spaceId);
      } catch (error) {
        debugPrint('Notification refresh failed after preference save: $error');
      }

      if (!mounted) return;
      if (successMessage != null) _message(successMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preferences = previous;
        _error = 'não consegui salvar $label';
      });
      _message('não consegui salvar $label');
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  Future<void> _toggleMaster(bool enabled) async {
    final current = _preferences;
    if (current == null || _saving) return;

    if (enabled && _permission != NotificationPermissionStatus.unsupported) {
      final permission = await _service.requestPermission();
      if (!mounted) return;
      setState(() => _permission = permission);
      if (permission != NotificationPermissionStatus.granted) {
        _message(_permissionMessage(permission));
        return;
      }
    }

    await _save(
      current.copyWith(financialRemindersEnabled: enabled),
      key: 'master',
      label: 'sua preferência geral de lembretes',
      successMessage: _permission == NotificationPermissionStatus.unsupported
          ? 'pronto — seus lembretes ficaram configurados'
          : 'preferências de lembrete salvas',
    );
  }

  Future<void> _pickTime() async {
    final current = _preferences;
    if (current == null || _saving) return;
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
      key: 'time',
      label: 'o horário dos lembretes',
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
              : AppContentContainer.list(
                  fillHeight: true,
                  child: ListView(
                    key: const ValueKey('notification-settings-list'),
                    padding: AppScrollGutter.padding(
                      context,
                      top: 16,
                      bottom: 40,
                    ),
                    children: [
                      _statusCard(brightness),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _InlineSaveError(message: _error!),
                      ],
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'lembretes',
                        subtitle: _preferences!.financialRemindersEnabled
                            ? 'suas preferências gerais estão ativas'
                            : 'pausados — suas escolhas continuam salvas',
                        child: SwitchListTile.adaptive(
                          key: const ValueKey('notifications-master-toggle'),
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(AppIcons.notifications),
                          title: const Text('lembretes financeiros'),
                          subtitle: const Text(
                            'controle geral para os lembretes que você escolher abaixo',
                          ),
                          value: _preferences!.financialRemindersEnabled,
                          onChanged: _saving ? null : _toggleMaster,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'tipos de lembrete',
                        subtitle:
                            'você pode ajustar estas escolhas mesmo com os lembretes gerais pausados',
                        child: Column(
                          children: [
                            _toggle(
                              keyName: 'invoices',
                              icon: AppIcons.creditCard,
                              title: 'faturas',
                              value: _preferences!.invoicesEnabled,
                              onChanged: (value) => _save(
                                _preferences!.copyWith(invoicesEnabled: value),
                                key: 'invoices',
                                label: 'a preferência de faturas',
                              ),
                            ),
                            _toggle(
                              keyName: 'debts',
                              icon: AppIcons.debt,
                              title: 'dívidas e parcelas',
                              value: _preferences!.debtsEnabled,
                              onChanged: (value) => _save(
                                _preferences!.copyWith(debtsEnabled: value),
                                key: 'debts',
                                label: 'a preferência de dívidas e parcelas',
                              ),
                            ),
                            _toggle(
                              keyName: 'recurrences',
                              icon: AppIcons.recurring,
                              title: 'recorrências',
                              value: _preferences!.recurrencesEnabled,
                              onChanged: (value) => _save(
                                _preferences!.copyWith(recurrencesEnabled: value),
                                key: 'recurrences',
                                label: 'a preferência de recorrências',
                              ),
                            ),
                            _toggle(
                              keyName: 'subscriptions',
                              icon: AppIcons.categorySubscriptions,
                              title: 'assinaturas',
                              value: _preferences!.subscriptionsEnabled,
                              onChanged: (value) => _save(
                                _preferences!.copyWith(subscriptionsEnabled: value),
                                key: 'subscriptions',
                                label: 'a preferência de assinaturas',
                              ),
                            ),
                            _toggle(
                              keyName: 'income',
                              icon: AppIcons.income,
                              title: 'entradas previstas',
                              value: _preferences!.expectedIncomeEnabled,
                              onChanged: (value) => _save(
                                _preferences!.copyWith(expectedIncomeEnabled: value),
                                key: 'income',
                                label: 'a preferência de entradas previstas',
                              ),
                            ),
                            _toggle(
                              keyName: 'overdue',
                              icon: AppIcons.warning,
                              title: 'itens atrasados',
                              value: _preferences!.overdueEnabled,
                              onChanged: (value) => _save(
                                _preferences!.copyWith(overdueEnabled: value),
                                key: 'overdue',
                                label: 'a preferência de itens atrasados',
                              ),
                              showDivider: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'quando avisar',
                        subtitle: 'escolha a antecedência que funciona para você',
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SegmentedButton<int>(
                            key: const ValueKey('notification-offset'),
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
                                      key: 'offset',
                                      label: 'a antecedência dos lembretes',
                                    ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SettingsSection(
                        title: 'horário',
                        subtitle: 'defina quando você prefere receber seus lembretes',
                        child: ListTile(
                          key: const ValueKey('notification-time'),
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
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _toggle({
    required String keyName,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) => Column(
        children: [
          Semantics(
            label: 'lembrete de $title',
            toggled: value,
            child: SwitchListTile.adaptive(
              key: ValueKey('notification-toggle-$keyName'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(icon, size: 20),
              title: Text(title),
              value: value,
              onChanged: _saving ? null : onChanged,
            ),
          ),
          if (showDivider) const Divider(height: 1),
        ],
      );

  Widget _statusCard(Brightness brightness) {
    final unsupported = _permission == NotificationPermissionStatus.unsupported;
    final denied = _permission == NotificationPermissionStatus.denied;
    final granted = _permission == NotificationPermissionStatus.granted;

    final String title;
    final String body;
    final String? badge;
    if (unsupported) {
      title = 'seus lembretes podem ser configurados agora';
      body =
          'escolha o que você quer receber. As preferências ficam salvas e serão usadas quando as notificações no celular estiverem disponíveis.';
      badge = 'notificações no celular: em breve';
    } else if (denied) {
      title = 'notificações no celular estão bloqueadas';
      body =
          'suas escolhas continuam salvas. Para receber no celular, permita notificações nas configurações do dispositivo.';
      badge = null;
    } else if (granted) {
      title = 'lembretes no celular prontos';
      body =
          'você escolhe o que quer receber e pode mudar essas preferências a qualquer momento.';
      badge = null;
    } else {
      title = 'escolha seus lembretes';
      body =
          'configure primeiro. Quando você ativar a entrega no celular, pediremos a permissão necessária.';
      badge = null;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(brightness)),
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
                    title,
                    style: AppTypography.section(context, fontSize: 15),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      color: AppColors.secondaryText(brightness),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple(brightness)
                            .withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          badge,
                          style: AppTypography.label(
                            context,
                            fontSize: 10,
                            color: AppColors.primaryPurple(brightness),
                          ),
                        ),
                      ),
                    ),
                  ],
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.section(context, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: AppColors.secondaryText(brightness),
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _InlineSaveError extends StatelessWidget {
  const _InlineSaveError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              AppIcons.warning,
              size: 18,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _permissionMessage(NotificationPermissionStatus status) => switch (status) {
      NotificationPermissionStatus.unsupported =>
        'notificações no celular: em breve',
      NotificationPermissionStatus.denied =>
        'as notificações estão bloqueadas nas configurações do dispositivo',
      NotificationPermissionStatus.notDetermined =>
        'a permissão de notificações ainda não foi concedida',
      NotificationPermissionStatus.granted => 'notificações ativadas',
    };
