import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import 'folego_glass_surface.dart';

/// Frosted mobile dock without BackdropFilter to preserve iOS PWA hit targets.
class LiquidGlassNavigationBar extends StatelessWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onOpenTools,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onOpenTools;

  @override
  Widget build(BuildContext context) {
    // Three everyday destinations; advanced tasks live behind tools.
    final items = <_NavItem>[
      _NavItem(icon: AppIcons.home, label: 'hoje'),
      _NavItem(icon: AppIcons.transactions, label: 'movimentos'),
      _NavItem(icon: AppIcons.plan, label: 'futuro'),
    ];

    final tokens = FolegoColorTokens.of(context);
    // Frosted appearance stays in the same layout region as the touch targets.
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final navigationHeight = 62.0 + 16.0 * (textScale.clamp(1.0, 2.0) - 1.0);

    return SafeArea(
      key: const ValueKey('mobile-liquid-nav'),
      top: false,
      minimum: const EdgeInsets.fromLTRB(15, 8, 15, 8),
      child: SizedBox(
        height: navigationHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  height: navigationHeight,
                  child: FolegoGlassSurface(
                    radius: 27,
                    prominent: true,
                    padding: const EdgeInsets.all(5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...List.generate(items.length, (index) {
                      return Expanded(
                        child: _Destination(
                          key: ValueKey('mobile-nav-destination-$index'),
                          item: items[index],
                          selected: selectedIndex == index,
                          onTap: () => onDestinationSelected(index),
                        ),
                      );
                    }),
                    if (onOpenTools != null)
                      Expanded(
                        child: Semantics(
                          button: true, selected: selectedIndex >= 3,
                          label: 'mais',
                          child: InkWell(
                            key: const ValueKey('mobile-tools-button'),
                            onTap: onOpenTools,
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(21),
                                gradient: selectedIndex >= 3
                                    ? LinearGradient(colors: [
                                        tokens.marca.withValues(alpha: .24),
                                        tokens.marca.withValues(alpha: .11),
                                      ])
                                    : null,
                                border: selectedIndex >= 3
                                    ? Border.all(
                                        color: tokens.marca.withValues(alpha: .34))
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    key: const ValueKey('mobile-tools-indicator'),
                                    duration: MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    width: selectedIndex >= 3 ? 22 : 5,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: selectedIndex >= 3
                                          ? tokens.marca
                                          : AppColors.transparent,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedContainer(
                                    duration: MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    width: 37,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: selectedIndex >= 3
                                          ? tokens.marca.withValues(alpha: .12)
                                          : AppColors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.grid_view_rounded,
                                      size: 21,
                                      color: selectedIndex >= 3
                                          ? tokens.marca
                                          : tokens.textoSecundario,
                                    ),
                                  ),
                                  Text('mais',
                                    style: AppTypography.label(
                                      context,
                                      fontSize: 12,
                                      fontWeight: selectedIndex >= 3
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selectedIndex >= 3
                                          ? tokens.marca
                                          : tokens.textoSecundario,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activePurple = FolegoColorTokens.of(context).marca;
    final inactiveColor = FolegoColorTokens.of(context).textoSecundario;
    final activeForeground = activePurple;
    final motionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          focusColor: activePurple.withValues(alpha: .16),
          hoverColor: activePurple.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(AppRadii.feature),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return activePurple.withValues(alpha: .10);
            }
            return null;
          }),
          child: AnimatedContainer(
            duration: motionDuration,
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        activePurple.withValues(alpha: isDark ? .28 : .22),
                        activePurple.withValues(alpha: isDark ? .14 : .10),
                      ],
                    )
                  : null,
              border: selected
                  ? Border.all(color: activePurple.withValues(alpha: .30),
                      width: .9)
                  : null,
              borderRadius: BorderRadius.circular(21),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: activePurple.withValues(
                          alpha: isDark ? .15 : .09,
                        ),
                        blurRadius: 11,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: motionDuration,
                  width: selected ? 22 : 5,
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? activePurple : AppColors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: motionDuration,
                  width: 37,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected
                        ? activePurple.withValues(alpha: isDark ? .18 : .09)
                        : AppColors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      size: selected ? 21 : 20,
                      color: selected ? activePurple : inactiveColor,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: AppTypography.label(
                      context,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? activeForeground : inactiveColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
