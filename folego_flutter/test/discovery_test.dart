import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/features/discovery/demo_ledger.dart';
import 'package:folego/features/discovery/demo_screen.dart';
import 'package:folego/features/discovery/discovery_model.dart';
import 'package:folego/features/discovery/discovery_screen.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });
  tearDown(() => FinancialPrivacy.hidden.value = false);
  const market = DiscoveryEntry(
    id: '1',
    kind: DiscoveryKind.transaction,
    title: 'Mercado São João',
    subtitle: 'Alimentação · Conta diária',
    amount: 45.50,
  );
  test(
    'search matches accented multi-word terms across sources and filters',
    () {
      expect(searchDiscovery([market], 'sao alimentacao'), [market]);
      expect(searchDiscovery([market], 'DIARIA mercado'), [market]);
      expect(searchDiscovery([market], 'internet'), isEmpty);
      expect(searchDiscovery([market], '', kind: DiscoveryKind.card), isEmpty);
    },
  );
  test(
    'priority keeps overdue first and deduplicates only the same source',
    () {
      final overdue = DiscoveryEntry(
        id: '1',
        kind: DiscoveryKind.scheduled,
        title: 'aluguel',
        subtitle: 'vencido',
        priority: 0,
        date: DateTime(2026, 10, 14),
      );
      final data = prioritizeDiscovery([market, overdue, overdue]);
      expect(data, [overdue, market]);
    },
  );
  test(
    'demo expenses and completion stay local and reset deterministically',
    () {
      final ledger = DemoLedger(today: DateTime(2026, 10, 15));
      ledger.addExpense('livro', 25);
      expect(ledger.balance, 2425);
      expect(searchDiscovery(ledger.data.entries, 'livro').single.amount, -25);
      ledger.complete(ledger.pending.first);
      expect(ledger.pending.length, 2);
      ledger.reset();
      expect(ledger.balance, 2450);
      expect(ledger.pending.length, 3);
      expect(searchDiscovery(ledger.data.entries, 'livro'), isEmpty);
      expect(() => ledger.addExpense('', 25), throwsArgumentError);
      expect(() => ledger.addExpense('x', double.nan), throwsArgumentError);
      expect(DemoLedger().balance, 2450);
    },
  );
  for (final width in [320.0, 768.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('discovery works at $width $brightness and masks money', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: DiscoveryScreen(
              identity: 'one',
              load: () async => const DiscoveryData(
                entries: [market],
                unavailable: ['agenda'],
              ),
              onOpen: (_) async {
                opened = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('consulta incompleta'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'sao');
        await tester.pump();
        expect(find.text(market.title), findsOneWidget);
        FinancialPrivacy.hidden.value = true;
        await tester.pump();
        expect(find.text('R\$ ••••'), findsOneWidget);
        await tester.tap(find.text(market.title));
        await tester.pumpAndSettle();
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('space switch rejects delayed results from previous space', (
    tester,
  ) async {
    final first = Completer<DiscoveryData>();
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoveryScreen(
          identity: 'old',
          load: () => first.future,
          onOpen: (_) async {},
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoveryScreen(
          identity: 'new',
          load: () async => const DiscoveryData(),
          onOpen: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    first.complete(const DiscoveryData(entries: [market]));
    await tester.pumpAndSettle();
    expect(find.text(market.title), findsNothing);
  });
  testWidgets('failed read has retry and does not claim no pending items', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoveryScreen(
          identity: 'one',
          pendingOnly: true,
          load: () async => throw StateError('unavailable'),
          onOpen: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('tentar novamente'), findsOneWidget);
    expect(find.textContaining('Nenhuma pendência encontrada'), findsNothing);
  });
  testWidgets('demo supports simulated expense, theme switch and exit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: DemoScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular gasto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'livro');
    await tester.enterText(find.byType(TextFormField).at(1), '25,00');
    await tester.tap(find.widgetWithText(FilledButton, 'simular gasto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2.425,00'), findsOneWidget);
    await tester.tap(find.byTooltip('testar modo escuro'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('testar modo claro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
