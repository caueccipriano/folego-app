import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/recurring_form_sheet.dart';

void main() {
  Future<void> open(WidgetTester tester, _Repository repository,
      {RecurringItem? item}) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RecurringFormSheet(
      space: const FinancialSpace(id: 'space', name: 'Pessoal'),
      repository: repository,
      initialType: 'income',
      item: item,
    ))));
    await tester.pumpAndSettle();
    if (item == null) {
      await tester.enterText(find.byType(TextField).at(0), 'Salário');
      await tester.enterText(find.byType(TextField).at(1), '1000,00');
    }
  }

  Future<void> removeDay(WidgetTester tester) async {
    final chip = find.byType(InputChip).first;
    await tester.ensureVisible(chip);
    await tester.tap(find.descendant(of: chip, matching: find.byType(Icon)).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, {bool editing = false}) async {
    final button = find.text(editing ? 'salvar recorrência' : 'criar recorrência');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('last day alone never sends an old fixed day', (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    await tester.ensureVisible(find.text('último dia'));
    await tester.tap(find.text('último dia'));
    await tester.pumpAndSettle();
    await removeDay(tester);
    await save(tester);
    expect(repository.calls, 1);
    expect(repository.day, isNull);
    expect(repository.days, isEmpty);
    expect(repository.lastDay, isTrue);
  });

  testWidgets('empty monthly schedule is rejected before saving', (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    await removeDay(tester);
    await save(tester);
    expect(repository.calls, 0);
    expect(find.text('selecione pelo menos um dia do mês'), findsOneWidget);
  });

  testWidgets('editing a last-day schedule does not add a legacy day', (tester) async {
    final repository = _Repository();
    await open(tester, repository, item: RecurringItem(
      id: 'recurring', spaceId: 'space', name: 'Salário',
      itemType: 'income', amount: 1000, frequency: 'monthly',
      startsOn: DateTime(2026, 9, 15), certainty: 'confirmed', active: true,
      accountId: 'account', categoryId: 'income', dayOfMonth: 15,
      monthlyLastDay: true,
    ));
    expect(find.byType(InputChip), findsNothing);
    await save(tester, editing: true);
    expect(repository.calls, 1);
    expect(repository.day, isNull);
    expect(repository.days, isEmpty);
    expect(repository.lastDay, isTrue);
  });
}

class _Repository implements FolegoRepository {
  int calls = 0;
  int? day;
  List<int>? days;
  bool? lastDay;
  @override
  Future<List<AccountItem>> listAccounts(String spaceId) async =>
      const [AccountItem(id: 'account', name: 'Conta', type: 'checking')];
  @override
  Future<List<CategoryItem>> listExpenseCategories(String spaceId) async =>
      const [CategoryItem(id: 'expense', name: 'Outros', essential: false)];
  @override
  Future<List<CategoryItem>> listIncomeCategories(String spaceId) async =>
      const [CategoryItem(id: 'income', name: 'Salário', essential: true)];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #createRecurringItem ||
        invocation.memberName == #updateRecurringItem) {
      calls++;
      day = invocation.namedArguments[#dayOfMonth] as int?;
      days = invocation.namedArguments[#monthlyDays] as List<int>?;
      lastDay = invocation.namedArguments[#monthlyLastDay] as bool?;
      if (invocation.memberName == #createRecurringItem) {
        return Future<String>.value('created');
      }
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
