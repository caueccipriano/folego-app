import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_info/app_version_info.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/notifications/notification_runtime.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/profile_export.dart';
import '../../data/models/profile_identity.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_profile.dart';
import '../../data/repositories/folego_repository_profile_export.dart';
import '../../shared/widgets/app_page_header.dart';
import 'automation_rules_screen.dart';
import 'financial_organization_screen.dart';
import 'notification_settings_screen.dart';
import 'profile_actions.dart';

part 'profile_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.client,
    required this.repository,
    required this.spaceId,
  });

  final SupabaseClient client;
  final FolegoRepository repository;
  final String spaceId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileLogoutAction _logoutAction;
  late ProfileIdentity _identity;
  AppVersionInfo? _versionInfo;
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguagePreference _language = AppLanguagePreference.system;
  bool _loadingIdentity = true;
  bool _loadingVersion = true;
  bool _exporting = false;
  bool _signingOut = false;
  String? _identityError;
  String? _versionError;

  @override
  void initState() {
    super.initState();
    _identity = ProfileIdentity(email: widget.client.auth.currentUser?.email ?? '');
    _themeMode = AppThemeController.mode.value;
    _language = AppPreferences.languagePreference.value;
    _logoutAction = ProfileLogoutAction(() async {
      final notificationService = NotificationServiceRegistry.current;
      if (notificationService != null) {
        await notificationService.clearForLogout();
      }
      await widget.client.auth.signOut();
    });
    _loadIdentity();
    _loadVersion();
  }

  Future<void> _loadIdentity() async {
    setState(() {
      _loadingIdentity = true;
      _identityError = null;
    });
    try {
      final identity = await widget.repository.getProfileIdentity();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _loadingIdentity = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingIdentity = false;
        _identityError = 'não consegui atualizar os dados da sua conta';
      });
    }
  }

  Future<void> _loadVersion() async {
    setState(() {
      _loadingVersion = true;
      _versionError = null;
    });
    try {
      final info = await AppVersionInfo.load();
      if (!mounted) return;
      setState(() {
        _versionInfo = info;
        _loadingVersion = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingVersion = false;
        _versionError = 'versão indisponível';
      });
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    setState(() => _themeMode = mode);
    try {
      await AppPreferences.setThemeMode(mode);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('tema aplicado, mas não consegui salvar essa preferência'),
        ),
      );
    }
  }

  Future<void> _setLanguage(AppLanguagePreference language) async {
    final normalized = normalizeLanguagePreference(language);
    if (_language == normalized) return;
    setState(() => _language = normalized);
    try {
      await AppPreferences.setLanguagePreference(normalized);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('idioma aplicado, mas não consegui salvar essa preferência'),
        ),
      );
    }
  }

  Future<void> _openFinancialOrganization() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinancialOrganizationScreen(repository: widget.repository),
      ),
    );
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationSettingsScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
        ),
      ),
    );
  }

  Future<void> _openAutomationRules() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AutomationRulesScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext anchorContext) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final rows = await widget.repository.listProfileExportRows(
        spaceId: widget.spaceId,
      );
      if (!anchorContext.mounted) return;
      final csv = buildProfileExportCsv(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final fileName = 'folego-dados-${_fileDate(DateTime.now())}.csv';
      final renderBox = anchorContext.findRenderObject() as RenderBox?;
      final origin = renderBox != null && renderBox.hasSize
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : null;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'text/csv;charset=utf-8')],
          fileNameOverrides: [fileName],
          title: 'Exportar dados do Fôlego',
          subject: 'Meus dados do Fôlego',
          sharePositionOrigin: origin,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.status == ShareResultStatus.dismissed
                ? 'exportação cancelada'
                : 'arquivo CSV preparado',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('não consegui exportar seus dados')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmSignOut() async {
    if (_signingOut || _logoutAction.isRunning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'sair do Fôlego?',
          style: AppTypography.section(dialogContext, fontSize: 18),
        ),
        content: Text(
          'isso encerra sua sessão neste dispositivo. seus dados continuam salvos.',
          style: AppTypography.body(
            dialogContext,
            fontSize: 12,
            color: AppColors.secondaryText(Theme.of(dialogContext).brightness),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await _logoutAction.run();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('não consegui encerrar sua sessão')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  String _fileDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}';
  }

  Widget _accountSection() => _ProfileSection(
        title: 'sua conta',
        subtitle: 'sua identidade e preferências do Fôlego',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AccountHeader(
              identity: _identity,
              loading: _loadingIdentity,
              error: _identityError,
              onRetry: _loadIdentity,
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: AppIcons.categoryUnclassified,
                  title: 'organização',
                  subtitle: 'categorias e marcadores em um só lugar',
                  onTap: _openFinancialOrganization,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _appearanceSection() => _ProfileSection(
        title: 'aparência',
        subtitle: 'o tema muda na hora e fica salvo neste dispositivo',
        child: _AppearanceCard(selected: _themeMode, onSelected: _setTheme),
      );

  Widget _languageSection() => _ProfileSection(
        title: 'idioma',
        subtitle:
            'português está completo; outros idiomas entram quando estiverem prontos',
        child: _LanguageCard(selected: _language, onSelected: _setLanguage),
      );

  Widget _notificationsSection() => _ProfileSection(
        title: 'notificações e automações',
        subtitle: 'lembretes do dia a dia e regras para organizar seus lançamentos',
        child: _SettingsCard(
          children: [
            _SettingsRow(
              icon: AppIcons.notifications,
              title: 'notificações',
              subtitle: 'faturas, dívidas, recorrências, assinaturas e entradas previstas',
              onTap: _openNotificationSettings,
            ),
            _SettingsRow(
              icon: AppIcons.recurring,
              title: 'automações',
              subtitle: 'quando algo parecido aparecer, sugerir ou preparar a classificação',
              trailingLabel: 'Premium em breve',
              onTap: _openAutomationRules,
            ),
          ],
        ),
      );

  Widget _privacySection() => _ProfileSection(
        title: 'privacidade e dados',
        subtitle: 'leve uma cópia legível dos dados do seu espaço',
        child: _SettingsCard(
          children: [
            Builder(
              builder: (exportContext) => _SettingsRow(
                icon: AppIcons.exportData,
                title: 'exportar dados',
                subtitle: 'CSV com lançamentos do espaço financeiro atual',
                trailing: _exporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                enabled: !_exporting,
                onTap: () => _exportData(exportContext),
              ),
            ),
          ],
        ),
      );

  Widget _aboutSection() => _ProfileSection(
        title: 'sobre o Fôlego',
        subtitle: 'informações desta instalação',
        child: _AboutCard(
          versionInfo: _versionInfo,
          loading: _loadingVersion,
          error: _versionError,
          onRetry: _loadVersion,
        ),
      );

  Widget _logoutSection() => _ProfileSection(
        title: 'sair',
        subtitle: 'encerre somente a sessão deste dispositivo',
        child: _SettingsCard(
          children: [
            _SettingsRow(
              icon: AppIcons.logout,
              title: _signingOut ? 'saindo…' : 'sair do Fôlego',
              subtitle: 'seus dados e seu onboarding não são apagados',
              destructive: true,
              enabled: !_signingOut,
              trailing: _signingOut
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _confirmSignOut,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;
    final mobileSections = <Widget>[
      _accountSection(),
      const SizedBox(height: 20),
      _appearanceSection(),
      const SizedBox(height: 20),
      _notificationsSection(),
      const SizedBox(height: 20),
      _privacySection(),
      const SizedBox(height: 20),
      _languageSection(),
      const SizedBox(height: 20),
      _aboutSection(),
      const SizedBox(height: 20),
      _logoutSection(),
    ];

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: AppContentContainer(
          maxWidth: desktop ? AppContentWidths.dashboard : AppContentWidths.form,
          fillHeight: true,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 130),
            children: [
              const AppPageHeader(
                title: 'perfil',
                subtitle: 'sua conta, preferências e privacidade',
              ),
              const SizedBox(height: 18),
              if (!desktop)
                ...mobileSections
              else
                Row(
                  key: const ValueKey('profile-desktop-layout'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      key: const ValueKey('profile-identity-column'),
                      width: layout == AppLayoutSize.wide ? 350 : 320,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _accountSection(),
                          const SizedBox(height: 28),
                          _logoutSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      key: const ValueKey('profile-settings-column'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _appearanceSection(),
                          const SizedBox(height: 28),
                          _notificationsSection(),
                          const SizedBox(height: 28),
                          _privacySection(),
                          const SizedBox(height: 28),
                          _languageSection(),
                          const SizedBox(height: 28),
                          _aboutSection(),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
