import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/home_budget_overview_panel.dart';

class _OverviewRepository implements FolegoRepository {
  const _OverviewRepository();
  @override
  Future<WalletOverview> getWalletOverview({required String spaceId}) async =>
      const WalletOverview(
        summary: WalletSummary(
          totalCash: 1500,
          availableCash: 1500,
          totalCardInvoice: 600,
          totalDebtRemaining: 400,
        ),
        accounts: [
          WalletAccount(
            id: 'account-1',
            name: 'Conta do dia a dia',
            type: 'checking',
            availableForSpending: true,
            balance: 1500,
          ),
        ],
        cards: [],
        debts: [],
        installments: [],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FolegoSnapshot _snapshot() => FolegoSnapshot(
  asOfDate: DateTime(2026, 11, 5),
  nextIncomeDate: DateTime(2026, 11, 30),
  nextIncomeAmount: 6000,
  daysUntilIncome: 25,
  liquidBalance: 2000,
  protectedBalance: 500,
  mandatoryOutflowsUntilIncome: 1200,
  cashHeadroom: 2300,
  monthlyBudgetPlanned: 3000,
  monthlyBudgetUsed: 900,
  economicHeadroom: 1600,
  spendablePool: 1600,
  dailyFolego: 64,
  shortfall: 0,
  limitingFactor: 'budget',
  status: 'ok',
  budgetConfigured: true,
  needsIncomeSetup: false,
);

void main() {
  setUpAll(() async {
    if (Platform.environment['FOLEGO_VISUAL_CAPTURE'] != '1') return;
    final manrope = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'));
    final unbounded = FontLoader('Unbounded')
      ..addFont(rootBundle.load('assets/fonts/Unbounded-Bold.ttf'));
    await Future.wait([manrope.load(), unbounded.load()]);
  });

  for (final width in [320.0, 390.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'overview is readable and actionable at width $width in $brightness',
        (tester) async {
          tester.view.physicalSize = Size(width, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          var expenses = 0;
          var income = 0;
          var budget = 0;
          var accounts = 0;
          await tester.pumpWidget(MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark() : AppTheme.light(),
            home: Scaffold(body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: HomeBudgetOverviewPanel(
                  repository: const _OverviewRepository(),
                  spaceId: 'demo',
                  snapshot: _snapshot(),
                  hidden: false,
                  onExpense: () => expenses++,
                  onIncome: () => income++,
                  onBudget: () => budget++,
                  onAccounts: () => accounts++,
                ),
              ),
            )),
          ));
          await tester.pumpAndSettle();
          expect(find.text('visão geral'), findsOneWidget);
          expect(find.text('orçamentos'), findsOneWidget);
          expect(find.text('Conta do dia a dia'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (Platform.environment['FOLEGO_VISUAL_CAPTURE'] == '1') {
            await expectLater(
              find.byType(Scaffold),
              matchesGoldenFile(
                'goldens/budget-flow-overview-${width.toInt()}-${brightness.name}.png',
              ),
            );
          }

          await tester.ensureVisible(
              find.byKey(const ValueKey('budget-flow-register-expense')));
          await tester.tap(
              find.byKey(const ValueKey('budget-flow-register-expense')));
          await tester.tap(
              find.byKey(const ValueKey('budget-flow-register-income')));
          await tester.tap(
              find.byKey(const ValueKey('budget-flow-open-budget')));
          expect(expenses, 1);
          expect(income, 1);
          expect(budget, 1);

          await tester.ensureVisible(find.text('Conta do dia a dia'));
          await tester.tap(find.text('Conta do dia a dia'));
          expect(accounts, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('privacy hides financial amounts but preserves navigation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(
        child: HomeBudgetOverviewPanel(
          repository: const _OverviewRepository(),
          spaceId: 'demo',
          snapshot: _snapshot(),
          hidden: true,
          onExpense: () {},
          onIncome: () {},
          onBudget: () {},
        ),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('••••'), findsWidgets);
    expect(find.textContaining('1.600'), findsNothing);
    expect(find.textContaining('1.500'), findsNothing);
    expect(find.text('visão geral'), findsOneWidget);
  });
}
