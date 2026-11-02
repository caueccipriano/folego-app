/// Rótulo curto para agrupar movimentos por dia civil, nunca por semana.
/// O cálculo em UTC evita que transições de horário de verão mudem o dia.
String transactionDayLabel(DateTime occurredAt, {DateTime? referenceDate}) {
  final now = referenceDate ?? DateTime.now();
  final day = DateTime.utc(occurredAt.year, occurredAt.month, occurredAt.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final delta = today.difference(day).inDays;

  const months = <String>[
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  const weekdays = <String>[
    'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom',
  ];

  final date = '${occurredAt.day.toString().padLeft(2, '0')} '
      '${months[occurredAt.month - 1]}'
      '${occurredAt.year == now.year ? '' : ' ${occurredAt.year}'}';
  if (delta == 0) return 'hoje · $date';
  if (delta == 1) return 'ontem · $date';
  return '${weekdays[day.weekday - 1]} · $date';
}
