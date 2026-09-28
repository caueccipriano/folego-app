import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/onboarding_state.dart';
import 'package:folego/features/onboarding/setup_checklist.dart';

void main() {
  testWidgets('setup displays real progress and routes first task', (tester) async {
    const state = OnboardingState(
      accountCount: 0, hasAccount: false, hasConfirmedIncome: false,
      recurringExpenseCount: 0, hasCard: false, budgetConfigured: false,
      reserveConfigured: false, folegoReady: false, onboardingCompleted: false,
    );
    int? destination;
    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), home: Scaffold(body: SetupChecklist(
      state: state,
      onNavigate: (tab) => destination = tab,
      onRefresh: () {},
      onDismiss: () {},
    ))));
    expect(find.text('Seu Fôlego começa aqui'), findsOneWidget);
    expect(find.text('Adicione sua primeira conta'), findsOneWidget);
    await tester.tap(find.text('Adicione sua primeira conta'));
    expect(destination, 3);
  });

  testWidgets('completed tasks cannot navigate again', (tester) async {
    const state = OnboardingState(
      accountCount: 1, hasAccount: true, hasConfirmedIncome: true,
      recurringExpenseCount: 1, hasCard: false, budgetConfigured: true,
      reserveConfigured: false, folegoReady: false, onboardingCompleted: false,
    );
    int? destination;
    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), home: Scaffold(body: SetupChecklist(
      state: state,
      onNavigate: (tab) => destination = tab,
      onRefresh: () {},
      onDismiss: () {},
    ))));
    await tester.tap(find.text('Adicione sua primeira conta'));
    expect(destination, isNull);
  });
}
