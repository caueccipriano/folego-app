import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/folego_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.client,
    required this.repository,
  });

  final SupabaseClient client;
  final FolegoRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Você';

  String _appearance = 'dark';

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    try {
      final name = await widget.repository.getProfileName();

      if (!mounted) {
        return;
      }

      setState(() {
        _name = name;
      });
    } catch (_) {}
  }

  Future<void> _setAppearance(String value) async {
    switch (value) {
      case 'system':
        AppThemeController.setSystem();
        break;

      case 'light':
        AppThemeController.setLight();
        break;

      case 'dark':
        AppThemeController.setDark();
        break;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _appearance = value;
    });
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final brightness = Theme.of(sheetContext).brightness;

        final surface = AppColors.surface(brightness);

        final border = AppColors.border(brightness);

        final primaryText = AppColors.primaryText(brightness);

        final secondaryText = AppColors.secondaryText(brightness);

        final expense = AppColors.expenseText(brightness);

        return Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: expense.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(TablerIcons.logout, size: 23, color: expense),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'sair do fôlego?',
                    textAlign: TextAlign.center,
                    style: AppTypography.section(
                      sheetContext,
                      fontSize: 18,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Você poderá entrar novamente com sua conta.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      sheetContext,
                      fontSize: 12,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(false);
                          },
                          child: const Text('cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: expense,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('sair'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await widget.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final background = AppColors.background(brightness);

    final surface = AppColors.surface(brightness);

    final border = AppColors.border(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final purple = AppColors.primaryPurple(brightness);

    final email = widget.client.auth.currentUser?.email ?? '';

    final initial = _name.trim().isEmpty ? '?' : _name.trim()[0].toUpperCase();

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 120),
              children: [
                Text(
                  'perfil',
                  style: AppTypography.display(
                    context,
                    fontSize: 28,
                    color: primaryText,
                  ),
                ),

                const SizedBox(height: 20),

                // PERFIL DO USUÁRIO
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: purple.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: Text(
                          initial,
                          style: AppTypography.section(
                            context,
                            fontSize: 22,
                            color: purple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name.toLowerCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.section(
                                context,
                                fontSize: 18,
                                color: primaryText,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                  context,
                                  fontSize: 12,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                _SectionTitle(
                  title: 'aparência',
                  subtitle: 'deixe o Fôlego do seu jeito',
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AppearanceOption(
                          label: 'sistema',
                          icon: TablerIcons.deviceDesktop,
                          selected: _appearance == 'system',
                          onTap: () => _setAppearance('system'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _AppearanceOption(
                          label: 'claro',
                          icon: TablerIcons.sun,
                          selected: _appearance == 'light',
                          onTap: () => _setAppearance('light'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _AppearanceOption(
                          label: 'escuro',
                          icon: TablerIcons.moon,
                          selected: _appearance == 'dark',
                          onTap: () => _setAppearance('dark'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                _SectionTitle(
                  title: 'preferências',
                  subtitle: 'ajustes que acompanham você',
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                ),

                const SizedBox(height: 12),

                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: TablerIcons.language,
                      title: 'idioma',
                      subtitle: 'português (Brasil)',
                      trailingLabel: 'em breve',
                      enabled: false,
                    ),
                    _SettingsDivider(color: border),
                    _SettingsRow(
                      icon: TablerIcons.bell,
                      title: 'notificações',
                      subtitle: 'avisos e lembretes do Fôlego',
                      trailingLabel: 'em breve',
                      enabled: false,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                _SectionTitle(
                  title: 'privacidade e segurança',
                  subtitle: 'seus dados continuam seus',
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                ),

                const SizedBox(height: 12),

                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: TablerIcons.lock,
                      title: 'conta protegida',
                      subtitle: 'autenticação e RLS ativos',
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: TablerIcons.logout,
                      title: 'sair',
                      subtitle: 'encerrar sessão neste dispositivo',
                      destructive: true,
                      onTap: _confirmSignOut,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.primaryText,
    required this.secondaryText,
  });

  final String title;
  final String subtitle;

  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.section(
            context,
            fontSize: 17,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.body(
            context,
            fontSize: 12,
            color: secondaryText,
          ),
        ),
      ],
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final purple = AppColors.primaryPurple(brightness);

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? purple.withValues(alpha: .14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? purple.withValues(alpha: .45)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 21, color: selected ? purple : secondaryText),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                style: AppTypography.label(
                  context,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? primaryText : secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: color);
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    this.enabled = true,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  final String? trailingLabel;

  final bool enabled;
  final bool destructive;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final primaryText = AppColors.primaryText(brightness);

    final secondaryText = AppColors.secondaryText(brightness);

    final border = AppColors.border(brightness);

    final expense = AppColors.expenseText(brightness);

    final purple = AppColors.primaryPurple(brightness);

    final foreground = destructive
        ? expense
        : enabled
        ? primaryText
        : secondaryText;

    final iconColor = destructive
        ? expense
        : enabled
        ? purple
        : secondaryText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body(
                        context,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: border.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    trailingLabel!,
                    style: AppTypography.label(
                      context,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: secondaryText,
                    ),
                  ),
                )
              else if (onTap != null)
                Icon(TablerIcons.chevronRight, size: 18, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
