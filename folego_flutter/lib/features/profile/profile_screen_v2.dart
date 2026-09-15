import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/folego_repository.dart';
import 'financial_organization_screen.dart';

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
      if (!mounted) return;
      setState(() => _name = name);
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

    if (!mounted) return;
    setState(() => _appearance = value);
  }

  Future<void> _openFinancialOrganization() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinancialOrganizationScreen(
          repository: widget.repository,
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final brightness = Theme.of(dialogContext).brightness;
        final secondaryText = AppColors.secondaryText(brightness);
        return AlertDialog(
          title: const Text('Sair do Fôlego?'),
          content: Text(
            'Você poderá entrar novamente com sua conta.',
            style: AppTypography.body(
              dialogContext,
              fontSize: 12,
              color: secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.client.auth.signOut();
    }
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
        child: AppContentContainer.form(
          fillHeight: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 26, 0, 120),
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
                title: 'organização financeira',
                subtitle: 'personalize como você classifica seu dinheiro',
                primaryText: primaryText,
                secondaryText: secondaryText,
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                surface: surface,
                border: border,
                children: [
                  _SettingsRow(
                    icon: AppIcons.categoryUnclassified,
                    title: 'categorias, tags e atributos',
                    subtitle:
                        'crie categorias próprias, projetos, pessoas e classificações',
                    onTap: _openFinancialOrganization,
                  ),
                ],
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
                        icon: AppIcons.settings,
                        selected: _appearance == 'system',
                        onTap: () => _setAppearance('system'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _AppearanceOption(
                        label: 'claro',
                        icon: AppIcons.lightTheme,
                        selected: _appearance == 'light',
                        onTap: () => _setAppearance('light'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _AppearanceOption(
                        label: 'escuro',
                        icon: AppIcons.darkTheme,
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
                surface: surface,
                border: border,
                children: const [
                  _SettingsRow(
                    icon: AppIcons.notifications,
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
                surface: surface,
                border: border,
                children: [
                  const _SettingsRow(
                    icon: AppIcons.check,
                    title: 'conta protegida',
                    subtitle: 'autenticação e RLS ativos',
                  ),
                  _SettingsDivider(color: border),
                  _SettingsRow(
                    icon: AppIcons.forward,
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
            fontSize: 16,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.body(
            context,
            fontSize: 11,
            color: secondaryText,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.children,
    required this.surface,
    required this.border,
  });

  final List<Widget> children;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
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
    return Divider(height: 1, indent: 58, color: color);
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final expense = AppColors.expenseText(brightness);
    final foreground = destructive ? expense : primaryText;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: enabled ? foreground : secondaryText),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: enabled ? foreground : secondaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.body(
                      context,
                      fontSize: 10,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingLabel != null)
              Text(
                trailingLabel!,
                style: AppTypography.label(
                  context,
                  fontSize: 9,
                  color: secondaryText,
                ),
              )
            else if (onTap != null)
              Icon(AppIcons.chevronRight, size: 18, color: secondaryText),
          ],
        ),
      ),
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? purple.withValues(alpha: .12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? purple : primaryText),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.label(
                context,
                fontSize: 10,
                color: selected ? purple : primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
