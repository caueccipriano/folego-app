import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/upcoming_financial_event.dart';
import 'agenda_calendar_month.dart';

/// Calendar of pending agenda events, never an inferred bank statement.
class AgendaCalendarGrid extends StatelessWidget {
  const AgendaCalendarGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.events,
    required this.onSelectDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final DateTime selectedDay;
  final List<UpcomingFinancialEvent> events;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    final days = AgendaCalendarMonth.cells(month);
    const weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    return Container(
      key: const ValueKey('agenda-calendar-grid'),
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 14),
      decoration: BoxDecoration(
        color: tokens.superficie,
        border: Border.all(color: tokens.borda),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            IconButton(
              key: const ValueKey('agenda-calendar-previous'),
              tooltip: 'mês anterior',
              onPressed: onPreviousMonth,
              icon: const Icon(AppIcons.chevronLeft, size: 19),
            ),
            Expanded(
              child: Text(
                Formatters.monthYear.format(month),
                key: const ValueKey('agenda-calendar-month'),
                textAlign: TextAlign.center,
                style: AppTypography.section(context, fontSize: 17),
              ),
            ),
            IconButton(
              key: const ValueKey('agenda-calendar-next'),
              tooltip: 'próximo mês',
              onPressed: onNextMonth,
              icon: const Icon(AppIcons.chevronRight, size: 19),
            ),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            for (final weekday in weekdays)
              Expanded(child: Center(child: Text(weekday,
                style: AppTypography.label(context, fontSize: 10,
                  color: tokens.textoSecundario)))),
          ]),
          const SizedBox(height: 5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4,
              childAspectRatio: .90,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              if (day == null) return const SizedBox.shrink();
              final isSelected = AgendaCalendarMonth.sameDay(day, selectedDay);
              final daily = AgendaCalendarMonth.eventsForDay(events, day);
              final hasIncome = daily.any((item) => item.isIncome);
              final hasOutflow = daily.any((item) =>
                  item.isOutflow && item.cashObligation);
              return Semantics(
                button: true,
                selected: isSelected,
                label: 'dia ${day.day}, ${daily.length} compromissos carregados',
                child: InkWell(
                  key: ValueKey('agenda-calendar-day-${day.day}'),
                  onTap: () => onSelectDay(day),
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? tokens.marca : tokens.fundo,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: isSelected
                          ? tokens.marca : tokens.borda),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${day.day}', style: AppTypography.label(
                          context,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? tokens.marcaSobre
                              : tokens.textoPrincipal,
                        )),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasIncome) _dot(isSelected
                                ? tokens.marcaSobre : tokens.folga),
                            if (hasIncome && hasOutflow)
                              const SizedBox(width: 3),
                            if (hasOutflow) _dot(isSelected
                                ? tokens.marcaSobre : tokens.estourado),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(tokens.folga), const SizedBox(width: 5),
              Text('entrada prevista', style: AppTypography.label(
                context, fontSize: 11, color: tokens.textoSecundario)),
              const SizedBox(width: 15),
              _dot(tokens.estourado), const SizedBox(width: 5),
              Text('saída prevista', style: AppTypography.label(
                context, fontSize: 11, color: tokens.textoSecundario)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 6, height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
