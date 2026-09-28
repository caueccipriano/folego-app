import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:folego/core/intelligence/cash_runway.dart';
import 'package:folego/core/intelligence/cash_runway_preparation.dart';
import 'package:folego/widgets/runway_what_if_card.dart';

CashRunwayPreparation preparation({bool needsReview = false}) {
  final runway = CashRunway.calculate(
    asOf: DateTime(2026, 9, 28),
    nextPayday: DateTime(2026, 10, 1),
    verifiedOpeningBalance: 500,
    confirmedEvents: [
      DatedCashEvent(date: DateTime(2026, 9, 30),
          amount: -100, label: 'Scheduled bill'),
    ],
  );
  return CashRunwayPreparation(
    runway: runway,
    nextIncomeDate: DateTime(2026, 10, 1),
    excludedOverdueCount: needsReview ? 1 : 0,
    openingBalance: 500,
  );
}

void main() {
  testWidgets('invalid amount hides stale simulation balance', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SingleChildScrollView(
        child: RunwayWhatIfCard(preparation: preparation()),
      )),
    ));
    await tester.tap(find.text('Simule uma compra ou um aporte'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo antes da próxima entrada após a simulação'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(find.text('Informe um valor entre 0 e 1.000.000'),
        findsOneWidget);
    expect(find.text('Saldo antes da próxima entrada após a simulação'),
        findsNothing);
    await tester.enterText(find.byType(TextField), '120');
    await tester.pump();
    expect(find.text('Saldo antes da próxima entrada após a simulação'),
        findsOneWidget);
  });

  testWidgets('provisional scenario is visibly labeled', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SingleChildScrollView(
        child: RunwayWhatIfCard(
          preparation: preparation(needsReview: true),
        ),
      )),
    ));
    await tester.tap(find.text('Simule uma compra ou um aporte'));
    await tester.pumpAndSettle();
    expect(find.textContaining('simulação provisória'), findsOneWidget);
    expect(find.text('Saldo simulado provisório antes da próxima entrada'),
        findsOneWidget);
  });
}
