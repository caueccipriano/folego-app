import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';

/// Mobile navigation with a glass-like visual treatment.
///
/// Important: this intentionally does not use BackdropFilter. On iOS PWAs the
/// real backdrop blur introduced an extra compositing layer around the
/// bottomNavigationBar and made visual and pointer geometry diverge. The
/// gradient below keeps the same visual language without changing hit testing.
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
    final highlight = Colors.white.withValues(alpha: isDark ? .08 : .72);
    final lower = surface.withValues(alpha: isDark ? .98 : .94);

    return SafeArea(
      key: const ValueKey('mobile-liquid-nav'),
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 9),
      child: SizedBox(
        height: 78,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  width: double.infinity,
                  height: 78,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [highlight, surface, lower],
                      stops: const [0, .30, 1],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: .14)
                          : Colors.white.withValues(alpha: .78),
                      width: .85,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? .24 : .09,
                        ),
                        blurRadius: 28,
                        spreadRadius: -9,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(items.length, (index) {
                      return Expanded(
                        child: _Destination(
                          key: ValueKey('mobile-nav-destination-$index'),
                          item: items[index],
                          selected: selectedIndex == index,
                          onTap: () => onDestinationSelected(index),
                        ),
                      );
                    }),
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
    final activePurple = isDark ? AppColors.purpleDark : AppColors.purpleLight;
    final inactiveColor = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final activeForeground = isDark
        ? AppColors.darkPrimaryText
        : AppColors.lightPrimaryText;

    final selectedTop = Colors.white.withValues(alpha: isDark ? .12 : .64);
    final selectedBottom = activePurple.withValues(alpha: isDark ? .16 : .13);

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
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
                    ? Colors.white.withValues(alpha: isDark ? .14 : .62)
                    : Colors.transparent,
                width: .8,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 38,
                  height: 30,
                  child: Center(
                    child: Icon(
                      item.icon,
                      size: selected ? 22 : 21,
                      color: selected ? activePurple : inactiveColor,
                    ),
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
                  duration: const Duration(milliseconds: 180),
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
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
