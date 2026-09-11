import 'package:flutter/material.dart';

import '../../data/models/upcoming_events.dart';
import '../../data/repositories/folego_repository.dart';

class UpcomingEventsScreen extends StatefulWidget {
  const UpcomingEventsScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<UpcomingEventsScreen> createState() => _UpcomingEventsScreenState();
}

class _UpcomingEventsScreenState extends State<UpcomingEventsScreen> {
  static const _purple = Color(0xFF6C3BF0);
  static const _lime = Color(0xFFC6F135);

  bool _loading = true;
  bool _realizing = false;
  String? _error;
  List<UpcomingEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final events = await widget.repository.getUpcomingEvents(
        widget.spaceId,
        days: 30,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  double get _totalIncome {
    return _events
        .where((event) => event.isIncome)
        .fold(0, (total, event) => total + event.amount);
  }

  double get _totalExpenses {
    return _events
        .where((event) => event.isExpense)
        .fold(0, (total, event) => total + event.amount);
  }

  double get _forecastBalance {
    return _totalIncome - _totalExpenses;
  }

  String _money(double value) {
    final negative = value < 0;
    final absolute = value.abs();

    final parts = absolute.toStringAsFixed(2).split('.');
    final integer = parts.first;
    final decimal = parts.last;

    final reversed = integer.split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;

      groups.add(reversed.sublist(i, end).reversed.join());
    }

    final formattedInteger = groups.reversed.join('.');

    return '${negative ? '-' : ''}'
        'R\$ $formattedInteger,$decimal';
  }

  String _dateLabel(DateTime date) {
    final today = DateTime.now();

    final normalizedToday = DateTime(today.year, today.month, today.day);

    final normalizedDate = DateTime(date.year, date.month, date.day);

    final difference = normalizedDate.difference(normalizedToday).inDays;

    if (difference == 0) {
      return 'Hoje';
    }

    if (difference == 1) {
      return 'Amanhã';
    }

    const weekdays = [
      'segunda',
      'terça',
      'quarta',
      'quinta',
      'sexta',
      'sábado',
      'domingo',
    ];

    const months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];

    return '${weekdays[date.weekday - 1]}, '
        '${date.day} ${months[date.month - 1]}';
  }

  String _compactDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  IconData _eventIcon(UpcomingEvent event) {
    if (event.isIncome) {
      return Icons.payments_rounded;
    }

    switch (event.source) {
      case 'invoice':
        return Icons.credit_card_rounded;

      case 'debt':
        return Icons.account_balance_wallet_rounded;

      case 'recurring':
        return Icons.event_repeat_rounded;

      default:
        return Icons.calendar_today_rounded;
    }
  }

  Color _eventColor(UpcomingEvent event) {
    if (event.isIncome) {
      return const Color(0xFF368C45);
    }

    switch (event.source) {
      case 'invoice':
        return _purple;

      case 'debt':
        return const Color(0xFFED7A3B);

      default:
        return const Color(0xFF6A6A75);
    }
  }

  Map<DateTime, List<UpcomingEvent>> get _groupedEvents {
    final result = <DateTime, List<UpcomingEvent>>{};

    for (final event in _events) {
      final date = DateTime(
        event.dueDate.year,
        event.dueDate.month,
        event.dueDate.day,
      );

      result.putIfAbsent(date, () => []);

      result[date]!.add(event);
    }

    return result;
  }

  Future<void> _realizeEvent(UpcomingEvent event) async {
    if (!event.isRecurring || _realizing) {
      return;
    }

    final action = event.isIncome ? 'recebido' : 'pago';

    final actionTitle = event.isIncome
        ? 'Marcar como recebido?'
        : 'Marcar como pago?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(actionTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _money(event.amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Isso vai transformar esta previsão '
                'em um lançamento real.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(event.isIncome ? 'Recebi' : 'Paguei'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _realizing = true;
    });

    try {
      await widget.repository.realizeRecurring(
        spaceId: widget.spaceId,
        itemId: event.id,
        dueDate: event.dueDate,
        amount: event.amount,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${event.name} marcado como $action.')),
      );

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não consegui atualizar: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _realizing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Agenda financeira',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 44),
                  const SizedBox(height: 14),
                  const Text(
                    'Não consegui carregar sua agenda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 600;

          final horizontalPadding = isPhone ? 16.0 : 24.0;

          return RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          0,
                        ),
                        child: _buildSummary(isPhone: isPhone),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          26,
                          horizontalPadding,
                          14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Próximos 30 dias',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'O que já está previsto '
                                    'para entrar e sair.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: .58),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${_events.length} '
                                '${_events.length == 1 ? 'previsto' : 'previstos'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if (_events.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: _buildEmpty(),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildListDelegate(
                      _buildDateSections(horizontalPadding: horizontalPadding),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary({required bool isPhone}) {
    final positive = _forecastBalance >= 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isPhone ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7444F4), Color(0xFF5A22E8)],
        ),
        borderRadius: BorderRadius.circular(isPhone ? 24 : 28),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: .18),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu dinheiro nos próximos dias',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            positive ? 'Previsão positiva' : 'Atenção aos próximos dias',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: _summaryValue(label: 'Entram', value: _totalIncome),
              ),
              SizedBox(width: isPhone ? 12 : 18),
              Expanded(
                child: _summaryValue(label: 'Saem', value: _totalExpenses),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .10)),
            ),
            child: isPhone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo previsto',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .76),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _money(_forecastBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Saldo previsto',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .76),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _money(_forecastBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryValue({required String label, required double value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .72),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _money(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDateSections({required double horizontalPadding}) {
    final grouped = _groupedEvents;
    final dates = grouped.keys.toList()..sort();

    return dates.map((date) {
      final events = grouped[date]!;

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _compactDate(date),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _dateLabel(date),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: .30),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < events.length; i++) ...[
                        _buildEvent(events[i]),
                        if (i < events.length - 1)
                          Divider(
                            height: 1,
                            indent: 70,
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: .25),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildEvent(UpcomingEvent event) {
    final color = _eventColor(event);
    final canRealize = event.isRecurring;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canRealize && !_realizing ? () => _realizeEvent(event) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_eventIcon(event), size: 21, color: color),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      canRealize
                          ? '${event.sourceLabel} · toque para confirmar'
                          : event.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .56),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${event.isIncome ? '+' : '-'}'
                  '${_money(event.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: event.isIncome
                        ? const Color(0xFF368C45)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              if (canRealize) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _lime.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.event_available_rounded, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nada previsto por enquanto',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            'Suas recorrências, faturas e parcelas '
            'dos próximos dias vão aparecer aqui.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .58),
            ),
          ),
        ],
      ),
    );
  }
}
