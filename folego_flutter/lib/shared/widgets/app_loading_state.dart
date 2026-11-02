import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';

/// Read-only loading state shared by the main screens.
/// Skeleton bars are decorative and never represent real balances or entries.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.label = 'organizando seus dados',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final primary = AppColors.primaryText(brightness);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Short sections, including inline wallet details, must not overflow.
        final condensed = compact ||
            (constraints.hasBoundedHeight && constraints.maxHeight < 210);
        return Semantics(
          liveRegion: true,
          label: label,
          child: ExcludeSemantics(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: condensed ? 12 : 16,
                  vertical: condensed ? 12 : 22,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: condensed
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(label,
                                style: AppTypography.body(context,
                                  fontSize: 12, color: secondary)),
                            ),
                          ],
                        )
                      : Container(
                          key: const ValueKey('folego-loading-skeleton'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surface(brightness),
                            borderRadius:
                                BorderRadius.circular(AppRadii.feature),
                            border: Border.all(
                              color: AppColors.border(brightness)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(label,
                                    style: AppTypography.cardTitle(context,
                                      fontSize: 13, color: primary)),
                                ),
                              ]),
                              const SizedBox(height: 18),
                              const _LoadingBar(widthFactor: .72),
                              const SizedBox(height: 10),
                              const _LoadingBar(widthFactor: 1),
                              const SizedBox(height: 10),
                              const _LoadingBar(widthFactor: .46),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A restrained static placeholder: no shimmer, fake data, or layout shift.
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.widthFactor});
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: AppColors.background(brightness),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.border(brightness)
              .withValues(alpha: .5)),
        ),
      ),
    );
  }
}
