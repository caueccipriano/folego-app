import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_typography.dart';

/// Prominent, palette-aware identity for each real bottom-navigation tab.
/// Financial values and commands remain in their existing widgets. This
/// decoration never intercepts iOS PWA touches or performs data operations.
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
    final foreground = colors.marcaHeroSobre;
    final highContrast = MediaQuery.highContrastOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final vertical = compact ? 15.0 : 20.0;
    final titleSize = compact ? 23.0 : 27.0;

    return Container(
      key: const ValueKey('signature-feature-hero'),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.marcaHero,
        borderRadius: BorderRadius.circular(compact ? 23 : 28),
        border: Border.all(
          color: foreground.withValues(alpha: highContrast ? .70 : .18),
          width: highContrast ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (!highContrast) ...[
            Positioned(
              right: -62,
              top: -93,
              child: IgnorePointer(
                child: Container(
                  width: 206,
                  height: 206,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: foreground.withValues(alpha: .13),
                      width: 31,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 60,
              bottom: -115,
              child: IgnorePointer(
                child: Container(
                  width: 185,
                  height: 185,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: foreground.withValues(alpha: .075),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(19, vertical, 16, vertical),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, color: foreground, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eyebrow.toUpperCase(),
                        maxLines: textScale > 1.5 ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(
                          context,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ).copyWith(letterSpacing: 1.3),
                      ),
                    ),
                    if (trailing != null)
                      Flexible(
                        flex: 0,
                        child: trailing!,
                      )
                    else
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: foreground.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: foreground.withValues(alpha: .24),
                          ),
                        ),
                        child: Icon(
                          Icons.north_east_rounded,
                          size: 17,
                          color: foreground,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 6 : 11),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(
                      context,
                      fontSize: titleSize,
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: textScale > 1.5 ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    context,
                    fontSize: compact ? 11 : 12,
                    color: foreground.withValues(alpha: .94),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
