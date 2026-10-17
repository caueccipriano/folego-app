import 'package:flutter/material.dart';

import '../layout/app_breakpoints.dart';

/// Consistent transient feedback across compact and desktop surfaces.
abstract final class AppSnackbars {
  static const double desktopWidth = 400;

  static void show(BuildContext context, String message) {
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: desktop ? SnackBarBehavior.floating : SnackBarBehavior.fixed,
          width: desktop ? desktopWidth : null,
          shape: desktop
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
        ),
      );
  }
}
