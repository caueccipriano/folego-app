import 'package:flutter/widgets.dart';

class FlexibleBudgetNavigationScope extends InheritedWidget {
  const FlexibleBudgetNavigationScope({
    super.key,
    required this.onOpen,
    required super.child,
  });

  final VoidCallback onOpen;

  static FlexibleBudgetNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FlexibleBudgetNavigationScope>();
  }

  void open() => onOpen();

  @override
  bool updateShouldNotify(FlexibleBudgetNavigationScope oldWidget) {
    return oldWidget.onOpen != onOpen;
  }
}
