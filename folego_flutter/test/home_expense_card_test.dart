import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/home_expense_summary.dart';
import 'package:folego/features/home/home_expense_card.dart';

void main() {
  testWidgets('mostra estado sem gastos sem desenhar donut vazio', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeExpenseCard(
            breakdown: HomeExpenseBreakdown(total: 0, categories: []),
            unavailable: false,
          ),
        ),
      ),
    );

    expect(find.text('sem gastos neste período'), findsOneWidget);
    expect(find.text('no mês'), findsNothing);
  });

  testWidgets('mostra legenda textual do donut em dark mode', (tester) async {
    const breakdown = HomeExpenseBreakdown(
      total: 100,
      categories: [
        HomeCategoryExpense(category: 'Alimentação', amount: 60, share: .6),
        HomeCategoryExpense(category: 'Compras', amount: 40, share: .4),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: HomeExpenseCard(
            breakdown: breakdown,
            unavailable: false,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('alimentação'), findsOneWidget);
    expect(find.text('60% dos gastos'), findsOneWidget);
    expect(find.text('compras'), findsOneWidget);
    expect(find.text('40% dos gastos'), findsOneWidget);
  });
}
