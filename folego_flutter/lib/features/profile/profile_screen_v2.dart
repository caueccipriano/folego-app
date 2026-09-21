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
import '../../core/utils/error_translator.dart';
import '../../data/models/profile_export.dart';
import '../../data/models/profile_identity.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_profile.dart';
import '../../data/repositories/folego_repository_profile_export.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_section_header.dart';
import '../auth/auth_validation.dart';
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
  bool _loadingIdentity = true;
  bool _loadingVersion = true;
  bool _exporting = false;
  bool _signingOut = false;
  bool _accountActionRunning = false;
  bool _deletingAccount = false;
  String? _identityError;
  String? _versionError;

  @override
  void initState() {
    super.initState();
    _identity = ProfileIdentity(email: widget.client.auth.currentUser?.email ?? '');
    _themeMode = AppThemeController.mode.value;
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

  Future<void> _changeEmail() async {
    if (_accountActionRunning || _deletingAccount) return;
    final controller = TextEditingController(
      text: widget.client.auth.currentUser?.email ?? _identity.email,
    );
    String? emailError;
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void submitEmail() {
            final error = AuthValidation.email(controller.text);
            if (error != null) {
              setDialogState(() => emailError = error);
              return;
            }
            Navigator.of(dialogContext).pop(controller.text.trim());
          }

          return AlertDialog(
            scrollable: true,
            title: Text(
              'alterar e-mail',
              style: AppTypography.section(dialogContext, fontSize: 18),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'novo e-mail',
                hintText: 'voce@exemplo.com',
                errorText: emailError,
              ),
              onChanged: (_) {
                if (emailError != null) {
                  setDialogState(() => emailError = null);
                }
              },
              onSubmitted: (_) => submitEmail(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('cancelar'),
              ),
              FilledButton(
                onPressed: submitEmail,
                child: const Text('continuar'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (email == null || !mounted) return;

    setState(() => _accountActionRunning = true);
    try {
      await widget.client.auth.updateUser(UserAttributes(email: email));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'pedido enviado para $email · siga as confirmações enviadas por e-mail',
          ),
        ),
      );
      await _loadIdentity();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorTranslator.forDisplay(error))),
      );
    } finally {
      if (mounted) setState(() => _accountActionRunning = false);
    }
  }

  Future<void> _changePassword() async {
    if (_accountActionRunning || _deletingAccount) return;
    final password = TextEditingController();
    final confirmation = TextEditingController();
    var obscure = true;
    var obscureConfirmation = true;
    String? passwordError;
    String? confirmationError;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(
            'alterar senha',
            style: AppTypography.section(dialogContext, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: password,
                autofocus: true,
                obscureText: obscure,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'nova senha',
                  errorText: passwordError,
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(obscure ? AppIcons.eye : AppIcons.eyeOff),
                  ),
                ),
                onChanged: (_) {
                  if (passwordError != null || confirmationError != null) {
                    setDialogState(() {
                      passwordError = null;
                      confirmationError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmation,
                obscureText: obscureConfirmation,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'confirmar nova senha',
                  errorText: confirmationError,
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(
                      () => obscureConfirmation = !obscureConfirmation,
                    ),
                    icon: Icon(
                      obscureConfirmation ? AppIcons.eye : AppIcons.eyeOff,
                    ),
                  ),
                ),
                onChanged: (_) {
                  if (confirmationError != null) {
                    setDialogState(() => confirmationError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final nextPasswordError = AuthValidation.password(
                  password.text,
                  enforceMinimum: true,
                );
                final nextConfirmationError =
                    AuthValidation.passwordConfirmation(
                  confirmation.text,
                  password.text,
                );
                if (nextPasswordError == null &&
                    nextConfirmationError == null) {
                  Navigator.of(dialogContext).pop(password.text);
                  return;
                }
                setDialogState(() {
                  passwordError = nextPasswordError;
                  confirmationError = nextConfirmationError;
                });
              },
              child: const Text('salvar'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    confirmation.dispose();
    if (result == null || !mounted) return;

    setState(() => _accountActionRunning = true);
    try {
      await widget.client.auth.updateUser(UserAttributes(password: result));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('senha atualizada')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorTranslator.forDisplay(error))),
      );
    } finally {
      if (mounted) setState(() => _accountActionRunning = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_deletingAccount || _accountActionRunning) return;
    final controller = TextEditingController();
    var typed = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(
            'apagar sua conta?',
            style: AppTypography.section(dialogContext, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'isso apaga sua conta e seus dados financeiros. essa ação não pode ser desfeita.',
                style: AppTypography.body(
                  dialogContext,
                  fontSize: 12,
                  color: AppColors.secondaryText(
                    Theme.of(dialogContext).brightness,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'digite APAGAR para confirmar',
                ),
                onChanged: (value) =>
                    setDialogState(() => typed = value.trim().toUpperCase()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('cancelar'),
            ),
            FilledButton(
              onPressed: typed == 'APAGAR'
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('apagar conta'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      final response = await widget.client.functions.invoke('delete-account');
      if (response.status < 200 || response.status >= 300) {
        throw StateError('delete_account_failed');
      }

      final notificationService = NotificationServiceRegistry.current;
      if (notificationService != null) {
        await notificationService.clearForLogout();
      }
      await AppPreferences.setRememberedEmail(null);
      try {
        await widget.client.auth.signOut();
      } catch (_) {
        // O usuário já pode ter sido removido do Auth.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('conta apagada')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? 'não consegui apagar sua conta agora'
                : ErrorTranslator.forDisplay(error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
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
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: AppIcons.edit,
                  title: 'alterar e-mail',
                  subtitle: widget.client.auth.currentUser?.email ??
                      _identity.email,
                  enabled: !_accountActionRunning && !_deletingAccount,
                  onTap: _changeEmail,
                ),
                _SettingsRow(
                  icon: AppIcons.privacy,
                  title: 'alterar senha',
                  subtitle: 'troque sua senha de acesso ao Fôlego',
                  enabled: !_accountActionRunning && !_deletingAccount,
                  onTap: _changePassword,
                ),
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

  Widget _preferencesSection() => _ProfileSection(
        title: 'preferências',
        subtitle: 'aparência, notificações e automações',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppearanceCard(selected: _themeMode, onSelected: _setTheme),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: AppIcons.notifications,
                  title: 'notificações',
                  subtitle:
                      'faturas, dívidas, recorrências, assinaturas e entradas previstas',
                  onTap: _openNotificationSettings,
                ),
                _SettingsRow(
                  icon: AppIcons.recurring,
                  title: 'automações',
                  subtitle:
                      'quando algo parecido aparecer, sugerir ou preparar a classificação',
                  onTap: _openAutomationRules,
                ),
              ],
            ),

          ],
        ),
      );

  Widget _dataSection() => _ProfileSection(
        title: 'dados e aplicativo',
        subtitle: 'exportação e informações desta instalação',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsCard(
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
            const SizedBox(height: 10),
            _AboutCard(
              versionInfo: _versionInfo,
              loading: _loadingVersion,
              error: _versionError,
              onRetry: _loadVersion,
            ),
          ],
        ),
      );

  Widget _logoutSection() => _ProfileSection(
        title: 'sessão',
        subtitle: 'acesso neste dispositivo',
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
            _SettingsRow(
              icon: AppIcons.delete,
              title: _deletingAccount ? 'apagando conta…' : 'apagar conta',
              subtitle: 'remove permanentemente sua conta e seus dados',
              destructive: true,
              enabled: !_deletingAccount && !_accountActionRunning,
              trailing: _deletingAccount
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _deleteAccount,
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
      const SizedBox(height: 8),
      _preferencesSection(),
      const SizedBox(height: 8),
      _dataSection(),
      const SizedBox(height: 8),
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
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 68),
            children: [
              const AppPageHeader(
                title: 'perfil',
                subtitle: 'sua conta, preferências e privacidade',
              ),
              const SizedBox(height: 10),
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
                          const SizedBox(height: 20),
                          _logoutSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      key: const ValueKey('profile-settings-column'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _preferencesSection(),
                          const SizedBox(height: 28),
                          _dataSection(),
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
