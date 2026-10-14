import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Agenda groups canonical events by month without changing payment actions', () {
    final source = File('lib/features/home/upcoming_events_screen_base.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('agenda-view-month')"));
    expect(source, contains("ValueKey('agenda-view-urgency')"));
    expect(source, contains('DateTime(event.dueDate.year, event.dueDate.month)'));
    expect(source, contains('Formatters.monthYear.format(month)'));
    expect(source, contains('await widget.repository.getFinancialAgenda(widget.spaceId)'));
    expect(source, contains('onRealize: event.isRecurring ? () => _realize(event) : null'));
  });
}
