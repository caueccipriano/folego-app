import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/profile/help_faq_screen.dart';

void main() {
  testWidgets('FAQ searches income questions and can switch to English', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpFaqScreen()));
    await tester.tap(find.text('Português').last);
    await tester.pumpAndSettle();
    expect(find.text('Help & FAQs'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'paycheck');
    await tester.pumpAndSettle();
    expect(find.text('Where do I add my paycheck or money I received?'), findsOneWidget);
    expect(find.text('Where do I add recurring bills?'), findsNothing);
  });
}
