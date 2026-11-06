import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/folego_motion.dart';

/// Consistent, palette-aware header for Movimentos, Planejar, Carteira,
/// Metas, Diário and Perfil. Pure UI; never reads or mutates financial data.
class SignatureFeatureHero extends StatelessWidget {
  const SignatureFeatureHero({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String eyebrow;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = FolegoColorTokens.of(context);
    final minimal = AppColorSelection.selected.value == 'ink';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return AnimatedContainer(
      key: const ValueKey('signature-feature-hero'),
      duration: FolegoMotion.duration(context, milliseconds: 240),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.superficie,
        gradient: minimal || highContrast
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    colors.marca.withValues(alpha: dark ? .14 : .075),
                    colors.superficie,
                  ),
                  Color.alphaBlend(
                    colors.superficieAlta.withValues(alpha: dark ? .23 : .36),
                    colors.superficie,
                  ),
                  colors.superficie,
                ],
              ),
        borderRadius: BorderRadius.circular(minimal ? 18 : 24),
        border: Border.all(color: colors.borda,
          width: highContrast ? 1.4 : 1),
        boxShadow: highContrast || minimal ? null : [
          BoxShadow(
            color: colors.textoPrincipal.withValues(alpha: dark ? .13 : .05),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, compact ? 15 : 20, 16,
          compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.marca.withValues(alpha: dark ? .16 : .09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: colors.marca, size: 18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    eyebrow.toUpperCase(),
                    maxLines: textScale > 1.5 ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      context, fontSize: 10, fontWeight: FontWeight.w800,
                      color: colors.marca,
                    ).copyWith(letterSpacing: 1.1),
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: compact ? 9 : 12),
            Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(context,
                  fontSize: compact ? 24 : 28,
                  color: colors.textoPrincipal),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: textScale > 1.5 ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(context,
                fontSize: compact ? 12 : 13,
                color: colors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}
