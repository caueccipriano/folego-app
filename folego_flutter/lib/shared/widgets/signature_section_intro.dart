import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_typography.dart';
import 'folego_glass_surface.dart';

/// Signature editorial identity shared by the app's secondary destinations.
///
/// No financial calculations, network calls, auth logic or touch interception.
/// The existing page heading and actions remain accessible immediately below.
class SignatureSectionIntro extends StatelessWidget {
  const SignatureSectionIntro({
    super.key,
    required this.eyebrow,
    required this.caption,
    required this.icon,
  });

  final String eyebrow;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final markBackground = Color.alphaBlend(
      tokens.marca.withValues(alpha: dark ? .21 : .11),
      tokens.superficie,
    );

    return FolegoGlassSurface(
      key: const ValueKey('signature-section-intro'),
      radius: 21,
      prominent: false,
      elevated: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: markBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: tokens.marca.withValues(alpha: .22),
              ),
            ),
            child: Icon(icon, size: 20, color: tokens.marca),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  maxLines: scale > 1.5 ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: tokens.marca,
                  ).copyWith(letterSpacing: 1.12),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  maxLines: scale > 1.5 ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    color: tokens.textoSecundario,
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


/// Compact identifier for banking sheets. No automatic financial side effects.
class SignatureSheetEyebrow extends StatelessWidget {
  const SignatureSheetEyebrow({
    super.key,
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = FolegoColorTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('signature-sheet-eyebrow'),
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.marca.withValues(alpha: dark ? .16 : .085),
          colors.superficie,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.marca.withValues(alpha: .20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.marca),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                context,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: colors.marca,
              ).copyWith(letterSpacing: .85),
            ),
          ),
        ],
      ),
    );
  }
}
