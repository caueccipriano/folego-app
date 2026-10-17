import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_icons.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/data/models/financial_goal.dart';
import 'package:folego/features/goals/goals_widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  test('goal icon mapping uses the centralized AppIcons set', () {
    expect(GoalIconVisuals.iconFor(GoalIcon.plane), AppIcons.categoryTravel);
    expect(
      GoalIconVisuals.iconFor(GoalIcon.deviceLaptop),
      AppIcons.shoppingElectronics,
    );
    expect(GoalIconVisuals.iconFor(GoalIcon.car), AppIcons.categoryTransport);
    expect(GoalIconVisuals.iconFor(GoalIcon.home), AppIcons.categoryHousing);
    expect(GoalIconVisuals.iconFor(GoalIcon.gift), AppIcons.categoryGifts);
    expect(GoalIconVisuals.iconFor(GoalIcon.piggyBank), AppIcons.savingsGoal);
  });

  testWidgets('empty state invites the first goal in light theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: GoalEmptyState(onCreate: () {})),
      ),
    );

    expect(find.text('o que você quer tornar possível?'), findsOneWidget);
    expect(find.text('criar primeira meta'), findsOneWidget);
  });

  testWidgets('empty state also renders in dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: GoalEmptyState(onCreate: () {})),
      ),
    );

    expect(find.text('o que você quer tornar possível?'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('goal card shows sem prazo when deadline is optional', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 190,
            child: GoalCard(goal: _goal(), onTap: () {}),
          ),
        ),
      ),
    );

    expect(find.text('sem prazo'), findsOneWidget);
  });

  testWidgets('goal card shows deadline when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 190,
            child: GoalCard(
              goal: _goal(targetDate: DateTime(2027, 1, 31)),
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('até jan/2027'), findsOneWidget);
  });
}

FinancialGoal _goal({DateTime? targetDate}) {
  return FinancialGoal(
    id: 'goal',
    spaceId: 'space',
    name: 'Entrada do carro',
    target: 10000,
    targetDate: targetDate,
    icon: GoalIcon.car,
    status: GoalStatus.active,
    currentAmount: 2400,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
}
