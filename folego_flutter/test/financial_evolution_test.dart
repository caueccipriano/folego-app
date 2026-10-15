import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:folego/data/models/projection_model.dart';
import 'package:folego/data/models/wallet_detail.dart';
import 'package:folego/features/plan/purchase_comparison.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });
  List<PurchaseOption> options() => buildPurchaseOptions(
    name: 'Notebook',
    cashCents: 90001,
    installmentCents: 100003,
    payments: 3,
    firstPayment: DateTime(2027, 1, 31),
  );
  test(
    'comparison preserves each price, cent remainder and delayed month end',
    () {
      final rows = options();
      expect(rows.length, 3);
      expect(rows[0].totalCents, 90001);
      expect(rows[1].totalCents, 100003);
      expect(rows[2].adjustments.first.startsOn, DateTime(2027, 2, 28));
      expect(rows[0].adjustments.first.amountDelta, 900.01);
      expect(
        rows[1].adjustments.fold<int>(
          0,
          (sum, a) =>
              sum +
              (a.amountDelta * 100).round() *
                  (a.frequency == 'monthly' ? 3 : 1),
        ),
        100003,
      );
    },
  );
  test('paid counts use actual settled invoices even when order has gaps', () {
    final item = WalletInstallmentPosition.fromPurchaseJson({
      'id': 'purchase',
      'description': 'item',
      'installments_count': 3,
      'card': {'id': 'card', 'name': 'Card'},
      'card_installments': [
        {
          'installment_number': 1,
          'amount': 100,
          'status': 'open',
          'invoice': {'status': 'open', 'due_date': '2026-10-20'},
        },
        {
          'installment_number': 2,
          'amount': 100,
          'status': 'open',
          'invoice': {'status': 'paid', 'due_date': '2026-11-20'},
        },
        {
          'installment_number': 3,
          'amount': 100,
          'status': 'open',
          'invoice': {'status': 'open', 'due_date': '2026-12-20'},
        },
      ],
    });
    expect(item.paidCount, 1);
    expect(item.remainingCount, 2);
    expect(item.outstandingAmount, 200);
    expect(item.progress, closeTo(1 / 3, .001));
  });
  final result = ProjectionResult.fromJson({
    'as_of_date': '2026-10-15',
    'horizon_months': 12,
    'summary': {'minimum_balance': 1000, 'ending_balance': 1500},
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'comparison at $width $brightness chooses simulation without writes',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          List<ProjectionAdjustment>? chosen;
          var reads = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      chosen = await showDialog<List<ProjectionAdjustment>>(
                        context: context,
                        builder: (_) => PurchaseComparisonDialog(
                          options: options(),
                          load: (changes) async {
                            reads++;
                            return result;
                          },
                          horizonMonths: 12,
                        ),
                      );
                    },
                    child: const Text('compare'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('compare'));
          await tester.pumpAndSettle();
          expect(reads, 4);
          expect(find.text('à vista agora'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('usar este cenário').first);
          await tester.tap(find.text('usar este cenário').first);
          await tester.pumpAndSettle();
          expect(chosen!.first.amountDelta, 900.01);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
