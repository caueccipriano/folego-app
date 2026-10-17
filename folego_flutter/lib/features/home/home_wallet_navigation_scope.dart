import 'package:flutter/widgets.dart';

/// Navigation from financial explanations to the existing Wallet sections.
/// Sections: 0 = accounts, 1 = credit cards. No balance logic lives here.
class HomeWalletNavigationScope extends InheritedWidget {
  const HomeWalletNavigationScope({
    super.key,
    required this.onOpenSection,
    required super.child,
  });

  final void Function(int section) onOpenSection;

  static HomeWalletNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeWalletNavigationScope>();
  }

  @override
  bool updateShouldNotify(covariant HomeWalletNavigationScope oldWidget) =>
      oldWidget.onOpenSection != onOpenSection;
}
