import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/features/wallet/balance_comparison.dart';
import 'package:folego/features/plan/monthly_category_donut.dart';

void main() {
  test(
    'bank comparison accepts BRL, negatives and zero; rejects malformed input',
    () {
      expect(balanceInputCents('R\$ 1.234,56'), 123456);
      expect(balanceInputCents('-15,50'), -1550);
      expect(balanceInputCents('0'), 0);
      for (final invalid in ['', 'abc', '1,234', '1.23', 'NaN', '1e3']) {
        expect(balanceInputCents(invalid), isNull, reason: invalid);
      }
    },
  );

  test(
    'donut hit testing excludes center and outside and matches quadrants',
    () {
      const amounts = [25.0, 75.0];
      expect(monthlyCategoryHit(const Offset(187, 100), 200, amounts), 1);
      expect(monthlyCategoryHit(const Offset(100, 13), 200, amounts), 0);
      expect(monthlyCategoryHit(const Offset(13, 100), 200, amounts), 1);
      expect(monthlyCategoryHit(const Offset(100, 100), 200, amounts), isNull);
      expect(monthlyCategoryHit(Offset.zero, 200, amounts), isNull);
      expect(monthlyCategoryHit(const Offset(100, 13), 200, []), isNull);
    },
  );

  testWidgets(
    'comparison reports exact cents, reacts to changed ledger and hides input',
    (tester) async {
      FinancialPrivacy.hidden.value = false;
      addTearDown(() => FinancialPrivacy.hidden.value = false);
      Future<void> render(num balance) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BalanceComparison(balance: balance),
            ),
          ),
        ),
      );
      await render(634.20);
      await tester.tap(find.text('conferir com o banco'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '635,00');
      await tester.pump();
      expect(find.textContaining('0,80'), findsOneWidget);
      await render(635);
      await tester.pumpAndSettle();
      expect(
        find.text('os valores coincidem nesta comparação.'),
        findsOneWidget,
      );
      FinancialPrivacy.hidden.value = true;
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      expect(find.textContaining('635,00'), findsNothing);
    },
  );
}
