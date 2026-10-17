import 'package:flutter/widgets.dart';

class HomeExpenseNavigationScope extends InheritedWidget {
  const HomeExpenseNavigationScope({
    super.key,
    required this.onOpenExpenses,
    this.onOpenMonthlyTransactions,
    required super.child,
  });

  final void Function(String? categoryId) onOpenExpenses;
  final void Function(DateTime periodMonth, Set<String> eventTypes)?
      onOpenMonthlyTransactions;

  static HomeExpenseNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeExpenseNavigationScope>();
  }

  @override
  bool updateShouldNotify(covariant HomeExpenseNavigationScope oldWidget) {
    return oldWidget.onOpenExpenses != onOpenExpenses ||
        oldWidget.onOpenMonthlyTransactions != onOpenMonthlyTransactions;
  }
}
