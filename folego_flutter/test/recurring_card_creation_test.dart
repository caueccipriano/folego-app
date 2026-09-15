import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/credit_card_item.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/recurring_form_sheet.dart';

void main() {
  const space = FinancialSpace(id: 'space-1', name: 'Pessoal');

  testWidgets('new recurring expense can use a credit card only', (tester) async {
    final repository = _FakeFolegoRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurringFormSheet(
            space: space,
            repository: repository,
            activeCardLoader: (_) async => const [
              CreditCardItem(
                id: 'card-1',
                name: 'Cartão principal',
                active: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Spotify');
    await tester.enterText(find.byType(TextField).at(1), '21,90');
    await tester.tap(find.text('Cartão'));
    await tester.pumpAndSettle();

    expect(find.text('Cartão principal'), findsOneWidget);
    expect(find.text('Conta ativa'), findsNothing);

    await tester.ensureVisible(find.text('Criar recorrência'));
    await tester.tap(find.text('Criar recorrência'));
    await tester.pumpAndSettle();

    expect(repository.createdAccountId, isNull);
    expect(repository.createdCardId, 'card-1');
  });

  testWidgets('new recurring expense keeps account destination exclusive', (
    tester,
  ) async {
    final repository = _FakeFolegoRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurringFormSheet(
            space: space,
            repository: repository,
            activeCardLoader: (_) async => const [
              CreditCardItem(
                id: 'card-1',
                name: 'Cartão principal',
                active: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Academia');
    await tester.enterText(find.byType(TextField).at(1), '99,90');

    expect(find.text('Conta ativa'), findsOneWidget);

    await tester.ensureVisible(find.text('Criar recorrência'));
    await tester.tap(find.text('Criar recorrência'));
    await tester.pumpAndSettle();

    expect(repository.createdAccountId, 'account-1');
    expect(repository.createdCardId, isNull);
  });
}

class _FakeFolegoRepository extends FolegoRepository {
  _FakeFolegoRepository()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'test-anon-key',
          ),
        );

  String? createdAccountId;
  String? createdCardId;

  @override
  Future<List<AccountItem>> listAccounts(String spaceId) async => const [
        AccountItem(id: 'account-1', name: 'Conta ativa', type: 'checking'),
      ];

  @override
  Future<List<CategoryItem>> listExpenseCategories(String spaceId) async {
    return const [
      CategoryItem(
        id: 'category-1',
        name: 'Assinaturas',
        essential: false,
      ),
    ];
  }

  @override
  Future<List<CategoryItem>> listIncomeCategories(String spaceId) async {
    return const [
      CategoryItem(
        id: 'income-category-1',
        name: 'Salário',
        essential: true,
      ),
    ];
  }

  @override
  Future<String> createRecurringItem({
    required String spaceId,
    required String name,
    required String itemType,
    required num amount,
    required String frequency,
    String? accountId,
    String? cardId,
    String? categoryId,
    int? dayOfMonth,
    List<int>? monthlyDays,
    bool monthlyLastDay = false,
    int? weekday,
    int? monthOfYear,
    required DateTime startsOn,
    DateTime? endsOn,
    String certainty = 'confirmed',
  }) async {
    createdAccountId = accountId;
    createdCardId = cardId;
    return 'recurring-created';
  }
}
