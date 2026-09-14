import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/transactions/recurring_occurrence.dart';

void main() {
  group('suggestMonthlyOccurrenceDate', () {
    test('uses one of the configured monthly days', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2026, 9, 14),
        startsOn: DateTime(2026, 1, 1),
        endsOn: null,
        monthlyDays: const [5, 20],
        monthlyLastDay: false,
        dayOfMonth: 5,
      );

      expect(result, DateTime(2026, 9, 5));
    });

    test('uses February 28 as last day in a non-leap year', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2025, 2, 15),
        startsOn: DateTime(2025, 1, 1),
        endsOn: null,
        monthlyDays: const [],
        monthlyLastDay: true,
        dayOfMonth: null,
      );

      expect(result, DateTime(2025, 2, 28));
    });

    test('uses February 29 as last day in a leap year', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2024, 2, 15),
        startsOn: DateTime(2024, 1, 1),
        endsOn: null,
        monthlyDays: const [],
        monthlyLastDay: true,
        dayOfMonth: null,
      );

      expect(result, DateTime(2024, 2, 29));
    });

    test('uses April 30 as last day', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2026, 4, 15),
        startsOn: DateTime(2026, 1, 1),
        endsOn: null,
        monthlyDays: const [],
        monthlyLastDay: true,
        dayOfMonth: null,
      );

      expect(result, DateTime(2026, 4, 30));
    });

    test('considers fixed days and last day together', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2026, 9, 30),
        startsOn: DateTime(2026, 1, 1),
        endsOn: null,
        monthlyDays: const [5, 20],
        monthlyLastDay: true,
        dayOfMonth: 5,
      );

      expect(result, DateTime(2026, 9, 30));
    });

    test('does not suggest an occurrence before startsOn', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2026, 9, 14),
        startsOn: DateTime(2026, 9, 10),
        endsOn: null,
        monthlyDays: const [5, 20],
        monthlyLastDay: false,
        dayOfMonth: 5,
      );

      expect(result, DateTime(2026, 9, 20));
    });

    test('does not suggest an occurrence after endsOn', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2026, 9, 25),
        startsOn: DateTime(2026, 1, 1),
        endsOn: DateTime(2026, 9, 10),
        monthlyDays: const [5, 20],
        monthlyLastDay: false,
        dayOfMonth: 5,
      );

      expect(result, DateTime(2026, 9, 5));
    });

    test('keeps legacy dayOfMonth fallback', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2026, 9, 14),
        startsOn: DateTime(2026, 1, 1),
        endsOn: null,
        monthlyDays: const [],
        monthlyLastDay: false,
        dayOfMonth: 12,
      );

      expect(result, DateTime(2026, 9, 12));
    });

    test('falls back to startsOn day for legacy records without dayOfMonth', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2026, 9, 14),
        startsOn: DateTime(2026, 1, 7),
        endsOn: null,
        monthlyDays: const [],
        monthlyLastDay: false,
        dayOfMonth: null,
      );

      expect(result, DateTime(2026, 9, 7));
    });

    test('does not clamp day 31 into a shorter month', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2025, 2, 15),
        startsOn: DateTime(2025, 1, 1),
        endsOn: null,
        monthlyDays: const [31],
        monthlyLastDay: false,
        dayOfMonth: 31,
      );

      expect(result, DateTime(2025, 1, 31));
    });

    test('returns null when no occurrence exists inside the recurrence bounds', () {
      final result = suggestMonthlyOccurrenceDate(
        referenceDate: DateTime(2026, 9, 14),
        startsOn: DateTime(2026, 9, 6),
        endsOn: DateTime(2026, 9, 10),
        monthlyDays: const [5, 20],
        monthlyLastDay: false,
        dayOfMonth: 5,
      );

      expect(result, isNull);
    });
  });
}
