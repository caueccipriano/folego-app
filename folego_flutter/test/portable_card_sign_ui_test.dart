import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/credit_card_item.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/statement_import_screen.dart';

class _FakeRepository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('iPhone card CSV lets user explicitly select positive purchases',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    List<StatementImportCandidate>? staged;
    Map<String, dynamic>? config;

    await tester.pumpWidget(MaterialApp(
      home: StatementImportScreen(
        repository: _FakeRepository(),
        spaceId: 'fictional-space-a',
        bootstrapOverride: () async => const StatementImportBootstrap(
          paymentAccounts: [],
          benefitAccounts: [],
          cards: [CreditCardItem(
            id: 'fictional-card-a',
            name: 'Cartão fictício',
            active: true,
          )],
          expenseCategories: [],
          incomeCategories: [],
          invoices: [],
        ),
        pickOverride: () async => StatementImportPickedFile(
          name: 'fictional-card.csv',
          bytes: Uint8List.fromList(utf8.encode(
            'Data;Descrição;Valor\n'
            '29/09/2026;COMPRA FICTÍCIA;95,50\n',
          )),
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
        }) async {
          expect(sourceKind, StatementImportSourceKind.card);
          expect(sourceAccountId, isNull);
          expect(sourceCardId, 'fictional-card-a');
          staged = candidates;
          config = configuration;
          return 'fictional-staging-batch';
        },
        rowsLoaderOverride: (_) async => const [],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cartão').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('statement-import-destination-card')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cartão fictício').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('statement-import-destination-continue')),
    );
    await tester.pumpAndSettle();

    final map = find.byKey(const ValueKey('statement-import-csv-mapping'));
    expect(map, findsOneWidget);
    final scroll = find.descendant(
      of: map,
      matching: find.byType(Scrollable),
    ).first;
    final signField = find.byKey(
      const ValueKey('statement-import-card-sign-convention'),
    );
    await tester.scrollUntilVisible(signField, 220, scrollable: scroll);
    expect(signField, findsOneWidget);
    await tester.tap(signField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compras positivas (+)').last);
    await tester.pumpAndSettle();

    final stage = find.byKey(const ValueKey('statement-import-stage-csv'));
    await tester.scrollUntilVisible(stage, 220, scrollable: scroll);
    await tester.tap(stage);
    await tester.pumpAndSettle();

    expect(staged, isNotNull);
    expect(staged, hasLength(1));
    expect(staged!.single.direction, StatementImportDirection.debit);
    expect(staged!.single.finalType, StatementImportFinalType.cardPurchase);
    expect(
      (config?['mapping'] as Map<String, dynamic>?)?['card_sign_convention'],
      'purchasesPositive',
    );
    expect(tester.takeException(), isNull);
  });
}
