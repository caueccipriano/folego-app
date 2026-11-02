import 'package:flutter/material.dart';

/// A single policy for optional polish animations.
///
/// Do not animate when the device requests reduced motion. Meaningful
/// values and actions must remain visible without any transition.
abstract final class FolegoMotion {
  static bool enabled(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations != true &&
        media?.accessibleNavigation != true;
  }

  static Duration duration(
    BuildContext context, {
    int milliseconds = 260,
  }) => enabled(context)
      ? Duration(milliseconds: milliseconds)
      : Duration.zero;
}
