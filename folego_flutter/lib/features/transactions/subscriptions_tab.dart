import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/recurring_item.dart';

typedef SubscriptionItemAction = Future<void> Function(RecurringItem item);

class SubscriptionsTab extends StatelessWidget {
  const SubscriptionsTab({
    super.key,
    required this.items,
    required this.recurringCandidates,
    required this.cardNames,
    required this.onRefresh,
    required this.onEdit,
    required this.onEnd,
    required this.onClassify,
    required this.onMoveToRecurring,
  });

  final List<RecurringItem> items;
  final List<RecurringItem> recurringCandidates;
  final Map<String, String> cardNames;
  final Future<void> Function() onRefresh;
  final SubscriptionItemAction onEdit;
  final SubscriptionItemAction onEnd;
  final SubscriptionItemAction onClassify;
  final SubscriptionItemAction onMoveToRecurring;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final active = items.where((item) => item.active).toList(growable: false);
    final monthly = active.fold<double>(
      0,
      (sum, item) => sum + subscriptionMonthlyEquivalent(item),
    );

    return AppContentContainer.list(
      fillHeight: true,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          key: ValueKey(
            AppBreakpoints.of(context) == AppLayoutSize.compact
                ? 'subscriptions-mobile-layout'
                : 'subscriptions-desktop-layout',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 120),
          children: [
            _SubscriptionHeader(
              monthlyEquivalent: monthly,
              activeCount: active.length,
              canClassify: recurringCandidates.isNotEmpty,
              onClassify: () => _pickRecurring(context),
            ),
            const SizedBox(height: 20),
            if (items.isEmpty)
              _EmptySubscriptions(
                canClassify: recurringCandidates.isNotEmpty,
                onClassify: () => _pickRecurring(context),
              )
            else
              for (final item in items) ...[
                _SubscriptionCard(
                  item: item,
                  cardName: item.cardId == null ? null : cardNames[item.cardId!],
                  onEdit: () => onEdit(item),
                  onEnd: item.active ? () => _confirmEnd(context, item) : null,
                  onMoveToRecurring: () => onMoveToRecurring(item),
                ),
                const SizedBox(height: 10),
              ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'O total mensal é uma equivalência para comparação. O valor e a frequência originais continuam preservados em cada assinatura.',
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: AppColors.secondaryText(brightness),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickRecurring(BuildContext context) async {
    final candidates = recurringCandidates
        .where((item) => item.isExpense)
        .toList(growable: false);
    if (candidates.isEmpty) return;

    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
    final selected = compact
        ? await showModalBottomSheet<RecurringItem>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            builder: (_) => _RecurringCandidatePicker(items: candidates),
          )
        : await showDialog<RecurringItem>(
            context: context,
            builder: (_) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
                child: _RecurringCandidatePicker(items: candidates),
              ),
            ),
          );
    if (selected != null) await onClassify(selected);
  }

  Future<void> _confirmEnd(BuildContext context, RecurringItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('encerrar acompanhamento?'),
        content: Text(
          '${item.name} deixará de entrar nas próximas previsões do Fôlego.\n\n'
          'Isso não cancela o serviço com o fornecedor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('manter ativa'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('marcar como encerrada'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onEnd(item);
  }
}

class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader({
    required this.monthlyEquivalent,
    required this.activeCount,
    required this.canClassify,
    required this.onClassify,
  });

  final double monthlyEquivalent;
  final int activeCount;
  final bool canClassify;
  final VoidCallback onClassify;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'assinaturas',
                  style: AppTypography.section(context, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  '${Formatters.money(monthlyEquivalent)} / mês',
                  style: AppTypography.money(context, fontSize: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeCount assinatura${activeCount == 1 ? '' : 's'} ativa${activeCount == 1 ? '' : 's'} · equivalente mensal',
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: AppColors.secondaryText(brightness),
                  ),
                ),
              ],
            ),
          ),
          if (canClassify) ...[
            const SizedBox(width: 12),
            OutlinedButton.icon(
              key: const ValueKey('subscription-classify-action'),
              onPressed: onClassify,
              icon: const Icon(AppIcons.add, size: 17),
              label: const Text('classificar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySubscriptions extends StatelessWidget {
  const _EmptySubscriptions({required this.canClassify, required this.onClassify});
  final bool canClassify;
  final VoidCallback onClassify;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        children: [
          const Icon(AppIcons.recurring, size: 34),
          const SizedBox(height: 12),
          Text(
            'nenhuma assinatura ainda',
            style: AppTypography.section(context, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Assinaturas são recorrências que você escolheu acompanhar separadamente. Nenhum item antigo é classificado automaticamente.',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: AppColors.secondaryText(brightness),
            ),
          ),
          if (canClassify) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onClassify,
              icon: const Icon(AppIcons.add, size: 17),
              label: const Text('classificar recorrência'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.item,
    required this.cardName,
    required this.onEdit,
    required this.onMoveToRecurring,
    this.onEnd,
  });

  final RecurringItem item;
  final String? cardName;
  final VoidCallback onEdit;
  final VoidCallback? onEnd;
  final VoidCallback onMoveToRecurring;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final next = nextSubscriptionOccurrence(item);
    final source = item.accountName ?? cardName ?? (item.cardId == null ? null : 'cartão');

    return Semantics(
      button: true,
      label: '${item.name}, ${item.frequencyLabel}, ${item.active ? 'ativa' : 'encerrada'}',
      child: Material(
        color: AppColors.surface(brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border(brightness)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple(brightness).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    AppIcons.recurring,
                    color: AppColors.primaryPurple(brightness),
                    size: 22,
                  ),
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
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.money(item.amount),
                            style: AppTypography.money(context, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          subscriptionFrequencyLabel(item),
                          if (next != null) 'próxima ${_shortDate(next)}',
                          if (source != null) source,
                          if (item.categoryName != null) item.categoryName!,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          context,
                          fontSize: 11,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.active ? 'ativa' : 'encerrada',
                        style: AppTypography.label(
                          context,
                          fontSize: 10,
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'ações da assinatura',
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'end') onEnd?.call();
                    if (value == 'recurring') onMoveToRecurring();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('editar')),
                    if (onEnd != null)
                      const PopupMenuItem(
                        value: 'end',
                        child: Text('marcar como encerrada'),
                      ),
                    const PopupMenuItem(
                      value: 'recurring',
                      child: Text('mover para recorrências'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecurringCandidatePicker extends StatelessWidget {
  const _RecurringCandidatePicker({required this.items});
  final List<RecurringItem> items;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'classificar como assinatura',
                    style: AppTypography.section(context, fontSize: 18),
                  ),
                ),
                IconButton(
                  tooltip: 'fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Escolha apenas serviços que você realmente considera assinatura. O Fôlego não classifica pelo nome ou pela categoria.',
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: AppColors.secondaryText(brightness),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    '${Formatters.money(item.amount)} · ${subscriptionFrequencyLabel(item)}',
                  ),
                  trailing: const Icon(AppIcons.chevronRight, size: 18),
                  onTap: () => Navigator.of(context).pop(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

double subscriptionMonthlyEquivalent(RecurringItem item) {
  final amount = item.amount.abs();
  switch (item.frequency) {
    case 'weekly':
      return amount * 52 / 12;
    case 'biweekly':
      return amount * 26 / 12;
    case 'yearly':
      return amount / 12;
    case 'monthly':
      final configuredDays = item.monthlyDays.where((day) => day >= 1 && day <= 31).toSet();
      final occurrences = configuredDays.isEmpty
          ? 1
          : configuredDays.length + (item.monthlyLastDay ? 1 : 0);
      return amount * occurrences;
    default:
      return amount;
  }
}

String subscriptionFrequencyLabel(RecurringItem item) {
  switch (item.frequency) {
    case 'weekly':
      return 'semanal';
    case 'biweekly':
      return 'a cada 2 semanas';
    case 'monthly':
      return 'mensal';
    case 'yearly':
      return 'anual';
    default:
      return item.frequencyLabel.toLowerCase();
  }
}

DateTime? nextSubscriptionOccurrence(RecurringItem item, {DateTime? from}) {
  if (!item.active) return null;
  final raw = from ?? DateTime.now();
  final today = DateTime(raw.year, raw.month, raw.day);
  final start = DateTime(item.startsOn.year, item.startsOn.month, item.startsOn.day);
  final reference = today.isBefore(start) ? start : today;
  final end = item.endsOn == null
      ? null
      : DateTime(item.endsOn!.year, item.endsOn!.month, item.endsOn!.day);

  DateTime? candidate;
  switch (item.frequency) {
    case 'weekly':
      final weekday = item.weekday ?? (start.weekday % 7);
      candidate = reference;
      for (var step = 0; step < 7; step++) {
        final date = reference.add(Duration(days: step));
        if (date.weekday % 7 == weekday) {
          candidate = date;
          break;
        }
      }
      break;
    case 'biweekly':
      if (reference.isBefore(start) || reference == start) {
        candidate = start;
      } else {
        final days = reference.difference(start).inDays;
        final steps = (days / 14).ceil();
        candidate = start.add(Duration(days: steps * 14));
      }
      break;
    case 'yearly':
      final month = item.monthOfYear ?? start.month;
      final day = item.dayOfMonth ?? start.day;
      candidate = _safeDate(reference.year, month, day);
      if (candidate.isBefore(reference)) {
        candidate = _safeDate(reference.year + 1, month, day);
      }
      break;
    case 'monthly':
      final days = <int>{
        ...item.monthlyDays.where((value) => value >= 1 && value <= 31),
        if (item.monthlyDays.isEmpty && item.dayOfMonth != null) item.dayOfMonth!,
      }.toList()..sort();
      final possible = <DateTime>[
        for (final day in days) _safeDate(reference.year, reference.month, day),
        if (item.monthlyLastDay)
          DateTime(reference.year, reference.month + 1, 0),
      ]..sort();
      for (final date in possible) {
        if (!date.isBefore(reference)) {
          candidate = date;
          break;
        }
      }
      if (candidate == null) {
        final nextMonth = DateTime(reference.year, reference.month + 1, 1);
        final nextPossible = <DateTime>[
          for (final day in days) _safeDate(nextMonth.year, nextMonth.month, day),
          if (item.monthlyLastDay)
            DateTime(nextMonth.year, nextMonth.month + 1, 0),
        ]..sort();
        candidate = nextPossible.isEmpty ? nextMonth : nextPossible.first;
      }
      break;
    default:
      candidate = reference;
  }

  if (candidate.isBefore(start)) candidate = start;
  if (end != null && candidate.isAfter(end)) return null;
  return candidate;
}

DateTime _safeDate(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > lastDay ? lastDay : day);
}

String _shortDate(DateTime value) {
  const months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  return '${value.day} ${months[value.month - 1]}';
}
