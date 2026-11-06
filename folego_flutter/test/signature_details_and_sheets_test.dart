import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/shared/widgets/signature_section_intro.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Signature finance sheet badge is accessible in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(12),
            child: SignatureSheetEyebrow(
              label: 'Pagamento seguro',
              icon: Icons.verified_user_outlined,
            ),
          ),
        ),
      ));
      expect(find.text('PAGAMENTO SEGURO'), findsOneWidget);
      expect(find.byKey(const ValueKey('signature-sheet-eyebrow')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('Signature is visible in secondary pages and banking forms', () {
    const details = [
      'wallet/wallet_instrument_detail_screen.dart',
      'wallet/wallet_debt_detail_screen.dart',
      'goals/goal_detail_screen.dart',
      'profile/category_management_screen.dart',
      'profile/notification_settings_screen.dart',
      'profile/automation_rules_screen.dart',
      'profile/financial_organization_screen.dart',
      'transactions/statement_import_screen.dart',
    ];
    const sheets = [
      'transactions/transaction_detail_sheet_v2.dart',
      'transactions/transaction_edit_sheet.dart',
      'transactions/transaction_filter_sheet.dart',
      'wallet/card_invoice_payment_sheet.dart',
      'goals/goal_form_sheet.dart',
      'wallet/debt_form_sheet.dart',
      'wallet/debt_payment_sheet.dart',
      'transactions/recurring_form_sheet.dart',
    ];
    for (final path in details) {
      expect(File('lib/features/$path').readAsStringSync(),
          contains('SignatureSectionIntro('), reason: path);
    }
    for (final path in sheets) {
      expect(File('lib/features/$path').readAsStringSync(),
          contains('SignatureSheetEyebrow('), reason: path);
    }
  });

  test('nested transaction editor has an opaque sheet on iPhone', () {
    final source =
        File('lib/features/transactions/transaction_detail_sheet_v2.dart')
            .readAsStringSync();
    final start = source.indexOf('Future<bool?> _showEditor(');
    final end = source.indexOf('Future<void> _editSpendingBehavior()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final editor = source.substring(start, end);
    expect(editor,
        contains('backgroundColor: AppColors.surface(Theme.of(context).brightness)'));
    expect(editor, contains('barrierColor:'));
    expect(editor, contains('clipBehavior: Clip.antiAlias'));
    expect(editor, isNot(contains('backgroundColor: AppColors.transparent')));
  });

  test('signature details preserve their original financial safety actions', () {
    final payment = File('lib/features/wallet/card_invoice_payment_sheet.dart')
        .readAsStringSync();
    final edit = File('lib/features/transactions/transaction_edit_sheet.dart')
        .readAsStringSync();
    final details =
        File('lib/features/transactions/transaction_detail_sheet_v2.dart')
            .readAsStringSync();
    final filter =
        File('lib/features/transactions/transaction_filter_sheet.dart')
            .readAsStringSync();
    final import =
        File('lib/features/transactions/statement_import_screen.dart')
            .readAsStringSync();
    expect(payment, contains('_saving'));
    expect(edit, contains('_formKey'));
    expect(details, contains('_changed'));
    expect(filter, contains('_draft'));
    expect(import, contains('_cancelImport'));
    expect(import, contains('_reviewStep'));
  });
}
