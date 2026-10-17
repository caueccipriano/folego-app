import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/transaction_reflection.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/diary/diary_screen.dart';

void main() {
  testWidgets('Diary desktop renders all sections and keeps reflection clickable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final reflected = DiaryEntry(
      eventId: 'reflected',
      eventType: 'expense',
      description: 'Mercado refletido',
      amount: 120,
      occurredAt: DateTime(2026, 9, 15),
      categoryName: 'Mercado',
      reflection: TransactionReflection(
        id: 'reflection-1',
        spaceId: 'space',
        eventId: 'reflected',
        type: ReflectionType.necessary,
        note: 'compra da semana',
        createdAt: DateTime(2026, 9, 15),
        updatedAt: DateTime(2026, 9, 15),
      ),
    );
    final pending = DiaryEntry(
      eventId: 'pending',
      eventType: 'expense',
      description: 'Café pendente',
      amount: 18,
      occurredAt: DateTime(2026, 9, 16),
      categoryName: 'Café',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          repository: _FakeRepository(),
          spaceId: 'space',
          loadOverride: ({required spaceId, required periodMonth}) async => [
            reflected,
            pending,
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('seu mês'), findsWidgets);
    expect(find.text('para refletir'), findsOneWidget);
    expect(find.text('suas reflexões'), findsOneWidget);
    expect(find.text('Mercado refletido'), findsOneWidget);

    final summaryPosition = tester.getTopLeft(find.text('seu mês').first);
    final reflectionsPosition = tester.getTopLeft(find.text('suas reflexões'));
    expect(reflectionsPosition.dx, greaterThan(summaryPosition.dx));

    final reflectionInkWell = find.ancestor(
      of: find.text('Mercado refletido'),
      matching: find.byType(InkWell),
    );
    expect(reflectionInkWell, findsOneWidget);
    await tester.tap(find.text('Mercado refletido'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('editar reflexão'), findsOneWidget);
  });
}

class _FakeRepository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
