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
import 'notification_history_screen.dart';
import 'notification_settings_data_source.dart';

typedef NotificationTimePicker = Future<TimeOfDay?> Function(
  BuildContext context,
  TimeOfDay initialTime,
);

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.service,
    this.dataSource,
    this.timePicker,
  });

  final FolegoRepository repository;
  final String spaceId;
  final NotificationService? service;
  final NotificationSettingsDataSource? dataSource;
  final NotificationTimePicker? timePicker;

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
  bool _savingThis(String key) => _savingKey == key;

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

  Future<TimeOfDay?> _chooseTime(int hour, int minute) {
    final initial = TimeOfDay(hour: hour, minute: minute);
    return widget.timePicker == null
        ? showTimePicker(context: context, initialTime: initial)
        : widget.timePicker!(context, initial);
  }

  Future<void> _pickReminderTime() async {
    final current = _preferences;
    if (current == null || _saving) return;
    final value = await _chooseTime(current.preferredHour, current.preferredMinute);
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

  Future<void> _pickDailySummaryTime() async {
    final current = _preferences;
    if (current == null || _saving) return;
    final value = await _chooseTime(
      current.dailySummaryHour,
      current.dailySummaryMinute,
    );
    if (value == null || !mounted) return;
    await _save(
      current.copyWith(
        dailySummaryHour: value.hour,
        dailySummaryMinute: value.minute,
      ),
      key: 'daily-time',
      label: 'o horário do resumo diário',
    );
  }

  Future<void> _pickQuietStart() async {
    final current = _preferences;
    if (current == null || _saving) return;
    final value = await _chooseTime(
      current.quietStartHour,
      current.quietStartMinute,
    );
    if (value == null || !mounted) return;
    await _save(
      current.copyWith(
        quietStartHour: value.hour,
        quietStartMinute: value.minute,
      ),
      key: 'quiet-start',
      label: 'o início do não perturbe',
    );
  }

  Future<void> _pickQuietEnd() async {
    final current = _preferences;
    if (current == null || _saving) return;
    final value = await _chooseTime(
      current.quietEndHour,
      current.quietEndMinute,
    );
    if (value == null || !mounted) return;
    await _save(
      current.copyWith(
        quietEndHour: value.hour,
        quietEndMinute: value.minute,
      ),
      key: 'quiet-end',
      label: 'o fim do não perturbe',
    );
  }

  Future<void> _editLargeExpenseThreshold() async {
    final current = _preferences;
    if (current == null || _saving) return;
    final controller = TextEditingController(
      text: current.largeExpenseThreshold
          .toStringAsFixed(2)
          .replaceAll('.', ','),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('gasto relevante'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'me avise a partir de',
            prefixText: 'R\$ ',
          ),
          onSubmitted: (raw) {
            final parsed = _parseMoney(raw);
            if (parsed != null && parsed > 0) {
              Navigator.of(dialogContext).pop(parsed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = _parseMoney(controller.text);
              if (parsed == null || parsed <= 0) return;
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    await _save(
      current.copyWith(largeExpenseThreshold: value),
      key: 'large-threshold',
      label: 'o valor de gasto relevante',
    );
  }

  double? _parseMoney(String raw) {
    final normalized = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationHistoryScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
        ),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _clock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final prefs = _preferences;
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      appBar: AppBar(title: const Text('notificações')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : prefs == null
              ? _errorState()
              : AppContentContainer.list(
                  fillHeight: true,
                  child: ListView(
                    key: const ValueKey('notification-settings-list'),
                    padding: AppScrollGutter.padding(
                      context,
                      top: 16,
                      bottom: 56,
                    ),
                    children: [
                      _statusCard(brightness),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _InlineSaveError(message: _error!),
                      ],
                      const SizedBox(height: 16),
                      _masterSection(prefs),
                      const SizedBox(height: 16),
                      _typesSection(prefs),
                      const SizedBox(height: 16),
                      _realtimeSection(prefs),
                      const SizedBox(height: 16),
                      _timingSection(prefs),
                      const SizedBox(height: 16),
                      _dailySummarySection(prefs),
                      const SizedBox(height: 16),
                      _quietHoursSection(prefs),
                      const SizedBox(height: 16),
                      _historySection(),
                    ],
                  ),
                ),
    );
  }

  Widget _masterSection(NotificationPreferences prefs) => _SettingsSection(
        title: 'lembretes',
        subtitle: prefs.financialRemindersEnabled
            ? 'seus alertas estão ativos'
            : 'pausados — suas escolhas continuam salvas',
        child: SwitchListTile.adaptive(
          key: const ValueKey('notifications-master-toggle'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(AppIcons.notifications),
          title: const Text('lembretes financeiros'),
          subtitle: const Text('controle geral de todas as notificações'),
          value: prefs.financialRemindersEnabled,
          onChanged: _savingThis('master') ? null : _toggleMaster,
        ),
      );

  Widget _typesSection(NotificationPreferences prefs) => _SettingsSection(
        title: 'tipos de lembrete',
        subtitle: 'vencimentos, recorrências e entradas previstas',
        child: Column(
          children: [
            _toggle(
              keyName: 'invoices',
              icon: AppIcons.creditCard,
              title: 'faturas',
              value: prefs.invoicesEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(invoicesEnabled: value),
                key: 'invoices',
                label: 'a preferência de faturas',
              ),
            ),
            _toggle(
              keyName: 'debts',
              icon: AppIcons.debt,
              title: 'dívidas e parcelas',
              value: prefs.debtsEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(debtsEnabled: value),
                key: 'debts',
                label: 'a preferência de dívidas e parcelas',
              ),
            ),
            _toggle(
              keyName: 'recurrences',
              icon: AppIcons.recurring,
              title: 'recorrências',
              value: prefs.recurrencesEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(recurrencesEnabled: value),
                key: 'recurrences',
                label: 'a preferência de recorrências',
              ),
            ),
            _toggle(
              keyName: 'subscriptions',
              icon: AppIcons.categorySubscriptions,
              title: 'assinaturas',
              value: prefs.subscriptionsEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(subscriptionsEnabled: value),
                key: 'subscriptions',
                label: 'a preferência de assinaturas',
              ),
            ),
            _toggle(
              keyName: 'income',
              icon: AppIcons.income,
              title: 'entradas previstas',
              value: prefs.expectedIncomeEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(expectedIncomeEnabled: value),
                key: 'income',
                label: 'a preferência de entradas previstas',
              ),
            ),
            _toggle(
              keyName: 'overdue',
              icon: AppIcons.warning,
              title: 'itens atrasados',
              value: prefs.overdueEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(overdueEnabled: value),
                key: 'overdue',
                label: 'a preferência de itens atrasados',
              ),
              showDivider: false,
            ),
          ],
        ),
      );

  Widget _realtimeSection(NotificationPreferences prefs) => _SettingsSection(
        title: 'alertas em tempo real',
        subtitle: 'o Fôlego avisa quando algo muda de faixa ou merece atenção',
        child: Column(
          children: [
            _toggle(
              keyName: 'plan-thresholds',
              icon: AppIcons.warning,
              title: 'limites do plano',
              subtitle: '70%, 90% e 100% por categoria',
              value: prefs.planThresholdsEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(planThresholdsEnabled: value),
                key: 'plan-thresholds',
                label: 'os alertas de limite do plano',
              ),
            ),
            _toggle(
              keyName: 'card-thresholds',
              icon: AppIcons.creditCard,
              title: 'limites dos cartões',
              subtitle: '70%, 90% e 100% do limite definido',
              value: prefs.cardLimitThresholdsEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(cardLimitThresholdsEnabled: value),
                key: 'card-thresholds',
                label: 'os alertas de limite dos cartões',
              ),
            ),
            _toggle(
              keyName: 'large-expenses',
              icon: AppIcons.warning,
              title: 'gastos relevantes',
              subtitle: 'avisar quando um gasto passar do valor escolhido',
              value: prefs.largeExpensesEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(largeExpensesEnabled: value),
                key: 'large-expenses',
                label: 'os alertas de gastos relevantes',
              ),
              showDivider: !prefs.largeExpensesEnabled,
            ),
            if (prefs.largeExpensesEnabled)
              ListTile(
                key: const ValueKey('large-expense-threshold'),
                contentPadding: EdgeInsets.zero,
                title: const Text('valor considerado relevante'),
                subtitle: Text(
                  'R\$ ${prefs.largeExpenseThreshold.toStringAsFixed(2).replaceAll('.', ',')}',
                ),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: _savingThis('large-threshold')
                    ? null
                    : _editLargeExpenseThreshold,
              ),
          ],
        ),
      );

  Widget _dailySummarySection(NotificationPreferences prefs) => _SettingsSection(
        title: 'resumo diário',
        subtitle: 'um overview consolidado do seu dinheiro uma vez por dia',
        child: Column(
          children: [
            _toggle(
              keyName: 'daily-summary',
              icon: AppIcons.calendar,
              title: 'Seu Fôlego de hoje',
              subtitle: 'saldo livre, R\$/dia, limites e próximos movimentos',
              value: prefs.dailySummaryEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(dailySummaryEnabled: value),
                key: 'daily-summary',
                label: 'o resumo diário',
              ),
            ),
            ListTile(
              key: const ValueKey('daily-summary-time'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.calendar),
              title: const Text('horário do resumo'),
              subtitle: Text(
                _clock(prefs.dailySummaryHour, prefs.dailySummaryMinute),
              ),
              trailing: const Icon(AppIcons.chevronRight),
              enabled: prefs.dailySummaryEnabled && !_savingThis('daily-time'),
              onTap: !prefs.dailySummaryEnabled || _savingThis('daily-time')
                  ? null
                  : _pickDailySummaryTime,
            ),
          ],
        ),
      );

  Widget _timingSection(NotificationPreferences prefs) => _SettingsSection(
        title: 'quando avisar',
        subtitle: 'escolha a antecedência dos vencimentos e entradas',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SegmentedButton<int>(
                key: const ValueKey('notification-offset'),
                segments: const [
                  ButtonSegment(value: 0, label: Text('no dia')),
                  ButtonSegment(value: 1, label: Text('1 dia antes')),
                  ButtonSegment(value: 3, label: Text('3 dias antes')),
                ],
                selected: <int>{prefs.reminderOffsetDays},
                onSelectionChanged: _savingThis('offset')
                    ? null
                    : (value) => _save(
                          prefs.copyWith(reminderOffsetDays: value.first),
                          key: 'offset',
                          label: 'a antecedência dos lembretes',
                        ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 18),
            ListTile(
              key: const ValueKey('notification-time'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.calendar),
              title: const Text('horário preferido'),
              subtitle: Text(
                _clock(prefs.preferredHour, prefs.preferredMinute),
              ),
              trailing: const Icon(AppIcons.chevronRight),
              onTap: _savingThis('time') ? null : _pickReminderTime,
            ),
          ],
        ),
      );

  Widget _quietHoursSection(NotificationPreferences prefs) => _SettingsSection(
        title: 'não perturbe',
        subtitle:
            'silencia alertas não críticos; atingir 100% de um limite ainda pode avisar',
        child: Column(
          children: [
            _toggle(
              keyName: 'quiet-hours',
              icon: AppIcons.notifications,
              title: 'não perturbe',
              subtitle: prefs.quietHoursEnabled
                  ? '${_clock(prefs.quietStartHour, prefs.quietStartMinute)} até ${_clock(prefs.quietEndHour, prefs.quietEndMinute)}'
                  : 'desativado',
              value: prefs.quietHoursEnabled,
              onChanged: (value) => _save(
                prefs.copyWith(quietHoursEnabled: value),
                key: 'quiet-hours',
                label: 'o não perturbe',
              ),
              showDivider: !prefs.quietHoursEnabled,
            ),
            if (prefs.quietHoursEnabled) ...[
              ListTile(
                key: const ValueKey('quiet-hours-start'),
                contentPadding: EdgeInsets.zero,
                title: const Text('começa'),
                subtitle: Text(
                  _clock(prefs.quietStartHour, prefs.quietStartMinute),
                ),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: _savingThis('quiet-start') ? null : _pickQuietStart,
              ),
              const Divider(height: 1),
              ListTile(
                key: const ValueKey('quiet-hours-end'),
                contentPadding: EdgeInsets.zero,
                title: const Text('termina'),
                subtitle: Text(
                  _clock(prefs.quietEndHour, prefs.quietEndMinute),
                ),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: _savingThis('quiet-end') ? null : _pickQuietEnd,
              ),
            ],
          ],
        ),
      );

  Widget _historySection() => _SettingsSection(
        title: 'histórico',
        subtitle:
            'veja os alertas que o Fôlego realmente entregou nos últimos 90 dias',
        child: ListTile(
          key: const ValueKey('notification-history'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.notifications),
          title: const Text('histórico de alertas'),
          trailing: const Icon(AppIcons.chevronRight),
          onTap: _openHistory,
        ),
      );

  Widget _toggle({
    required String keyName,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) =>
      Column(
        children: [
          Semantics(
            label: 'lembrete de $title',
            toggled: value,
            child: SwitchListTile.adaptive(
              key: ValueKey('notification-toggle-$keyName'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(icon, size: 20),
              title: Text(title),
              subtitle: subtitle == null ? null : Text(subtitle),
              value: value,
              onChanged: _savingThis(keyName) ? null : onChanged,
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
    if (unsupported) {
      title = 'seus lembretes podem ser configurados agora';
      body = 'notificações no celular: em breve';
    } else if (denied) {
      title = 'notificações no celular estão bloqueadas';
      body =
          'suas escolhas continuam salvas. permita notificações nas configurações do dispositivo.';
    } else if (granted) {
      title = 'notificações no celular prontas';
      body =
          'alertas, resumo diário e não perturbe são processados mesmo com o Fôlego fechado.';
    } else {
      title = 'escolha seus lembretes';
      body =
          'quando você ativar a entrega, o dispositivo pedirá a permissão necessária.';
    }

    return Material(
      color: AppColors.surface(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border(brightness)),
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
              FilledButton(
                onPressed: _load,
                child: const Text('tentar de novo'),
              ),
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
    return Material(
      color: AppColors.surface(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border(brightness)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.section(context, fontSize: 16),
            ),
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
        'abra o Fôlego instalado na Tela de Início para receber notificações',
      NotificationPermissionStatus.denied =>
        'as notificações estão bloqueadas nas configurações do dispositivo',
      NotificationPermissionStatus.notDetermined =>
        'a permissão de notificações ainda não foi concedida',
      NotificationPermissionStatus.granted => 'notificações ativadas',
    };
