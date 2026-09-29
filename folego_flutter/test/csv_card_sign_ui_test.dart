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
import 'package:folego/features/transactions/statement_import_parser.dart';

class _FakeRepository extends Fake implements FolegoRepository {}

StatementImportBootstrap _bootstrap() => const StatementImportBootstrap(
      paymentAccounts: [
        AccountItem(id: 'fictional-account', name: 'Conta fictícia', type: 'checking'),
      ],
      benefitAccounts: [],
      cards: [
        CreditCardItem(id: 'fictional-card', name: 'Cartão fictício', active: true),
      ],
      expenseCategories: [
        CategoryItem(
          id: 'fictional-category', name: 'Teste', kind: 'expense',
          essential: false, iconKey: 'groceries',
        ),
      ],
      incomeCategories: [],
      invoices: [],
    );

Future<void> _cardMapping(WidgetTester tester, {
  required Future<String> Function(List<StatementImportCandidate> candidates,
    Map<String, dynamic> configuration) onStage,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(
    home: StatementImportScreen(
      repository: _FakeRepository(),
      spaceId: 'fictional-space',
      bootstrapOverride: () async => _bootstrap(),
      pickOverride: () async => StatementImportPickedFile(
        name: 'fictional-positive-card.csv',
        bytes: Uint8List.fromList(utf8.encode(
          'Data;Descrição;Valor\n'
          '28/09/2026;COMPRA FICTÍCIA;35,90\n'
          '29/09/2026;ESTORNO FICTÍCIO;-8,90\n',
        )),
      ),
      stageOverride: ({
        required fileType, required sourceKind,
        required sourceAccountId, required sourceCardId,
        required sourceInstitution, required fingerprint,
        required configuration, required candidates,
      }) async {
        expect(fileType, StatementImportFileType.csv);
        expect(sourceKind, StatementImportSourceKind.card);
        expect(sourceAccountId, isNull);
        expect(sourceCardId, 'fictional-card');
        return onStage(candidates, configuration);
      },
      rowsLoaderOverride: (_) async => const <StatementImportRow>[],
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('cartão').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('statement-import-destination-card')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cartão fictício').last);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('statement-import-destination-continue')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('statement-import-csv-mapping')),
      findsOneWidget);
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder target, {
  double delta = 200,
}) async {
  final scrollable = find.descendant(
    of: find.byKey(const ValueKey('statement-import-csv-mapping')),
    matching: find.byType(Scrollable),
  ).first;
  await tester.scrollUntilVisible(target, delta, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed card CSV cannot stage BEFORE explicitly selecting purchase sign',
      (tester) async {
    var stageCalls = 0;
    await _cardMapping(tester, onStage: (candidates, configuration) async {
      stageCalls++;
      return 'fictional-batch';
    });

    final stage = find.byKey(const ValueKey('statement-import-stage-csv'));
    await _scrollTo(tester, stage);
    await tester.tap(stage);
    await tester.pumpAndSettle();

    expect(stageCalls, 0);
    expect(
      find.textContaining('confirme se compras do cartão aparecem'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('positive card sign is deliberate, persisted and shown in staged rows',
      (tester) async {
    var stageCalls = 0;
    await _cardMapping(tester, onStage: (candidates, configuration) async {
      stageCalls++;
      expect(candidates, hasLength(2));
      expect(candidates.first.amountMinor, 3590);
      expect(candidates.first.direction, StatementImportDirection.debit);
      expect(candidates.first.finalType, StatementImportFinalType.cardPurchase);
      expect(candidates.last.amountMinor, 890);
      expect(candidates.last.direction, StatementImportDirection.credit);
      expect(candidates.last.finalType, isNull);
      final mapping = configuration['mapping'] as Map<String, dynamic>;
      expect(mapping['card_sign_convention'], 'purchasesPositive');
      return 'fictional-batch';
    });

    final sign = find.byKey(const ValueKey('csv-card-sign-card-2'));
    await _scrollTo(tester, sign);
    expect(find.textContaining('sinal das compras no cartão'), findsOneWidget);
    await tester.tap(sign);
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('compras positivas (ex.: +35,90)').last,
    );
    await tester.pumpAndSettle();

    final stage = find.byKey(const ValueKey('statement-import-stage-csv'));
    await _scrollTo(tester, stage);
    await tester.tap(stage);
    await tester.pumpAndSettle();
    expect(stageCalls, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('changing signed source amount requires a NEW sign confirmation',
      (tester) async {
    var stageCalls = 0;
    await _cardMapping(tester, onStage: (candidates, configuration) async {
      stageCalls++;
      return 'fictional-batch';
    });

    final sign = find.byKey(const ValueKey('csv-card-sign-card-2'));
    await _scrollTo(tester, sign);
    await tester.tap(sign);
    await tester.pumpAndSettle();
    await tester.tap(find.text('compras positivas (ex.: +35,90)').last);
    await tester.pumpAndSettle();

    final amountField = find.descendant(
      of: find.byKey(const ValueKey('statement-import-signed-amount-field')),
      matching: find.byType(DropdownButtonFormField<int>),
    );
    // The amount field is ABOVE the sign selector. Scroll upward from the
    // previously visible sign; positive scroll would move farther away from
    // an unmounted lazily built amount field and produce a false test error.
    await _scrollTo(tester, amountField, delta: -200);
    await tester.tap(amountField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('não usar').last);
    await tester.pumpAndSettle();

    // Restoring the same amount column must NOT silently restore the old
    // source-sign choice. A stale choice could turn a refund into a charge.
    await tester.tap(amountField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valor').last);
    await tester.pumpAndSettle();

    await _scrollTo(tester, sign);
    final selected =
        tester.widget<DropdownButtonFormField<CsvCardSignConvention>>(sign);
    expect(selected.initialValue, isNull);

    final stage = find.byKey(const ValueKey('statement-import-stage-csv'));
    await _scrollTo(tester, stage);
    await tester.tap(stage);
    await tester.pumpAndSettle();
    expect(stageCalls, 0);
    expect(find.textContaining('confirme se compras do cartão aparecem'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
