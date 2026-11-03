import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/shared/widgets/signature_section_intro.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('Signature final surfaces render on $width $brightness',
          (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SignatureSectionIntro(
                    eyebrow: 'Central de atenção',
                    caption: 'Avisos organizados, sem notificações desnecessárias',
                    icon: Icons.notifications_none_rounded,
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SignatureSheetEyebrow(
                      label: 'Conciliação manual',
                      icon: Icons.link_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
        expect(find.text('CENTRAL DE ATENÇÃO'), findsOneWidget);
        expect(find.text('CONCILIAÇÃO MANUAL'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('remaining wallet and movement surfaces share the Signature identity', () {
    const sheets = <String>[
      'wallet/wallet_instrument_management.dart',
      'wallet/existing_payment_picker.dart',
      'transactions/transaction_action_sheets.dart',
      'home/quick_register_sheet_v3.dart',
    ];
    for (final path in sheets) {
      final source = File('lib/features/$path').readAsStringSync();
      expect(source, contains('SignatureSheetEyebrow('), reason: path);
    }
    const sections = <String>[
      'profile/notification_history_screen.dart',
      'profile/folego_help_screen.dart',
      'profile/folego_feedback_screen.dart',
      'profile/sheet_audit_screen.dart',
      'profile/capture_review_screen.dart',
    ];
    for (final path in sections) {
      final source = File('lib/features/$path').readAsStringSync();
      expect(source, contains('SignatureSectionIntro('), reason: path);
    }
  });

  test('financial safety controls are unchanged after the visual finish', () {
    final wallet = File('lib/features/wallet/wallet_instrument_management.dart')
        .readAsStringSync();
    final movement = File('lib/features/home/quick_register_sheet_v3.dart')
        .readAsStringSync();
    final payment = File('lib/features/wallet/existing_payment_picker.dart')
        .readAsStringSync();
    final audit = File('lib/features/profile/sheet_audit_screen.dart')
        .readAsStringSync();
    final receipt = File('lib/features/profile/capture_review_screen.dart')
        .readAsStringSync();
    expect(wallet, contains("ValueKey('wallet-account-name')"));
    expect(wallet, contains("ValueKey('wallet-card-name')"));
    expect(movement, contains('_moneyField()'));
    expect(movement, contains('_categoryField(brightness)'));
    expect(payment, contains('linkPayment'));
    expect(audit, contains('sheet-audit-no-ack-warning'));
    expect(receipt, contains('linked_event_id'));
  });
}
