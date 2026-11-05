import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/features/home/quick_amount_calculator.dart';

void main() {
  test('currency calculator respects precedence and Brazilian decimal comma', () {
    expect(BudgetAmountMath.evaluate('10+5'), 15);
    expect(BudgetAmountMath.evaluate('10,50+2,50'), 13);
    expect(BudgetAmountMath.evaluate('2+3×4'), 14);
    expect(BudgetAmountMath.evaluate('18÷3+1'), 7);
    expect(BudgetAmountMath.evaluate('5−3'), 2);
    expect(BudgetAmountMath.evaluate('10/0'), isNull);
    expect(BudgetAmountMath.evaluate('0'), isNull);
    expect(BudgetAmountMath.evaluate('3−5'), isNull);
    expect(BudgetAmountMath.evaluate('1000000000'), isNull);
    expect(BudgetAmountMath.evaluate('2+'), isNull);
  });

  testWidgets('calculator only returns amount after explicit Apply',
      (tester) async {
    FinancialPrivacy.hidden.value = false;
    addTearDown(() => FinancialPrivacy.hidden.value = false);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    num? confirmed;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await showModalBottomSheet<num>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const QuickAmountCalculator(),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(confirmed, isNull);
    for (final key in ['2', '+', '3', '×', '4']) {
      await tester.tap(find.byKey(ValueKey('budget-calculator-key-$key')));
      await tester.pump();
    }
    expect(find.textContaining('14,00'), findsOneWidget);
    expect(confirmed, isNull);

    await tester.tap(find.byKey(const ValueKey('budget-calculator-key-OK')));
    await tester.pumpAndSettle();
    expect(confirmed, 14);
  });
}
