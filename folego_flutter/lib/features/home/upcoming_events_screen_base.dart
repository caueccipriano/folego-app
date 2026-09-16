import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/recurring_item.dart';
import '../../data/models/upcoming_financial_event.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_agenda.dart';
import '../transactions/recurring_form_sheet.dart';
import '../wallet/wallet_detail_screen.dart';

class UpcomingEventsScreen extends StatelessWidget {
  const UpcomingEventsScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  Widget build(BuildContext context) {
    return RealtimeRefreshView(
      domain: AppRealtimeDomain.home,
      identity: 'agenda:$spaceId',
      builder: (key) => _FinancialAgendaBody(
        key: key,
        repository: repository,
        spaceId: spaceId,
      ),
    );
  }
}

class _FinancialAgendaBody extends StatefulWidget {
  const _FinancialAgendaBody({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<_FinancialAgendaBody> createState() => _FinancialAgendaBodyState();
}

class _FinancialAgendaBodyState extends State<_FinancialAgendaBody> {
  bool _loading = true;
  String? _error;
  String? _realizingKey;
  AgendaFilter _filter = AgendaFilter.all;
  List<UpcomingFinancialEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final events = await widget.repository.getFinancialAgenda(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<UpcomingFinancialEvent> get _visibleEvents => _events
      .where((event) => event.matches(_filter))
      .toList(growable: false);

  Future<void> _openEvent(UpcomingFinancialEvent event) async {
    if (event.isRecurring) {
      final items = await widget.repository.listRecurringItems(widget.spaceId);
      RecurringItem? selected;
      for (final item in items) {
        if (item.id == event.sourceId) {
          selected = item;
          break;
        }
      }
      if (!mounted || selected == null) return;
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => RecurringFormSheet(
          space: FinancialSpace(id: widget.spaceId, name: ''),
          repository: widget.repository,
          item: selected,
        ),
      );
      if (saved == true && mounted) await _load();
      return;
    }

    final overview = await widget.repository.getWalletOverview(
      spaceId: widget.spaceId,
    );
    if (!mounted) return;

    if (event.isInvoice && event.cardId != null) {
      WalletCard? card;
      for (final item in overview.cards) {
        if (item.id == event.cardId) {
          card = item;
          break;
        }
      }
      if (card == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WalletCardDetailScreen(
            repository: widget.repository,
            spaceId: widget.spaceId,
            card: card!,
          ),
        ),
      );
    } else if (event.isDebt && event.debtId != null) {
      WalletDebt? debt;
      for (final item in overview.debts) {
        if (item.id == event.debtId) {
          debt = item;
          break;
        }
      }
      if (debt == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WalletDebtDetailScreen(
            repository: widget.repository,
            spaceId: widget.spaceId,
            debt: debt!,
          ),
        ),
      );
    }

    if (mounted) await _load();
  }

  Future<void> _realize(UpcomingFinancialEvent event) async {
    if (!event.isRecurring || _realizingKey != null) return;
    final verb = event.isIncome ? 'recebido' : 'realizado';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(event.isIncome ? 'Marcar como recebido?' : 'Realizar agora?'),
        content: Text(
          '${event.title}\n${Formatters.money(event.amount)}\n\n'
          'A previsão será transformada no lançamento canônico correspondente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(event.isIncome ? 'recebi' : 'realizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _realizingKey = event.eventKey);
    try {
      await widget.repository.realizeRecurring(
        spaceId: widget.spaceId,
        itemId: event.sourceId,
        dueDate: event.dueDate,
        amount: event.amount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${event.title} $verb.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('não consegui atualizar: $error')),
      );
    } finally {
      if (mounted) setState(() => _realizingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      appBar: AppBar(
        title: Text(
          'agenda',
          style: AppTypography.display(
            context,
            fontSize: 24,
            color: AppColors.primaryText(brightness),
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: AppContentContainer.list(
        fillHeight: true,
        child: _buildBody(brightness),
      ),
    );
  }

  Widget _buildBody(Brightness brightness) {
    if (_loading && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.warning, size: 42),
            const SizedBox(height: 12),
            Text(
              'não consegui carregar sua agenda',
              style: AppTypography.section(context, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('tentar novamente')),
          ],
        ),
      );
    }

    final visible = _visibleEvents;
    final summary = AgendaSummary.nextDays(_events);
    final grouped = <AgendaSection, List<UpcomingFinancialEvent>>{};
    for (final event in visible) {
      grouped.putIfAbsent(event.section, () => []).add(event);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 48),
        children: [
          _AgendaHero(summary: summary),
          const SizedBox(height: 22),
          Text(
            'o que vem pela frente',
            style: AppTypography.section(
              context,
              fontSize: 20,
              color: AppColors.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'obrigações e entradas reais, sem contar a mesma saída duas vezes',
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: AppColors.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AgendaFilter.values.map((filter) {
                final selected = _filter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(agendaFilterLabel(filter)),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 20),
          if (visible.isEmpty)
            const _AgendaEmpty()
          else
            for (final section in AgendaSection.values)
              if (grouped[section]?.isNotEmpty == true) ...[
                _AgendaSectionHeader(
                  label: agendaSectionLabel(section),
                  count: grouped[section]!.length,
                  overdue: section == AgendaSection.overdue,
                ),
                const SizedBox(height: 9),
                ...grouped[section]!.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _AgendaEventCard(
                      event: event,
                      realizing: _realizingKey == event.eventKey,
                      onTap: () => _openEvent(event),
                      onRealize: event.isRecurring ? () => _realize(event) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
              ],
        ],
      ),
    );
  }
}

class _AgendaHero extends StatelessWidget {
  const _AgendaHero({required this.summary});

  final AgendaSummary summary;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final purple = AppColors.primaryPurple(brightness);
    final onPurple = brightness == Brightness.dark
        ? AppColors.iconOnPurpleDark
        : AppColors.iconOnPurpleLight;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: purple,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'próximos 7 dias',
            style: AppTypography.label(
              context,
              fontSize: 12,
              color: onPurple.withValues(alpha: .78),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'um mapa curto do que já está previsto',
            style: AppTypography.section(
              context,
              fontSize: 21,
              color: onPurple,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AgendaHeroMetric(
                icon: AppIcons.expense,
                label: '${summary.outflowCount} saídas',
                value: Formatters.money(summary.outflowAmount),
              ),
              _AgendaHeroMetric(
                icon: AppIcons.income,
                label: '${summary.incomeCount} entradas',
                value: Formatters.money(summary.incomeAmount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgendaHeroMetric extends StatelessWidget {
  const _AgendaHeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgendaSectionHeader extends StatelessWidget {
  const _AgendaSectionHeader({
    required this.label,
    required this.count,
    required this.overdue,
  });
  final String label;
  final int count;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      children: [
        Icon(
          overdue ? AppIcons.warning : AppIcons.calendar,
          size: 17,
          color: overdue
              ? AppColors.expenseText(brightness)
              : AppColors.secondaryText(brightness),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: AppTypography.label(
            context,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText(brightness),
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: AppTypography.label(
            context,
            fontSize: 11,
            color: AppColors.secondaryText(brightness),
          ),
        ),
      ],
    );
  }
}

class _AgendaEventCard extends StatelessWidget {
  const _AgendaEventCard({
    required this.event,
    required this.realizing,
    required this.onTap,
    this.onRealize,
  });
  final UpcomingFinancialEvent event;
  final bool realizing;
  final VoidCallback onTap;
  final VoidCallback? onRealize;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final accent = event.isIncome
        ? AppColors.positiveText(brightness)
        : event.isInvoice
        ? AppColors.primaryPurple(brightness)
        : event.isDebt
        ? AppColors.expenseText(brightness)
        : secondary;
    final icon = event.isIncome
        ? AppIcons.income
        : event.isInvoice
        ? AppIcons.creditCard
        : event.isDebt
        ? AppIcons.debt
        : AppIcons.recurring;
    final prefix = event.isIncome
        ? '+'
        : event.isOutflow && event.cashObligation
        ? '-'
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface(brightness),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border(brightness)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$prefix${Formatters.money(event.amount)}',
                          style: AppTypography.label(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: event.isInformational ? primary : accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.subtitle.isEmpty
                          ? event.sourceLabel
                          : event.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          _dateText(event),
                          style: AppTypography.label(
                            context,
                            fontSize: 10,
                            color: event.overdue
                                ? AppColors.expenseText(brightness)
                                : secondary,
                          ),
                        ),
                        if (event.isInformational) ...[
                          const SizedBox(width: 8),
                          Text(
                            'compromisso · não soma cash agora',
                            style: AppTypography.label(
                              context,
                              fontSize: 10,
                              color: secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onRealize != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: event.isIncome ? 'marcar recebido' : 'realizar',
                  onPressed: realizing ? null : onRealize,
                  icon: realizing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.check, size: 18),
                ),
              ] else
                Icon(AppIcons.chevronRight, size: 18, color: secondary),
            ],
          ),
        ),
      ),
    );
  }

  String _dateText(UpcomingFinancialEvent event) {
    if (event.overdue) return 'atrasado · ${Formatters.shortDate.format(event.dueDate)}';
    if (event.dayOffset == 0) return 'hoje';
    if (event.dayOffset == 1) return 'amanhã';
    return Formatters.shortDate.format(event.dueDate);
  }
}

class _AgendaEmpty extends StatelessWidget {
  const _AgendaEmpty();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        children: [
          Icon(AppIcons.calendar, size: 34, color: AppColors.secondaryText(brightness)),
          const SizedBox(height: 12),
          Text(
            'nada apertando por enquanto',
            textAlign: TextAlign.center,
            style: AppTypography.section(
              context,
              fontSize: 18,
              color: AppColors.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'quando surgir uma recorrência, fatura ou parcela de dívida, ela aparece aqui',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: AppColors.secondaryText(brightness),
            ),
          ),
        ],
      ),
    );
  }
}
