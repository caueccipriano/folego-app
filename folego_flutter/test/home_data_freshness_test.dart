import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego_flutter/features/home/home_data_freshness.dart';

void main() {
  test('the app never claims a Google Sheets sync from a snapshot read', () {
    final text = homeDataFreshnessLabel(
      DateTime(2026, 10, 13, 17, 45),
      failed: false,
    );
    expect(text, contains('Fôlego consultado às'));
    expect(text, isNot(contains('planilha sincronizada')));
  });

  test('a failed refresh keeps the previous-data warning explicit', () {
    expect(
      homeDataFreshnessLabel(DateTime(2026, 10, 13, 17), failed: true),
      contains('dados anteriores'),
    );
    expect(
      homeDataFreshnessLabel(null, failed: true),
      contains('não foi possível'),
    );
  });

  testWidgets('refresh action is available after a failed update', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeDataFreshness(
          lastLoadedAt: DateTime(2026, 10, 13),
          failed: true,
          loading: false,
          onRefresh: () => calls++,
        ),
      ),
    ));
    await tester.tap(find.text('tentar novamente'));
    expect(calls, 1);
  });
}
