import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
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
      _NavItem(icon: AppIcons.home, label: l10n.home.toLowerCase()),
      _NavItem(
        icon: AppIcons.transactions,
        label: l10n.transactions.toLowerCase(),
      ),
      _NavItem(icon: AppIcons.plan, label: l10n.plan.toLowerCase()),
      _NavItem(icon: AppIcons.wallet, label: l10n.wallet.toLowerCase()),
      _NavItem(icon: AppIcons.profile, label: l10n.profile.toLowerCase()),
    ];

    final tokens = FolegoColorTokens.of(context);
    final surface = tokens.superficie;
    final highlight = tokens.superficieAlta.withValues(alpha: isDark ? .42 : .72);
    final lower = surface.withValues(alpha: isDark ? .98 : .94);
    final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final navigationHeight = 64.0 + 16.0 * (textScale.clamp(1.0, 2.0) - 1.0);

    return SafeArea(
      key: const ValueKey('mobile-liquid-nav'),
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 5),
      child: SizedBox(
        height: navigationHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  width: double.infinity,
                  height: navigationHeight,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [highlight, surface, lower],
                      stops: const [0, .30, 1],
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.navigation),
                    border: Border.all(
                      color: AppColors.border(theme.brightness),
                      width: .85,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.textoPrincipal.withValues(alpha: isDark ? .24 : .09),
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
              color: selected
                  ? activePurple.withValues(alpha: isDark ? .14 : .10)
                  : AppColors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.feature),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 24,
                  child: Center(
                    child: Icon(
                      item.icon,
                      size: selected ? 21 : 20,
                      color: selected ? activePurple : inactiveColor,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: AppTypography.label(
                      context,
                      fontSize: 11,
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
