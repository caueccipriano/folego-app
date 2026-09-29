import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_typography.dart';

/// Shared Fôlego Home surface: never fall back to Flutter's generic Card
/// silhouette for secondary tools or analytical summaries.
class FolegoHomeSectionCard extends StatelessWidget {
  const FolegoHomeSectionCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: AppColors.surface(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.feature),
        side: BorderSide(color: AppColors.border(brightness)),
      ),
      child: child,
    );
  }
}

/// Use the display typeface for section titles, while keeping dense numeric
/// labels and explanatory copy in the Fôlego interface typeface.
class FolegoHomeSectionTitle extends StatelessWidget {
  const FolegoHomeSectionTitle(this.text, {super.key, this.size = 15});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.section(context, fontSize: size));
}
