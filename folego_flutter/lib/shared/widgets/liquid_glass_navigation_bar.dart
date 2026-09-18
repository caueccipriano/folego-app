import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';

class LiquidGlassNavigationBar extends StatelessWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final items = <_NavItem>[
      _NavItem(icon: AppIcons.home, label: l10n.home),
      const _NavItem(icon: AppIcons.transactions, label: 'lançamentos'),
      _NavItem(icon: AppIcons.plan, label: l10n.plan),
      _NavItem(icon: AppIcons.wallet, label: l10n.wallet),
      _NavItem(icon: AppIcons.profile, label: l10n.profile),
    ];

    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final glassTint = surface.withValues(alpha: isDark ? .62 : .70);
    final glassHighlight = Colors.white.withValues(alpha: isDark ? .10 : .42);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 9),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(
            height: 76,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        glassHighlight,
                        glassTint,
                        glassTint.withValues(alpha: isDark ? .54 : .62),
                      ],
                      stops: const [0, .34, 1],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? .14 : .52,
                      ),
                      width: .8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? .30 : .10,
                        ),
                        blurRadius: 28,
                        spreadRadius: -8,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 18,
                        right: 18,
                        top: 0,
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(
                                  alpha: isDark ? .24 : .68,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          children: List.generate(items.length, (index) {
                            return Expanded(
                              child: _Destination(
                                item: items[index],
                                selected: selectedIndex == index,
                                onTap: () => onDestinationSelected(index),
                                outerBorder: border,
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.outerBorder,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final Color outerBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activePurple = isDark ? AppColors.purpleDark : AppColors.purpleLight;
    final inactiveColor = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final activeForeground = isDark
        ? AppColors.darkPrimaryText
        : AppColors.lightPrimaryText;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(23),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? .13 : .52),
                          activePurple.withValues(alpha: isDark ? .28 : .20),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(23),
                border: selected
                    ? Border.all(
                        color: Colors.white.withValues(
                          alpha: isDark ? .16 : .58,
                        ),
                        width: .8,
                      )
                    : Border.all(color: Colors.transparent, width: .8),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: activePurple.withValues(
                            alpha: isDark ? .22 : .16,
                          ),
                          blurRadius: 18,
                          spreadRadius: -7,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: selected ? activePurple : inactiveColor,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          style: AppTypography.label(
                            context,
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? activeForeground
                                : inactiveColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selected)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 15,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.lime.withValues(alpha: .95),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lime.withValues(alpha: .28),
                              blurRadius: 7,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
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
