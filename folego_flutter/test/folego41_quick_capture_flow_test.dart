import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/credit_card_item.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/quick_register_sheet.dart';

Future<void> _openQuickSheet(
  WidgetTester tester, {
  required int paymentAccounts,
}) async {
  final accounts = List<AccountItem>.generate(
    paymentAccounts,
    (i) => AccountItem(
      id: 'account-$i',
      name: 'conta ${i + 1}',
      type: 'bank',
    ),
  );
  final repository = FolegoRepository(
    SupabaseClient('https://example.supabase.co', 'fake-public-anon-key'),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuickRegisterSheet(
          key: ValueKey('quick-catalog-$paymentAccounts'),
          space: const FinancialSpace(id: 'demo', name: 'demo'),
          repository: repository,
          loadCatalog: () async => (
            accounts: accounts,
            benefits: <AccountItem>[],
            cards: <CreditCardItem>[],
            categories: <CategoryItem>[
              const CategoryItem(
                id: 'transport',
                name: 'Transporte',
                kind: 'expense',
                essential: false,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 30));
}

void main() {
  testWidgets('one-line capture fills two fields but never auto-saves',
      (tester) async {
    await _openQuickSheet(tester, paymentAccounts: 1);
    final description =
        find.byKey(const ValueKey('quick-register-description'));
    final amount = find.byKey(const ValueKey('quick-register-amount'));

    expect(description, findsOneWidget);
    expect(amount, findsOneWidget);
    await tester.enterText(description, '27,90 Uber');
    await tester.pump();

    expect(tester.widget<TextField>(description).controller!.text, 'Uber');
    expect(tester.widget<TextField>(amount).controller!.text, '27,90');
    expect(
      find.text('valor preenchido · confira antes de registrar'),
      findsOneWidget,
    );
    expect(find.text('registrar gasto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all accounts require deliberate selection, even if there is one',
      (tester) async {
    await _openQuickSheet(tester, paymentAccounts: 1);
    final single =
        tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>).first,
        );
    expect(single.initialValue, isNull);

    await _openQuickSheet(tester, paymentAccounts: 2);
    final multiple =
        tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>).first,
        );
    expect(multiple.initialValue, isNull);
    expect(tester.takeException(), isNull);
  });
}
