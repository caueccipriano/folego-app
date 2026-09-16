import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/debt_detail.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/data/repositories/folego_repository_debts.dart';
import 'package:folego/features/wallet/debt_form_sheet.dart';
import 'package:folego/features/wallet/debt_payment_sheet.dart';
import 'package:folego/features/wallet/wallet_debt_detail_screen.dart';

void main() {
  tearDown(() {
    debugDebtDetailLoader = null;
    debugArchiveDebtAction = null;
    debugReopenDebtAction = null;
    debugCloseDebtAction = null;
    debugDebtPaymentAction = null;
  });

  test('debt draft validates and preserves cents in schedule', () {
    final draft = DebtDraft(
      name: 'Empréstimo',
      creditor: 'Banco',
      originalAmount: 100,
      totalInstallments: 3,
      firstDueDate: DateTime(2026, 10, 10),
      debtType: 'loan',
    );
    expect(draft.validate(), isNull);
    expect(draft.installmentSchedule(), [33.33, 33.33, 33.34]);
    expect(draft.hasLastInstallmentAdjustment, isTrue);
  });

  testWidgets('create debt form produces valid draft', (tester) async {
    final repository = _FakeRepository();
    DebtDraft? saved;
    await _openForm(tester, repository, onSave: (draft) async => saved = draft);

    await tester.enterText(_field('nome'), 'Financiamento carro');
    await tester.enterText(_field('credor'), 'Banco teste');
    await tester.enterText(_field('valor original'), '100,00');
    await tester.enterText(_field('parcelas'), '3');
    await tester.enterText(_field('juros ao mês (opcional)'), '1,5');
    await tester.enterText(_field('observação (opcional)'), 'contrato atual');
    await tester.tap(find.text('criar dívida'));
    await _flush(tester);

    expect(saved, isNotNull);
    expect(saved!.name, 'Financiamento carro');
    expect(saved!.creditor, 'Banco teste');
    expect(saved!.originalAmount, 100);
    expect(saved!.totalInstallments, 3);
    expect(saved!.installmentSchedule(), [33.33, 33.33, 33.34]);
    expect(saved!.interestRateMonthly, 1.5);
    expect(saved!.notes, 'contrato atual');
  });

  testWidgets('edit allows restructure before payment and administrative fields', (tester) async {
    final repository = _FakeRepository();
    DebtDraft? saved;
    await _openForm(
      tester,
      repository,
      existing: _detail(payments: const [], paidOnFirst: 0),
      onSave: (draft) async => saved = draft,
    );

    expect(find.text('editar dívida'), findsOneWidget);
    await tester.enterText(_field('nome'), 'Empréstimo atualizado');
    await tester.enterText(_field('credor'), 'Novo credor');
    await tester.enterText(_field('valor original'), '120,00');
    await tester.enterText(_field('parcelas'), '4');
    await tester.enterText(_field('observação (opcional)'), 'nota atualizada');
    await tester.tap(find.text('salvar alterações'));
    await _flush(tester);

    expect(saved, isNotNull);
    expect(saved!.name, 'Empréstimo atualizado');
    expect(saved!.creditor, 'Novo credor');
    expect(saved!.originalAmount, 120);
    expect(saved!.totalInstallments, 4);
    expect(saved!.notes, 'nota atualizada');
  });

  testWidgets('backend restructure block becomes friendly error', (tester) async {
    final repository = _FakeRepository();
    await _openForm(
      tester,
      repository,
      existing: _detail(payments: const [], paidOnFirst: 0),
      onSave: (_) async => throw Exception('debt_restructure_after_payment'),
    );
    await tester.enterText(_field('valor original'), '120,00');
    await tester.tap(find.text('salvar alterações'));
    await _flush(tester);
    expect(
      find.text('parcelas já pagas impedem reestruturar valor, quantidade ou primeiro vencimento'),
      findsOneWidget,
    );
  });

  testWidgets('paid history protects structural fields', (tester) async {
    final repository = _FakeRepository();
    await _openForm(tester, repository, existing: _detail(payments: [_payment()], paidOnFirst: 20), onSave: (_) async {});
    expect(find.text('valor, quantidade e vencimentos ficam protegidos depois do primeiro pagamento'), findsOneWidget);
    expect(tester.widget<TextField>(_field('valor original')).enabled, isFalse);
    expect(tester.widget<TextField>(_field('parcelas')).enabled, isFalse);
  });

  testWidgets('debt detail shows balance, progress, installments and payments', (tester) async {
    debugDebtDetailLoader = ({required spaceId, required debtId}) async => _detail(payments: [_payment()], paidOnFirst: 20);
    await tester.pumpWidget(MaterialApp(home: WalletDebtDetailScreen(repository: _FakeRepository(), spaceId: 'space', debt: _walletDebt())));
    await _flush(tester);

    expect(find.text('Empréstimo teste'), findsWidgets);
    expect(find.text('Banco teste · empréstimo'), findsOneWidget);
    expect(find.text('saldo restante'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('2.50% a.m.'), findsOneWidget);
    expect(find.text('nota da dívida'), findsOneWidget);
    expect(find.textContaining('já pagos'), findsOneWidget);
    expect(find.text('pagamentos'), findsOneWidget);
    expect(find.textContaining('Conta teste'), findsOneWidget);
    expect(find.text('parcelas concluídas'), findsOneWidget);
  });

  test('archive, reopen and close keep canonical lifecycle actions', () async {
    final repository = _FakeRepository();
    final calls = <String>[];
    debugArchiveDebtAction = ({required spaceId, required debtId}) async => calls.add('archive:$spaceId:$debtId');
    debugReopenDebtAction = ({required spaceId, required debtId}) async => calls.add('reopen:$spaceId:$debtId');
    debugCloseDebtAction = ({required spaceId, required debtId}) async => calls.add('close:$spaceId:$debtId');

    await repository.archiveDebt(spaceId: 'space', debtId: 'debt-1');
    await repository.reopenDebt(spaceId: 'space', debtId: 'debt-1');
    await repository.closeDebt(spaceId: 'space', debtId: 'debt-1');
    expect(calls, ['archive:space:debt-1', 'reopen:space:debt-1', 'close:space:debt-1']);
  });

  test('close surfaces backend open-balance rejection', () async {
    final repository = _FakeRepository();
    debugCloseDebtAction = ({required spaceId, required debtId}) async => throw Exception('debt_has_open_balance');
    expect(
      repository.closeDebt(spaceId: 'space', debtId: 'debt-1'),
      throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('debt_has_open_balance'))),
    );
  });

  testWidgets('payment flow sends account and partial value through canonical action', (tester) async {
    String? capturedAccountId;
    num? capturedAmount;
    String? capturedInstallmentId;
    debugDebtPaymentAction = ({required spaceId, required installmentId, required accountId, required amount, required paidAt}) async {
      capturedInstallmentId = installmentId;
      capturedAccountId = accountId;
      capturedAmount = amount;
      return 'event-1';
    };

    final detail = _detail(payments: const [], paidOnFirst: 0);
    await _openPayment(tester, _FakeRepository(), detail.debt, detail.installments.first);
    await tester.enterText(_field('valor pago'), '10,00');
    await tester.tap(find.text('registrar pagamento'));
    await _flush(tester);

    expect(capturedInstallmentId, 'installment-1');
    expect(capturedAccountId, 'account-1');
    expect(capturedAmount, 10);
  });

  test('flutter state represents partial, paid, archived, reopened and closed debts', () {
    final partial = _installment(paid: 20, remaining: 30, status: 'partially_paid');
    final paid = _installment(number: 2, paid: 50, remaining: 0, status: 'paid');
    expect(partial.canPay, isTrue);
    expect(partial.isPaid, isFalse);
    expect(paid.isPaid, isTrue);

    final archived = _record(remaining: 30, archivedAt: DateTime(2026, 9, 16));
    final reopened = _record(remaining: 30);
    final closed = _record(remaining: 0, status: 'paid', closedAt: DateTime(2026, 9, 16));
    expect(archived.isArchived, isTrue);
    expect(archived.isActive, isFalse);
    expect(reopened.isActive, isTrue);
    expect(closed.isPaid, isTrue);
  });
}

Future<void> _openForm(
  WidgetTester tester,
  FolegoRepository repository, {
  DebtDetail? existing,
  required DebtSaveOverride onSave,
}) async {
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DebtForm(repository: repository, spaceId: 'space', existing: existing, onSaveOverride: onSave))),
    child: const Text('abrir'),
  )))));
  await tester.tap(find.text('abrir'));
  await _flush(tester);
}

Future<void> _openPayment(WidgetTester tester, FolegoRepository repository, DebtRecord debt, DebtInstallmentRecord installment) async {
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: DebtPaymentSheet(repository: repository, spaceId: 'space', debt: debt, installment: installment)))),
    child: const Text('abrir pagamento'),
  )))));
  await tester.tap(find.text('abrir pagamento'));
  await _flush(tester);
}

Finder _field(String label) => find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == label);

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump();
}

DebtDetail _detail({required List<DebtPaymentRecord> payments, required double paidOnFirst}) {
  final firstRemaining = 50 - paidOnFirst;
  return DebtDetail(
    debt: _record(remaining: firstRemaining),
    installments: [
      _installment(paid: paidOnFirst, remaining: firstRemaining, status: paidOnFirst == 0 ? 'pending' : 'partially_paid'),
      _installment(number: 2, paid: 50, remaining: 0, status: 'paid'),
    ],
    payments: payments,
    today: DateTime(2026, 9, 16),
  );
}

DebtRecord _record({required double remaining, String status = 'active', DateTime? archivedAt, DateTime? closedAt}) => DebtRecord(
  id: 'debt-1',
  name: 'Empréstimo teste',
  creditor: 'Banco teste',
  debtType: 'loan',
  notes: 'nota da dívida',
  originalAmount: 100,
  openingBalance: 100,
  remainingBalance: remaining,
  interestRateMonthly: 2.5,
  totalInstallments: 2,
  paymentAccountId: 'account-1',
  status: status,
  firstDueDate: DateTime(2026, 9, 20),
  archivedAt: archivedAt,
  closedAt: closedAt,
);

DebtInstallmentRecord _installment({int number = 1, double paid = 0, double remaining = 50, String status = 'pending'}) => DebtInstallmentRecord(
  id: 'installment-$number',
  installmentNumber: number,
  dueDate: DateTime(2026, 9, 20 + number),
  plannedAmount: 50,
  paidAmount: paid,
  remainingAmount: remaining,
  status: status,
  isOverdue: false,
);

DebtPaymentRecord _payment() => DebtPaymentRecord(
  id: 'payment-1',
  eventId: 'event-1',
  installmentId: 'installment-1',
  installmentNumber: 1,
  amount: 20,
  paidAt: DateTime(2026, 9, 15),
  accountId: 'account-1',
  accountName: 'Conta teste',
  status: 'confirmed',
);

WalletDebt _walletDebt() => const WalletDebt(
  id: 'debt-1',
  name: 'Empréstimo teste',
  openingBalance: 100,
  remainingBalance: 30,
  nextAmount: 30,
  paidInstallments: 1,
  creditor: 'Banco teste',
  originalAmount: 100,
  totalInstallments: 2,
  paymentAccountId: 'account-1',
);

class _FakeRepository implements FolegoRepository {
  @override
  Future<List<AccountItem>> listAccounts(String spaceId) async => [
    const AccountItem(id: 'account-1', name: 'Conta teste', type: 'checking'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
