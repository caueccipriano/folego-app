import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/upcoming_financial_event.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/data/repositories/folego_repository_agenda.dart';
import 'package:folego/features/home/agenda_calendar_month.dart';
import 'package:folego/features/home/agenda_calendar_grid.dart';
import 'package:folego/features/home/upcoming_events_screen.dart';

class _TestRepository implements FolegoRepository {
  const _TestRepository();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UpcomingFinancialEvent _event(
  String name, DateTime date, double amount, {
  UpcomingEventDirection direction = UpcomingEventDirection.outflow,
  bool cash = true,
}) => UpcomingFinancialEvent(
  eventKey: name,
  source: UpcomingEventSource.recurring,
  sourceId: name,
  title: name,
  subtitle: '',
  dueDate: date,
  amount: amount,
  direction: direction,
  status: 'pending',
  overdue: false,
  realized: false,
  recurring: false,
  dayOffset: 7,
  cashObligation: cash,
  navigationTarget: '',
);

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));
  tearDown(() {
    debugFinancialAgendaLoader = null;
    FinancialPrivacy.hidden.value = false;
  });

  test('calendar starts Monday and handles month boundaries', () {
    final nov = AgendaCalendarMonth.cells(DateTime(2026, 11));
    expect(nov.length, 42);
    expect(nov.take(6).every((day) => day == null), isTrue);
    expect(nov[6], DateTime(2026, 11, 1));
    expect(nov.last, isNull);
    final feb = AgendaCalendarMonth.cells(DateTime(2028, 2));
    expect(feb.whereType<DateTime>().length, 29);
    expect(AgendaCalendarMonth.lastDay(DateTime(2028, 2)),
        DateTime(2028, 2, 29));
  });

  test('only confirmed cash outflows contribute to expected payments', () {
    final date = DateTime(2026, 11, 14);
    final items = [
      _event('salário', date, 2300,
          direction: UpcomingEventDirection.income),
      _event('energia', date, 160),
      _event('cartão informativo', date, 100, cash: false),
      _event('aluguel', DateTime(2026, 11, 15), 900),
    ];
    final day = AgendaCalendarMonth.eventsForDay(items, date);
    expect(day.length, 3);
    expect(AgendaCalendarMonth.incomeForDay(day), 2300);
    expect(AgendaCalendarMonth.outflowForDay(day), 160);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('month grid on iPhone $width selects the right day',
        (tester) async {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = DateTime(2026, 11, 5);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(
          child: StatefulBuilder(builder: (context, refresh) =>
            AgendaCalendarGrid(
              month: DateTime(2026, 11),
              selectedDay: selected,
              events: [_event('salário', DateTime(2026, 11, 14), 2500,
                  direction: UpcomingEventDirection.income)],
              onSelectDay: (day) => refresh(() => selected = day),
              onPreviousMonth: () {},
              onNextMonth: () {},
            ),
          ),
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agenda-calendar-grid')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('agenda-calendar-day-14')));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 11, 14));
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('Agenda calendar fetches month and opens day at $width',
        (tester) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scopedQueries = <(DateTime?, DateTime?, int)>[];
    debugFinancialAgendaLoader = ({
      required spaceId, startDate, endDate, required limit,
    }) async {
      scopedQueries.add((startDate, endDate, limit));
      return [
        _event('Pagamento energia', DateTime(2026, 11, 14), 160),
        _event('Salário previsto', DateTime(2026, 11, 14), 2300,
          direction: UpcomingEventDirection.income),
      ];
    };
    await tester.pumpWidget(MaterialApp(
      home: UpcomingEventsScreen(
        repository: const _TestRepository(),
        spaceId: 'test',
        initialDate: DateTime(2026, 11, 5),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('agenda-view-calendar')));
    await tester.tap(find.byKey(const ValueKey('agenda-view-calendar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-calendar-grid')), findsOneWidget);
    expect(scopedQueries.any((q) =>
        q.$1 == DateTime(2026, 11, 1) &&
        q.$2 == DateTime(2026, 11, 30) && q.$3 == 200), isTrue);

    // The calendar is nested inside Agenda's scrollable timeline.
    // Move the outer list, not the non-scrollable seven-column grid.
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agenda-calendar-day-14')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.text('Pagamento energia'), findsOneWidget);
    expect(find.text('Salário previsto'), findsOneWidget);
    final layoutFailure = tester.takeException();
    if (layoutFailure != null) {
      debugPrint('AGENDA_LAYOUT_DIAGNOSTIC: $layoutFailure');
      for (final flex in tester.allRenderObjects.whereType<RenderFlex>()) {
        if (flex.direction != Axis.horizontal || !flex.hasSize) continue;
        var child = flex.firstChild;
        var rightmost = 0.0;
        while (child != null) {
          final data = child.parentData as FlexParentData;
          if (child.hasSize) {
            final right = data.offset.dx + child.size.width;
            if (right > rightmost) rightmost = right;
          }
          child = flex.childAfter(child);
        }
        if (rightmost > flex.size.width + 1) {
          debugPrint(
            'AGENDA_OVERFLOW_ROW: width=${flex.size.width.toStringAsFixed(1)} '
            'childrenEnd=${rightmost.toStringAsFixed(1)} '
            'creator=${flex.debugCreator}',
          );
        }
      }
    }
    expect(layoutFailure, isNull);
    });
  }
}
