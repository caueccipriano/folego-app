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

    final glassBase = isDark
        ? const Color(0xFF15151B).withValues(alpha: .38)
        : Colors.white.withValues(alpha: .56);
    final glassLower = isDark
        ? const Color(0xFF101014).withValues(alpha: .28)
        : const Color(0xFFF7F7FA).withValues(alpha: .42);
    final highlight = Colors.white.withValues(alpha: isDark ? .16 : .72);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 9),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(
            height: 78,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        highlight,
                        glassBase,
                        glassLower,
                      ],
                      stops: const [0, .28, 1],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? .20 : .68,
                      ),
                      width: .85,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? .26 : .09,
                        ),
                        blurRadius: 34,
                        spreadRadius: -9,
                        offset: const Offset(0, 12),
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
                                  alpha: isDark ? .38 : .90,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 26,
                        right: 26,
                        bottom: 0,
                        child: Container(
                          height: .6,
                          color: Colors.black.withValues(
                            alpha: isDark ? .20 : .05,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(items.length, (index) {
                            return Expanded(
                              child: _Destination(
                                item: items[index],
                                selected: selectedIndex == index,
                                onTap: () => onDestinationSelected(index),
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
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

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

    final selectedTop = Colors.white.withValues(alpha: isDark ? .13 : .60);
    final selectedBottom = activePurple.withValues(alpha: isDark ? .13 : .11);

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
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [selectedTop, selectedBottom],
                      )
                    : null,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(
                          alpha: isDark ? .16 : .66,
                        )
                      : Colors.transparent,
                  width: .8,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? .18 : .05,
                          ),
                          blurRadius: 16,
                          spreadRadius: -8,
                          offset: const Offset(0, 7),
                        ),
                        BoxShadow(
                          color: activePurple.withValues(
                            alpha: isDark ? .10 : .08,
                          ),
                          blurRadius: 18,
                          spreadRadius: -10,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 230),
                    curve: Curves.easeOutCubic,
                    width: selected ? 38 : 34,
                    height: 31,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(
                              alpha: isDark ? .07 : .30,
                            )
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      item.icon,
                      size: selected ? 22 : 21,
                      color: selected ? activePurple : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      style: AppTypography.label(
                        context,
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? activeForeground : inactiveColor,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 230),
                    width: selected ? 4 : 0,
                    height: selected ? 4 : 0,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: activePurple.withValues(alpha: .92),
                      shape: BoxShape.circle,
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
