import 'package:flutter/material.dart';

import '../../data/models/transaction_reflection.dart';
import 'app_colors.dart';
import 'app_icons.dart';

abstract final class ReflectionVisuals {
  static Color foreground(ReflectionType type, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (type) {
      ReflectionType.necessary => dark
          ? AppColors.necessaryDarkText
          : AppColors.necessaryLightText,
      ReflectionType.want => dark
          ? AppColors.desireDarkText
          : AppColors.desireLightText,
      ReflectionType.selfInvestment => AppColors.primaryPurple(brightness),
    };
  }

  static Color background(ReflectionType type, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (type) {
      ReflectionType.necessary => dark
          ? AppColors.necessaryDarkBackground
          : AppColors.necessaryLightBackground,
      ReflectionType.want => dark
          ? AppColors.desireDarkBackground
          : AppColors.desireLightBackground,
      ReflectionType.selfInvestment => AppColors.primaryPurple(
          brightness,
        ).withValues(alpha: dark ? .18 : .10),
    };
  }

  static Color border(ReflectionType type, Brightness brightness) {
    return foreground(type, brightness).withValues(alpha: .35);
  }

  static IconData icon(ReflectionType type) {
    return switch (type) {
      ReflectionType.necessary => AppIcons.check,
      ReflectionType.want => AppIcons.heart,
      ReflectionType.selfInvestment => AppIcons.savingsGoal,
    };
  }
}
