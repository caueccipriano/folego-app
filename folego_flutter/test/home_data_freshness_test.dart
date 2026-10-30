import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/home/home_data_freshness.dart';

void main() {
  test('the app never claims a Google Sheets sync from a snapshot read', () {
    final text = homeDataFreshnessLabel(
      DateTime(2026, 10, 13, 17, 45),
      failed: false,
    );
    expect(text, contains('atualizado às'));
    expect(text, isNot(contains('parciais')));
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

  test('partial data never claims everything is current', () {
    final date = DateTime(2026, 10, 13, 17, 45);
    expect(homeDataFreshnessLabel(date, failed: false, partial: true),
      'dados parciais · 17:45');
    expect(homeDataFreshnessLabel(null, failed: false, partial: true),
      'parte do resumo indisponível');
    expect(homeDataFreshnessLabel(date, failed: true, partial: true),
      contains('atualização falhou'));
  });

  testWidgets('partial status exposes affected sections without another alert',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeDataFreshness(
          lastLoadedAt: DateTime(2026, 10, 13, 17, 45),
          failed: false,
          loading: false,
          sourceFailures: const ['projeção', 'agenda'],
          onRefresh: () {},
        ),
      ),
    ));
    expect(find.textContaining('dados parciais'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('fontes e atualização'));
    await tester.pumpAndSettle();
    expect(find.textContaining('projeção, agenda'), findsOneWidget);
    expect(find.text('tentar novamente'), findsNothing);
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
