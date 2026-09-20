part of 'profile_screen_v2.dart';

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.section(
            context,
            fontSize: 17,
            color: AppColors.primaryText(brightness),
          ),
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
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.identity,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final ProfileIdentity identity;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.feature),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: 'iniciais ${identity.initials}',
                image: true,
                child: Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: purple.withValues(alpha: .22)),
                  ),
                  child: Text(
                    identity.initials,
                    style: AppTypography.section(
                      context,
                      fontSize: 20,
                      color: purple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.section(
                        context,
                        fontSize: 18,
                        color: primary,
                      ),
                    ),
                    if (identity.email.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        identity.email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          context,
                          fontSize: 12,
                          color: secondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      'conta pessoal do Fôlego',
                      style: AppTypography.label(
                        context,
                        fontSize: 9,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
              decoration: BoxDecoration(
                color: border.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      error!,
                      style: AppTypography.body(
                        context,
                        fontSize: 10,
                        color: secondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('tentar novamente'),
                  ),
                ],
              ),
            ),
          ],
        ],
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
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final expense = AppColors.expenseText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final foreground = destructive ? expense : primary;
    final iconColor = enabled
        ? (destructive ? expense : purple)
        : secondary;

    return Semantics(
      button: onTap != null,
      enabled: enabled,
      label: title,
      child: Material(
        color: AppColors.surface(brightness),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.body(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: enabled ? foreground : secondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppTypography.body(
                            context,
                            fontSize: 10,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (trailing != null)
                    trailing!
                  else if (trailingLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.border(brightness).withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        trailingLabel!,
                        style: AppTypography.label(
                          context,
                          fontSize: 9,
                          color: secondary,
                        ),
                      ),
                    )
                  else if (onTap != null)
                    Icon(AppIcons.chevronRight, size: 18, color: secondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({
    required this.selected,
    required this.onSelected,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return _ChoiceSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppBreakpoints.fromWidth(constraints.maxWidth);
          final gap = layout == AppLayoutSize.compact ? 6.0 : 8.0;
          final optionWidth = (constraints.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: optionWidth,
                child: _AppearanceOption(
                  label: 'sistema',
                  icon: AppIcons.systemTheme,
                  selected: selected == ThemeMode.system,
                  onTap: () => onSelected(ThemeMode.system),
                ),
              ),
              SizedBox(
                width: optionWidth,
                child: _AppearanceOption(
                  label: 'claro',
                  icon: AppIcons.lightTheme,
                  selected: selected == ThemeMode.light,
                  onTap: () => onSelected(ThemeMode.light),
                ),
              ),
              SizedBox(
                width: optionWidth,
                child: _AppearanceOption(
                  label: 'escuro',
                  icon: AppIcons.darkTheme,
                  selected: selected == ThemeMode.dark,
                  onTap: () => onSelected(ThemeMode.dark),
                ),
              ),
            ],
          );
        },
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
    final primary = AppColors.primaryText(brightness);
    final border = AppColors.border(brightness);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? purple.withValues(alpha: .11) : AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(
                color: selected ? purple.withValues(alpha: .45) : border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: selected ? purple : primary),
                const SizedBox(height: 7),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? purple : primary,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(height: 4),
                  Icon(AppIcons.check, size: 14, color: purple),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.selected,
    required this.onSelected,
  });

  final AppLanguagePreference selected;
  final ValueChanged<AppLanguagePreference> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        _LanguageOption(
          label: 'Sistema',
          subtitle: 'usa português enquanto outros idiomas não estão completos',
          icon: AppIcons.systemTheme,
          selected: selected == AppLanguagePreference.system,
          onTap: () => onSelected(AppLanguagePreference.system),
        ),
        _ChoiceDivider(),
        _LanguageOption(
          label: 'Português (Brasil)',
          subtitle: 'idioma completo',
          icon: AppIcons.language,
          selected: selected == AppLanguagePreference.portugueseBrazil,
          onTap: () => onSelected(AppLanguagePreference.portugueseBrazil),
        ),

      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    this.onTap,
    this.enabled = true,
    this.badge,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final purple = AppColors.primaryPurple(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return Semantics(
      button: enabled && onTap != null,
      enabled: enabled,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? purple.withValues(alpha: .07)
            : AppColors.surface(brightness),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: enabled && selected ? purple : secondary,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTypography.body(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: !enabled
                                ? secondary
                                : selected
                                    ? purple
                                    : primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.label(
                            context,
                            fontSize: 9,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.border(brightness).withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        badge!,
                        style: AppTypography.label(
                          context,
                          fontSize: 9,
                          color: secondary,
                        ),
                      ),
                    )
                  else if (selected)
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.check, size: 16, color: purple),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceSurface extends StatelessWidget {
  const _ChoiceSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: child,
    );
  }
}

class _ChoiceDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 46,
      endIndent: 12,
      color: AppColors.border(Theme.of(context).brightness),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.versionInfo,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final AppVersionInfo? versionInfo;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(AppIcons.info, size: 21, color: purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fôlego',
                  style: AppTypography.section(
                    context,
                    fontSize: 17,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'seu dinheiro com um pouco mais de espaço pra respirar.',
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: secondary,
                  ),
                ),
                const SizedBox(height: 10),
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: purple,
                    ),
                  )
                else if (versionInfo != null)
                  Text(
                    versionInfo!.versionLabel,
                    style: AppTypography.label(
                      context,
                      fontSize: 10,
                      color: secondary,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          error ?? 'versão indisponível',
                          style: AppTypography.label(
                            context,
                            fontSize: 10,
                            color: secondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('tentar novamente'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
