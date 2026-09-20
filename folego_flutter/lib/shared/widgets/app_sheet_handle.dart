import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';

/// Handle visual oficial para bottom sheets do Fôlego.
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final border = AppColors.border(Theme.of(context).brightness);

    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: border,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    );
  }
}
