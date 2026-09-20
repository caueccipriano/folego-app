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

class _Repo implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StatementImportBootstrap _bootstrap() => const StatementImportBootstrap(
      paymentAccounts: [
        AccountItem(id: 'account-1', name: 'Conta teste', type: 'checking'),
        AccountItem(id: 'account-2', name: 'Reserva', type: 'savings'),
      ],
      benefitAccounts: [],
      cards: [CreditCardItem(id: 'card-1', name: 'Cartão teste', active: true)],
      expenseCategories: [
        CategoryItem(
          id: 'cat-exp',
          name: 'Mercado',
          essential: true,
          kind: 'expense',
          iconKey: 'groceries',
        ),
      ],
      incomeCategories: [],
      invoices: [],
    );

List<StatementImportRow> _rows() => List<StatementImportRow>.generate(
      120,
      (index) {
        final duplicate = index % 10 == 0
            ? StatementImportDuplicateState.possibleDuplicate
            : StatementImportDuplicateState.unique;
        final pending = index % 15 == 0;
        return StatementImportRow(
          id: 'row-$index',
          batchId: 'batch-qa',
          rowNumber: index + 1,
          occurredAt: DateTime(2026, 9, 1 + (index % 20), 12),
          description: pending ? 'TRANSFERENCIA ENTRE CONTAS $index' : 'COMPRA $index',
          amount: 10 + index / 10,
          direction: StatementImportDirection.debit,
          candidateType: pending
              ? StatementImportCandidateType.transferCandidate
              : StatementImportCandidateType.expense,
          finalType: pending ? null : StatementImportFinalType.expense,
          duplicateState: duplicate,
          decision: pending
              ? StatementImportDecision.review
              : duplicate == StatementImportDuplicateState.unique
                  ? StatementImportDecision.include
                  : StatementImportDecision.review,
          status: StatementImportRowStatus.staged,
          reason: pending ? 'confirme a contraparte' : null,
        );
      },
    );

Future<void> _openReview(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: StatementImportScreen(
        repository: _Repo(),
        spaceId: 'space-1',
        bootstrapOverride: () async => _bootstrap(),
        pickOverride: () async => StatementImportPickedFile(
          name: 'stress.csv',
          bytes: Uint8List.fromList(
            utf8.encode(
              'data;descricao;valor\n'
              '16/09/2026;COMPRA TESTE;-35,90\n',
            ),
          ),
        ),
        stageOverride: ({
          required fileType,
          required sourceKind,
          required sourceAccountId,
          required sourceCardId,
          required sourceInstitution,
          required fingerprint,
          required configuration,
          required candidates,
        }) async => 'batch-qa',
        rowsLoaderOverride: (_) async => _rows(),
        updateOverride: (batchId, rows) async {},
        confirmOverride: (_) async => const StatementImportResult(
          batchId: 'batch-qa',
          status: 'partially_completed',
          imported: 100,
          ignored: 10,
          duplicates: 12,
          errors: 0,
          pending: 10,
        ),
        cancelOverride: (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conta teste').last);
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(const ValueKey('statement-import-destination-continue')),
  );
  await tester.pumpAndSettle();

  final mapping = find.byKey(const ValueKey('statement-import-csv-mapping'));
  await tester.drag(mapping, const Offset(0, -900));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('statement-import-stage-csv')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile review handles 120 mixed rows without overflow', (tester) async {
    await _openReview(tester);

    expect(find.text('120 linhas'), findsOneWidget);
    expect(find.byKey(const ValueKey('statement-import-review-mobile')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final review = find.byKey(const ValueKey('statement-import-review-mobile'));
    final scrollable = find.descendant(of: review, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('statement-import-include-row-119')),
      600,
      scrollable: scrollable,
      maxScrolls: 40,
    );
    expect(find.text('COMPRA 119'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile review search and duplicate filter stay usable', (tester) async {
    await _openReview(tester);

    final search = find.byType(TextField).first;
    await tester.enterText(search, 'COMPRA 119');
    await tester.pumpAndSettle();
    expect(find.text('COMPRA 119'), findsOneWidget);
    expect(find.text('COMPRA 118'), findsNothing);

    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('duplicados'));
    await tester.pumpAndSettle();

    expect(find.textContaining('duplicata possível'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
