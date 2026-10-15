import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/profile/folego_help_screen.dart';

void main() {
  testWidgets('financial FAQ expands and offers a support path', (tester) async {
    var contacted = false;
    await tester.pumpWidget(MaterialApp(
      home: FolegoHelpScreen(onContact: () => contacted = true),
    ));
    await tester.pumpAndSettle();

    expect(find.text('entenda seu fôlego.'), findsOneWidget);
    final question = find.byKey(const ValueKey('help-question-1'));
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.textContaining('pagar a fatura movimenta o saldo'), findsOneWidget);

    final contact = find.byKey(const ValueKey('help-contact'));
    await tester.scrollUntilVisible(
      contact,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(contact);
    expect(contacted, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('Help is discoverable in Profile without bypassing onboarding', () {
    final profile = File('lib/features/profile/profile_screen_v2.dart')
        .readAsStringSync();
    expect(profile, contains('ajuda e perguntas frequentes'));
    expect(profile, contains('FolegoHelpScreen('));
    expect(profile, contains('onTap: _openHelpCenter'));
  });
}
