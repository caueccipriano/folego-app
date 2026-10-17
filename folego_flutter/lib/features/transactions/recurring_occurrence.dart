DateTime? suggestMonthlyOccurrenceDate({
  required DateTime referenceDate,
  required DateTime startsOn,
  required DateTime? endsOn,
  required List<int> monthlyDays,
  required bool monthlyLastDay,
  required int? dayOfMonth,
}) {
  final reference = _dateOnly(referenceDate);
  final start = _dateOnly(startsOn);
  final end = endsOn == null ? null : _dateOnly(endsOn);

  if (end != null && end.isBefore(start)) {
    return null;
  }

  final fixedDays = monthlyDays
      .where((day) => day >= 1 && day <= 31)
      .toSet()
      .toList()
    ..sort();

  if (fixedDays.isEmpty && !monthlyLastDay) {
    final legacyDay = dayOfMonth != null && dayOfMonth >= 1 && dayOfMonth <= 31
        ? dayOfMonth
        : start.day;

    fixedDays.add(legacyDay);
  }

  final referenceMonth = _monthIndex(reference);
  final startMonth = _monthIndex(start);
  final endMonth = end == null ? null : _monthIndex(end);

  final currentCandidates = _boundedCandidatesForMonth(
    monthIndex: referenceMonth,
    fixedDays: fixedDays,
    monthlyLastDay: monthlyLastDay,
    start: start,
    end: end,
  );

  if (currentCandidates.isNotEmpty) {
    final notAfterReference = currentCandidates
        .where((candidate) => !candidate.isAfter(reference))
        .toList();

    if (notAfterReference.isNotEmpty) {
      return notAfterReference.last;
    }

    return currentCandidates.first;
  }

  for (var month = referenceMonth - 1; month >= startMonth; month--) {
    final candidates = _boundedCandidatesForMonth(
      monthIndex: month,
      fixedDays: fixedDays,
      monthlyLastDay: monthlyLastDay,
      start: start,
      end: end,
    );

    if (candidates.isNotEmpty) {
      return candidates.last;
    }
  }

  var firstForwardMonth = referenceMonth + 1;
  if (firstForwardMonth < startMonth) {
    firstForwardMonth = startMonth;
  }

  // Qualquer configuração mensal válida (dia 1–31 ou último dia) produz uma
  // ocorrência em no máximo poucos meses. O limite defensivo só se aplica
  // quando não existe endsOn, evitando loop infinito em dados corrompidos.
  final lastForwardMonth = endMonth ?? firstForwardMonth + 24;

  for (
    var month = firstForwardMonth;
    month <= lastForwardMonth;
    month++
  ) {
    final candidates = _boundedCandidatesForMonth(
      monthIndex: month,
      fixedDays: fixedDays,
      monthlyLastDay: monthlyLastDay,
      start: start,
      end: end,
    );

    if (candidates.isNotEmpty) {
      return candidates.first;
    }
  }

  return null;
}

List<DateTime> _boundedCandidatesForMonth({
  required int monthIndex,
  required List<int> fixedDays,
  required bool monthlyLastDay,
  required DateTime start,
  required DateTime? end,
}) {
  final year = monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;

  final candidateDays = <int>{
    for (final day in fixedDays)
      if (day <= lastDay) day,
    if (monthlyLastDay) lastDay,
  }.toList()
    ..sort();

  return candidateDays
      .map((day) => DateTime(year, month, day))
      .where(
        (candidate) =>
            !candidate.isBefore(start) &&
            (end == null || !candidate.isAfter(end)),
      )
      .toList();
}

int _monthIndex(DateTime date) => date.year * 12 + date.month - 1;

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
