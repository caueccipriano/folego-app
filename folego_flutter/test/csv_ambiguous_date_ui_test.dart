import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/statement_import.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/statement_import_screen.dart';

class _FakeRepository extends Fake implements FolegoRepository {}

void main() {
  testWidgets('iPhone import blocks ambiguous dates until DD/MM selected',
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
          spaceId: 'fake-account-space',
          bootstrapOverride: () async => const StatementImportBootstrap(
            paymentAccounts: [
              AccountItem(
                id: 'fake-account',
                name: 'Conta fictícia',
                type: 'checking',
              ),
            ],
            benefitAccounts: [],
            cards: [],
            expenseCategories: [],
            incomeCategories: [],
            invoices: [],
          ),
          pickOverride: () async => StatementImportPickedFile(
            name: 'fictitious-date-ambiguous.csv',
            bytes: Uint8List.fromList(utf8.encode(
              'Data;Descrição;Valor\n'
              '09/10/2026;DESPESA DE TESTE;-35,90\n',
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
            expect(candidates, hasLength(1));
            expect(candidates.single.occurredAt.month, 10);
            expect(candidates.single.occurredAt.day, 9);
            expect(candidates.single.direction, StatementImportDirection.debit);
            return 'fake-batch';
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

    final mapping = find.byKey(const ValueKey('statement-import-csv-mapping'));
    expect(mapping, findsOneWidget);
    expect(
      find.textContaining('Encontramos datas que podem representar'),
      findsOneWidget,
    );
    final scrollable =
        find.descendant(of: mapping, matching: find.byType(Scrollable)).first;
    final stage = find.byKey(const ValueKey('statement-import-stage-csv'));
    await tester.scrollUntilVisible(stage, 210, scrollable: scrollable);
    await tester.tap(stage);
    await tester.pumpAndSettle();
    expect(stageCalls, 0);
    expect(
      find.textContaining('o arquivo contém datas ambíguas'),
      findsOneWidget,
    );

    final dateDropdown = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField<dynamic> &&
          widget.decoration.labelText == 'formato de data',
    );
    await tester.scrollUntilVisible(
      dateDropdown,
      -200,
      scrollable: scrollable,
    );
    await tester.tap(dateDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DD/MM/AAAA').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(stage, 210, scrollable: scrollable);
    await tester.tap(stage);
    await tester.pumpAndSettle();
    expect(stageCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
