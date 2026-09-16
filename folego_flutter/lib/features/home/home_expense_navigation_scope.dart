import 'package:flutter/widgets.dart';

class HomeExpenseNavigationScope extends InheritedWidget {
  const HomeExpenseNavigationScope({
    super.key,
    required this.onOpenExpenses,
    required super.child,
  });

  final void Function(String? categoryId) onOpenExpenses;

  static HomeExpenseNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeExpenseNavigationScope>();
  }

  @override
  bool updateShouldNotify(covariant HomeExpenseNavigationScope oldWidget) {
    return oldWidget.onOpenExpenses != onOpenExpenses;
  }
}
