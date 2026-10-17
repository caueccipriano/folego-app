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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          subtitle: subtitle,
        ),
        const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(10),
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
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(AppRadii.compactCard),
                    border: Border.all(color: purple.withValues(alpha: .22)),
                  ),
                  child: Text(
                    identity.initials,
                    style: AppTypography.section(
                      context,
                      fontSize: 16,
                      color: purple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 15,
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
                          fontSize: 11,
                          color: secondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      'conta pessoal',
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
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
      value: subtitle,
      child: ExcludeSemantics(
        child: Material(
        color: AppColors.surface(brightness),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
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
                            fontWeight: FontWeight.w700,
                            color: enabled ? foreground : secondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (trailing != null)
                    trailing!
                  else if (onTap != null)
                    Icon(AppIcons.chevronRight, size: 18, color: secondary),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// Separate destination: Perfil > Preferências > Tema do app.
class _ThemeAppScreen extends StatelessWidget {
  const _ThemeAppScreen();

  Future<void> _saveMode(BuildContext context, ThemeMode mode) async {
    try {
      await AppPreferences.setThemeMode(mode);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('tema aplicado, mas não consegui salvar')),
      );
    }
  }

  Future<void> _savePalette(BuildContext context, String id) async {
    try {
      await AppPreferences.setPaletteId(id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('cor aplicada, mas não consegui salvar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FolegoColorTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('tema do app')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                Text('seu Fôlego, sua identidade',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Escolha uma paleta e como ela aparece. Cada opção tem '
                  'uma versão clara e outra escura. Isso muda só o visual, '
                  'não os valores nem as classificações.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<String>(
                  valueListenable: AppThemeController.paletteId,
                  builder: (context, paletteId, _) =>
                      ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppThemeController.mode,
                    builder: (context, mode, _) => _AppearanceCard(
                      selected: mode,
                      onSelected: (value) => _saveMode(context, value),
                      paletteSelected: paletteId,
                      onPaletteSelected: (id) => _savePalette(context, id),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _ThemeLivePreview(),
                const SizedBox(height: 12),
                Text(
                  'Verde, âmbar e vermelho continuam indicando os mesmos '
                  'estados financeiros em todos os temas.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textoSecundario,
                  ),
                ),
              ],
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
    required this.paletteSelected,
    required this.onPaletteSelected,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;
  final String paletteSelected;
  final ValueChanged<String> onPaletteSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('modo de exibição',
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _ChoiceSurface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gap = constraints.maxWidth < 350 ? 6.0 : 8.0;
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
        ),
        const SizedBox(height: 20),
        Text('paletas de cores',
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Toque para aplicar. Compare as versões clara e escura.',
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        _PaletteGrid(selected: paletteSelected, onSelected: onPaletteSelected),
      ],
    );
  }
}

class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final activeColors = FolegoColorTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 650 ? 3 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final palette in FolegoColorTokens.catalog)
              SizedBox(
                width: width,
                child: Builder(
                  builder: (context) {
                    final light = FolegoColorTokens.fromId(
                      palette.id, Brightness.light);
                    final dark = FolegoColorTokens.fromId(
                      palette.id, Brightness.dark);
                    final active = selected == palette.id;
                    return Semantics(
                      button: true,
                      selected: active,
                      label: 'tema ${palette.name}, ${palette.description}',
                      child: Material(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        child: InkWell(
                          onTap: () => onSelected(palette.id),
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          child: Container(
                            key: ValueKey('theme-palette-${palette.id}'),
                            constraints: const BoxConstraints(minHeight: 130),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadii.control),
                              border: Border.all(
                                color: active
                                    ? activeColors.marca : activeColors.borda,
                                width: active ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _PaletteMiniPreview(
                                      colors: light, label: 'claro')),
                                    const SizedBox(width: 4),
                                    Expanded(child: _PaletteMiniPreview(
                                      colors: dark, label: 'escuro')),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        palette.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme.labelLarge,
                                      ),
                                    ),
                                    if (active)
                                      Icon(Icons.check_circle_rounded,
                                        color: activeColors.marca, size: 17),
                                  ],
                                ),
                                Text(
                                  palette.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme.bodySmall?.copyWith(
                                    color: activeColors.textoSecundario,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PaletteMiniPreview extends StatelessWidget {
  const _PaletteMiniPreview({required this.colors, required this.label});
  final FolegoColorTokens colors;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 53,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: colors.fundo,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: colors.borda),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
          color: colors.textoSecundario,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 4),
        Expanded(
          child: Row(
            children: [
              Expanded(child: Container(
                decoration: BoxDecoration(
                  color: colors.marcaHero,
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
              const SizedBox(width: 3),
              Expanded(child: Container(
                decoration: BoxDecoration(
                  color: colors.superficieAlta,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: Container(height: 5, width: 18,
                  decoration: BoxDecoration(
                    color: colors.acao,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              )),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ThemeLivePreview extends StatelessWidget {
  const _ThemeLivePreview();

  @override
  Widget build(BuildContext context) {
    final colors = FolegoColorTokens.of(context);
    return Container(
      key: const ValueKey('theme-live-preview'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.superficie,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('prévia no app',
            style: AppTypography.cardTitle(context, fontSize: 15)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.marcaHero,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('seu dinheiro disponível',
                  style: AppTypography.body(
                    context, fontSize: 12, color: colors.marcaHeroSobre,
                  )),
                const SizedBox(height: 6),
                Text(r'R$ 1.250,00',
                  style: AppTypography.money(
                    context, fontSize: 26, color: colors.acaoHero,
                  )),
                const SizedBox(height: 5),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'em conta: ',
                      style: AppTypography.body(
                        context, fontSize: 12, color: colors.marcaHeroSobre,
                      )),
                    TextSpan(text: r'R$ 62,90',
                      style: AppTypography.money(
                        context, fontSize: 13, color: colors.acaoHero,
                      )),
                  ]),
                  style: AppTypography.body(context, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.acao,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('simulação visual',
                    style: AppTypography.label(
                      context, fontSize: 11, fontWeight: FontWeight.w700,
                      color: colors.acaoSobre,
                    )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Valores ilustrativos — não são seus saldos.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textoSecundario,
            )),
        ],
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
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(
                color: selected ? purple.withValues(alpha: .45) : border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? purple : primary),
                const SizedBox(height: 5),
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

              ],
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: child,
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
