import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/credit_card_item.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/statement_import_screen.dart';

class _Repository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StatementImportBootstrap _bootstrap() => const StatementImportBootstrap(
      paymentAccounts: [AccountItem(id: 'account-1', name: 'Conta teste', type: 'checking')],
      benefitAccounts: [AccountItem(id: 'benefit-1', name: 'Vale teste', type: 'benefit')],
      cards: [CreditCardItem(id: 'card-1', name: 'Cartão teste', active: true)],
      expenseCategories: [CategoryItem(id: 'cat-exp', name: 'Mercado', essential: true, kind: 'expense', iconKey: 'groceries')],
      incomeCategories: [CategoryItem(id: 'cat-inc', name: 'Salário', essential: true, kind: 'income', iconKey: 'income')],
      invoices: [],
    );

StatementImportRow _row({StatementImportDuplicateState duplicate = StatementImportDuplicateState.unique}) => StatementImportRow(
      id: 'row-1',
      batchId: 'batch-1',
      rowNumber: 1,
      occurredAt: DateTime(2026, 9, 16, 12),
      description: 'MERCADO TESTE',
      amount: 35.90,
      direction: StatementImportDirection.debit,
      candidateType: StatementImportCandidateType.expense,
      finalType: StatementImportFinalType.expense,
      duplicateState: duplicate,
      decision: duplicate == StatementImportDuplicateState.unique ? StatementImportDecision.include : StatementImportDecision.ignore,
      status: StatementImportRowStatus.staged,
    );

Future<void> _pumpImport(
  WidgetTester tester, {
  required Size size,
  StatementImportDuplicateState duplicate = StatementImportDuplicateState.unique,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  var confirmed = false;
  await tester.pumpWidget(MaterialApp(home: StatementImportScreen(
    repository: _Repository(),
    spaceId: 'space-1',
    bootstrapOverride: () async => _bootstrap(),
    pickOverride: () async => StatementImportPickedFile(
      name: 'teste.csv',
      bytes: Uint8List.fromList(utf8.encode('data;descricao;valor\n16/09/2026;MERCADO TESTE;-35,90\n')),
    ),
    stageOverride: ({required fileType, required sourceKind, required sourceAccountId, required sourceCardId, required sourceInstitution, required fingerprint, required configuration, required candidates}) async {
      expect(candidates, hasLength(1));
      expect(candidates.single.description, 'MERCADO TESTE');
      return 'batch-1';
    },
    rowsLoaderOverride: (_) async => [
      if (!confirmed) _row(duplicate: duplicate) else StatementImportRow(
        id: 'row-1', batchId: 'batch-1', rowNumber: 1,
        occurredAt: DateTime(2026, 9, 16, 12), description: 'MERCADO TESTE', amount: 35.90,
        direction: StatementImportDirection.debit, candidateType: StatementImportCandidateType.expense,
        finalType: StatementImportFinalType.expense, duplicateState: duplicate,
        decision: StatementImportDecision.include, status: StatementImportRowStatus.imported,
        importedEventId: 'event-1',
      ),
    ],
    updateOverride: (_, rows) async => expect(rows, isNotEmpty),
    confirmOverride: (_) async {
      confirmed = true;
      return const StatementImportResult(batchId: 'batch-1', status: 'completed', imported: 1, ignored: 0, duplicates: 0, errors: 0, pending: 0);
    },
    cancelOverride: (_) async {},
  )));
  await tester.pumpAndSettle();
}

Future<void> _driveCsvToReview(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conta teste').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('statement-import-destination-continue')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('statement-import-csv-mapping')), findsOneWidget);
  await tester.ensureVisible(find.byKey(const ValueKey('statement-import-stage-csv')));
  await tester.tap(find.byKey(const ValueKey('statement-import-stage-csv')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile CSV wizard reaches review, confirms and shows result', (tester) async {
    await _pumpImport(tester, size: const Size(390, 844));
    await _driveCsvToReview(tester);
    expect(find.byKey(const ValueKey('statement-import-review-mobile')), findsOneWidget);
    expect(find.text('MERCADO TESTE'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('statement-import-confirm')));
    await tester.tap(find.byKey(const ValueKey('statement-import-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('statement-import-result')), findsOneWidget);
    expect(find.text('importação concluída'), findsOneWidget);
    expect(find.text('ver lançamentos'), findsOneWidget);
  });

  testWidgets('desktop uses dense review layout', (tester) async {
    await _pumpImport(tester, size: const Size(1366, 900));
    await _driveCsvToReview(tester);
    expect(find.byKey(const ValueKey('statement-import-review-desktop')), findsOneWidget);
  });

  testWidgets('exact duplicate is ignored by default and clearly labeled', (tester) async {
    await _pumpImport(tester, size: const Size(430, 900), duplicate: StatementImportDuplicateState.exactDuplicate);
    await _driveCsvToReview(tester);
    expect(find.textContaining('duplicata exata'), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byKey(const ValueKey('statement-import-include-row-1')));
    expect(checkbox.value, isFalse);
  });

  testWidgets('responsive scaffold renders requested widths without exception', (tester) async {
    for (final width in <double>[375, 390, 430, 768, 1024, 1366, 1440, 1920]) {
      await _pumpImport(tester, size: Size(width, 900));
      expect(find.text('importar extrato'), findsOneWidget, reason: 'width $width');
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
