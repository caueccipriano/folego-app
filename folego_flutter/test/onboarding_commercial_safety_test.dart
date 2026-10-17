import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('new users can skip optional intro without connecting banks',
      (tester) async {
    var completed = 0;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        onCompleted: () async { completed++; },
        onSignOut: () async {},
      ),
    ));
    expect(find.textContaining('sem conectar bancos ou planilhas'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pump();
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed first-use completion remains on intro with retry',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        onCompleted: () async {
          attempts++;
          if (attempts == 1) throw StateError('sensitive backend detail');
        },
        onSignOut: () async {},
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.textContaining('não consegui concluir'), findsOneWidget);
    expect(find.textContaining('sensitive backend detail'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.textContaining('não consegui concluir'), findsNothing);
    expect(find.textContaining('sem conectar bancos ou planilhas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed sign-out is private and does not trap a user',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        onCompleted: () async {},
        onSignOut: () async {
          attempts++;
          if (attempts == 1) throw StateError('secret auth error');
        },
      ),
    ));
    await tester.tap(find.byTooltip('sair da conta'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.textContaining('não consegui encerrar'), findsOneWidget);
    expect(find.textContaining('secret auth error'), findsNothing);
    await tester.tap(find.byTooltip('sair da conta'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.textContaining('não consegui encerrar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('next and finish remain usable for a regular new account',
      (tester) async {
    var completed = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        onCompleted: () async { completed++; },
        onSignOut: () async {},
      ),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('onboarding-finish')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-finish')));
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });
}
