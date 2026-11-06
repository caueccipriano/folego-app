import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/folego_motion.dart';
import '../../shared/widgets/folego_glass_surface.dart';

/// Secondary destinations in one calm, two-by-two mobile menu.
/// All actions remain explicit navigation, with no financial writes.
class MoreToolsSheet extends StatelessWidget {
  const MoreToolsSheet({super.key, required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = FolegoColorTokens.of(context);
    final space = MediaQuery.sizeOf(context);
    final pad = space.width < 355 ? 12.0 : 18.0;

    return FolegoGlassSurface(
      radius: 28,
      prominent: false,
      elevated: false,
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 20),
      child: ConstrainedBox(
        // Large accessibility text and short iPhones can scroll the menu
        // without shrinking labels or hiding actions below the home indicator.
        // In embedded tests or hosts MediaQuery can report zero height.
        // Never collapse the whole menu and make its tap targets unreachable.
        constraints: BoxConstraints(
          maxHeight: space.height > 0 ? space.height * .78 : double.infinity,
        ),
        child: SingleChildScrollView(
          key: const ValueKey('tools-scroll-region'),
          physics: const ClampingScrollPhysics(),
          child: Column(
            key: const ValueKey('tools-compact-grid'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 13),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: .34),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TUDO EM UM LUGAR',
                          style: AppTypography.label(
                            context,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: tokens.marca,
                          ).copyWith(letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 3),
                        Text('mais', style: AppTypography.section(context,
                          fontSize: 24, color: tokens.textoPrincipal)),
                        const SizedBox(height: 3),
                        Text('suas ferramentas, sem complicação',
                          style: AppTypography.body(context, fontSize: 13,
                            color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.marca.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: tokens.marca.withValues(alpha: .13),
                      ),
                    ),
                    child: Icon(Icons.dashboard_customize_outlined,
                      color: tokens.marca, size: 21),
                  ),
                ]),
              ),
              LayoutBuilder(builder: (context, limits) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                // On 320px phones, two half-width tiles truncate their
                // captions. At larger text scales use one readable column.
                final oneColumn = limits.maxWidth < 310 || scale >= 1.3;
                final tileWidth = oneColumn
                    ? limits.maxWidth : (limits.maxWidth - 10) / 2;
                return Wrap(
                  key: ValueKey(oneColumn
                      ? 'tools-single-column' : 'tools-two-columns'),
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: tileWidth, child: _ToolTile(
                      tileKey: const ValueKey('tools-wallet'),
                      label: 'contas e cartões',
                      caption: 'faturas e dívidas',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => onSelected(0))),
                    SizedBox(width: tileWidth, child: _ToolTile(
                      tileKey: const ValueKey('tools-goals'),
                      label: 'metas',
                      caption: 'guardar e realizar',
                      icon: Icons.flag_outlined,
                      onTap: () => onSelected(1))),
                    SizedBox(width: tileWidth, child: _ToolTile(
                      tileKey: const ValueKey('tools-diary'),
                      label: 'diário',
                      caption: 'anotações financeiras',
                      icon: Icons.auto_stories_outlined,
                      onTap: () => onSelected(2))),
                    SizedBox(width: tileWidth, child: _ToolTile(
                      tileKey: const ValueKey('tools-profile'),
                      label: 'configurações',
                      caption: 'perfil e automações',
                      icon: Icons.settings_outlined,
                      onTap: () => onSelected(3))),
                  ],
                );
              }),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('tools-financial-ai'),
                onPressed: () => onSelected(4),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: tokens.acao,
                  foregroundColor: tokens.acaoSobre,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_outlined, size: 19),
                label: const Text('perguntar ao Fôlego · IA'),
              ),
              if (const String.fromEnvironment('FOLEGO_RELEASE').isNotEmpty) ...[
                const SizedBox(height: 13),
                Center(
                  child: Semantics(
                    label: 'versão publicada do Fôlego',
                    child: Text(
                      'Fôlego · versão ${const String.fromEnvironment('FOLEGO_RELEASE').substring(0, 8)}',
                      key: const ValueKey('folego-visible-build-version'),
                      style: AppTypography.label(
                        context,
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolTile extends StatefulWidget {
  const _ToolTile({
    required this.tileKey,
    required this.label,
    required this.caption,
    required this.icon,
    required this.onTap,
  });

  final Key tileKey;
  final String label;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    return AnimatedScale(
      key: ValueKey('tool-scale-${widget.label}'),
      scale: _pressed && FolegoMotion.enabled(context) ? .975 : 1,
      duration: FolegoMotion.duration(context, milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: FolegoGlassSurface(
      radius: 20,
      elevated: false,
      child: InkWell(
        key: widget.tileKey,
        onTap: widget.onTap,
        onHighlightChanged: (pressed) {
          if (_pressed != pressed) setState(() => _pressed = pressed);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.fromLTRB(15, 13, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 37, height: 37,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.marca.withValues(alpha: .095),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: tokens.marca.withValues(alpha: .14),
                  ),
                ),
                child: Icon(widget.icon, size: 20, color: tokens.marca),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text(widget.label, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle(context, fontSize: 15,
                      color: tokens.textoPrincipal))),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_outward_rounded,
                    size: 16, color: tokens.marca),
                ],
              ),
              const SizedBox(height: 3),
              Text(widget.caption, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTypography.label(context, fontSize: 12,
                  color: tokens.textoSecundario)),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
