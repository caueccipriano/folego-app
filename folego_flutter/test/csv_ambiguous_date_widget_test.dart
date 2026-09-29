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

class _FakeRepository extends Fake implements FolegoRepository {}

void main() {
  testWidgets('compact CSV wizard refuses ambiguous date before any staging',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var stageCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatementImportScreen(
          repository: _FakeRepository(),
          spaceId: 'fictional-space',
          bootstrapOverride: () async => const StatementImportBootstrap(
            paymentAccounts: [
              AccountItem(
                id: 'fictional-account',
                name: 'Conta fictícia',
                type: 'checking',
              ),
            ],
            benefitAccounts: [],
            cards: <CreditCardItem>[],
            expenseCategories: <CategoryItem>[],
            incomeCategories: <CategoryItem>[],
            invoices: [],
          ),
          pickOverride: () async => StatementImportPickedFile(
            name: 'fictional-ambiguous.csv',
            bytes: Uint8List.fromList(utf8.encode(
              'Data;Descrição;Valor\n'
              '05/06/2026;Compra fictícia;-35,90\n',
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
            stageCalls++;
            return 'fictional-batch';
          },
          rowsLoaderOverride: (_) async => const <StatementImportRow>[],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statement-import-pick-file')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conta fictícia').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('statement-import-destination-continue')),
    );
    await tester.pumpAndSettle();

    final mapping = find.byKey(
      const ValueKey('statement-import-csv-mapping'),
    );
    expect(mapping, findsOneWidget);
    await tester.drag(mapping, const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('statement-import-ambiguous-date-guidance')),
      findsOneWidget,
    );
    final stage = find.byKey(const ValueKey('statement-import-stage-csv'));
    expect(stage, findsOneWidget);
    await tester.tap(stage);
    await tester.pumpAndSettle();

    expect(stageCalls, 0);
    expect(
      find.textContaining('data ambígua: selecione manualmente'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
