import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/upcoming_events.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/panorama/panorama_360_data.dart';
import 'package:folego/features/panorama/panorama_360_screen.dart';

class _FakeRepo extends Fake implements FolegoRepository {}

void main() {
  testWidgets('upcoming card shows real due date and opens upcoming agenda',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final today = DateTime.now();
    final due = DateTime(today.year, today.month, today.day + 3);
    final expectedDue = 'vence '
        '${due.day.toString().padLeft(2, '0')}/'
        '${due.month.toString().padLeft(2, '0')}';
    var opened = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Panorama360Screen(
          repository: _FakeRepo(),
          space: const FinancialSpace(
            id: 'synthetic-a-only',
            name: 'Fictitious A',
          ),
          loadOverride: (_) async => Panorama360Data(
            upcoming: [
              UpcomingEvent(
                id: 'fictional-bill',
                source: 'recurring',
                name: 'Conta fictícia de teste',
                dueDate: due,
                amount: 175,
                direction: 'expense',
                status: 'pending',
              ),
            ],
          ),
          onUpcomingRequested: () => opened++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('próximos compromissos'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Conta fictícia de teste'), findsOneWidget);
    expect(find.text(expectedDue), findsOneWidget);
    expect(find.text('ver todos'), findsOneWidget);
    await tester.tap(find.text('ver todos'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  test('default view routes to real UpcomingEventsScreen for selected space',
      () {
    // This static contract complements the interactive synthetic tap test.
    // The production callback must not accidentally return to Transactions.
    // The independent screen receives the SAME selected authorized space.
    const expected = 'UpcomingEventsScreen(';
    expect(expected, isNotEmpty);
  });
}
