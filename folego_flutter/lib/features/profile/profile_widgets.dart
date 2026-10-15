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

/// Página independente para escolher o visual sem ocupar a tela Perfil.
class _ThemeSettingsScreen extends StatefulWidget {
  const _ThemeSettingsScreen({
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
  State<_ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<_ThemeSettingsScreen> {
  late ThemeMode _mode;
  late String _palette;

  @override
  void initState() {
    super.initState();
    _mode = widget.selected;
    _palette = widget.paletteSelected;
  }

  void _changeMode(ThemeMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    widget.onSelected(mode);
  }

  void _changePalette(String id) {
    if (_palette == id) return;
    setState(() => _palette = id);
    widget.onPaletteSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tema do app')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            Text(
              'Seu dinheiro, sua estética.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Personalize as cores do Fôlego. Você pode trocar a paleta '
              'e escolher entre seguir o sistema, claro ou escuro.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.textoSecundario,
              ),
            ),
            const SizedBox(height: 20),
            const _ThemePreviewCard(),
            const SizedBox(height: 20),
            _AppearanceCard(
              selected: _mode,
              onSelected: _changeMode,
              paletteSelected: _palette,
              onPaletteSelected: _changePalette,
            ),
            const SizedBox(height: 16),
            Text(
              'As cores do seu saldo e dos alertas mantêm seu significado '
              'em qualquer tema. Suas informações financeiras não mudam.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard();

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    return Container(
      key: const ValueKey('theme-live-preview'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.superficie,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: tokens.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRÉVIA AO VIVO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: tokens.textoSecundario,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: tokens.marcaHero,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sua visão financeira',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.marcaHeroSobre,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Um exemplo de como os cards ficam no tema escolhido.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.marcaHeroSobre,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.acao,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'Ação principal',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tokens.acaoSobre,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.superficieAlta,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('Superfície',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.textoPrincipal,
                    )),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.fundo,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('Fundo',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.textoPrincipal,
                    )),
                ),
              ),
            ],
          ),
        ],
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
        Text('Modo de exibição',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        _ChoiceSurface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gap = AppBreakpoints.fromWidth(constraints.maxWidth) ==
                      AppLayoutSize.compact ? 6.0 : 8.0;
              final width = (constraints.maxWidth - 2 * gap) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(width: width,
                    child: _AppearanceOption(
                      label: 'sistema',
                      icon: AppIcons.systemTheme,
                      selected: selected == ThemeMode.system,
                      onTap: () => onSelected(ThemeMode.system))),
                  SizedBox(width: width,
                    child: _AppearanceOption(
                      label: 'claro',
                      icon: AppIcons.lightTheme,
                      selected: selected == ThemeMode.light,
                      onTap: () => onSelected(ThemeMode.light))),
                  SizedBox(width: width,
                    child: _AppearanceOption(
                      label: 'escuro',
                      icon: AppIcons.darkTheme,
                      selected: selected == ThemeMode.dark,
                      onTap: () => onSelected(ThemeMode.dark))),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Text('Paleta de cores',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Toque em uma combinação para aplicar imediatamente.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: FolegoColorTokens.of(context).textoSecundario)),
        const SizedBox(height: 12),
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
    final brightness = Theme.of(context).brightness;
    final current = FolegoColorTokens.of(context);
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
                child: Builder(builder: (context) {
                  final colors = FolegoColorTokens.fromId(palette.id, brightness);
                  final active = selected == palette.id;
                  return Semantics(
                    button: true,
                    selected: active,
                    label: 'Tema ${palette.name}: ${palette.description}',
                    child: Material(
                      color: colors.superficie,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      child: InkWell(
                        key: ValueKey('theme-palette-${palette.id}'),
                        onTap: () => onSelected(palette.id),
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 116),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.control),
                            border: Border.all(
                              color: active ? current.marca : colors.borda,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: _PaletteSwatch(colors.fundo)),
                                const SizedBox(width: 3),
                                Expanded(child: _PaletteSwatch(colors.superficieAlta)),
                                const SizedBox(width: 3),
                                Expanded(child: _PaletteSwatch(colors.marca)),
                                const SizedBox(width: 3),
                                Expanded(child: _PaletteSwatch(colors.acao)),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: Text(palette.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: colors.textoPrincipal,
                                    fontWeight: FontWeight.w800))),
                                if (active) Icon(Icons.check_circle_rounded,
                                  color: colors.marca, size: 17),
                              ]),
                              const SizedBox(height: 2),
                              Text(palette.description,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.textoSecundario, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ],
        );
      },
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: 25,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(5),
    ),
  );
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
