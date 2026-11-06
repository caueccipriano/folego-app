import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editing from transaction details uses an opaque iPhone modal', () {
    final source = File(
      'lib/features/transactions/transaction_detail_sheet_v2.dart',
    ).readAsStringSync();

    final editor = source
        .split('Future<bool?> _showEditor(Widget child) {')
        .last
        .split('Future<void> _editSpendingBehavior()')[0];

    expect(editor, contains('backgroundColor: AppColors.surface(brightness)'));
    expect(editor, contains('barrierColor:'));
    expect(editor, contains('clipBehavior: Clip.antiAlias'));
    expect(editor, contains('FractionallySizedBox('));
    expect(editor, contains('heightFactor: .92'));
    expect(editor, contains('isScrollControlled: true'));
    expect(editor, contains('useSafeArea: true'));
    expect(editor, isNot(contains('backgroundColor: AppColors.transparent')));
  });

  test('editor still updates its detail after a successful save', () {
    final source = File(
      'lib/features/transactions/transaction_detail_sheet_v2.dart',
    ).readAsStringSync();
    final edit = source
        .split('Future<void> _edit() async {')
        .last
        .split('Future<void> _editRecurringOrigin()')[0];

    expect(edit, contains('TransactionEditSheet('));
    expect(edit, contains('if (saved == true && mounted)'));
    expect(edit, contains('_changed = true;'));
    expect(edit, contains('await _load();'));
  });
}
