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
    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;

    return AppContentContainer.list(
      fillHeight: true,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          key: ValueKey(
            compact
                ? 'subscriptions-mobile-layout'
                : 'subscriptions-desktop-layout',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 120),
          children: [
            _Header(
              monthlyEquivalent: monthly,
              activeCount: active.length,
              canClassify: recurringCandidates.any((item) => item.isExpense),
              onClassify: () => _pickRecurring(context),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              _EmptyState(
                canClassify: recurringCandidates.any((item) => item.isExpense),
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
                'O total mensal é uma equivalência para comparação. O valor e a frequência originais continuam preservados.',
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
            builder: (_) => _CandidatePicker(items: candidates),
          )
        : await showDialog<RecurringItem>(
            context: context,
            builder: (_) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
                child: _CandidatePicker(items: candidates),
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

class _Header extends StatelessWidget {
  const _Header({
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
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 240, maxWidth: 520),
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
          if (canClassify)
            OutlinedButton.icon(
              key: const ValueKey('subscription-classify-action'),
              onPressed: onClassify,
              icon: const Icon(AppIcons.add, size: 17),
              label: const Text('classificar'),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canClassify, required this.onClassify});

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
            'Classifique uma recorrência de gasto como assinatura para acompanhá-la aqui. Nada antigo é classificado automaticamente.',
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
    final details = <String>[
      subscriptionFrequencyLabel(item),
      if (next != null) 'próxima ${_shortDate(next)}',
      ?source,
      ?item.categoryName,
    ];

    return Semantics(
      button: true,
      label:
          '${item.name}, ${Formatters.money(item.amount)}, ${item.active ? 'ativa' : 'encerrada'}',
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
                        details.join(' · '),
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

class _CandidatePicker extends StatelessWidget {
  const _CandidatePicker({required this.items});

  final List<RecurringItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'classificar como assinatura',
                    style: AppTypography.section(context, fontSize: 17),
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
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = items[index];
                return ListTile(
                  onTap: () => Navigator.of(context).pop(item),
                  title: Text(item.name),
                  subtitle: Text(
                    '${Formatters.money(item.amount)} · ${item.frequencyLabel}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
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
  switch (item.frequency) {
    case 'weekly':
      return item.amount * 52 / 12;
    case 'biweekly':
      return item.amount * 26 / 12;
    case 'yearly':
      return item.amount / 12;
    case 'monthly':
    default:
      return item.amount;
  }
}

String subscriptionFrequencyLabel(RecurringItem item) {
  switch (item.frequency) {
    case 'weekly':
      return 'semanal';
    case 'biweekly':
      return 'quinzenal';
    case 'yearly':
      return 'anual';
    case 'monthly':
      return 'mensal';
    default:
      return item.frequencyLabel.toLowerCase();
  }
}

DateTime? nextSubscriptionOccurrence(
  RecurringItem item, {
  DateTime? referenceDate,
}) {
  final now = referenceDate ?? DateTime.now();
  final reference = DateTime(now.year, now.month, now.day);
  final start = DateTime(item.startsOn.year, item.startsOn.month, item.startsOn.day);
  final end = item.endsOn == null
      ? null
      : DateTime(item.endsOn!.year, item.endsOn!.month, item.endsOn!.day);
  DateTime candidate;

  switch (item.frequency) {
    case 'weekly':
      final target = item.weekday ?? start.weekday % 7;
      candidate = reference.isBefore(start) ? start : reference;
      while (candidate.weekday % 7 != target) {
        candidate = candidate.add(const Duration(days: 1));
      }
      break;
    case 'biweekly':
      if (reference.isBefore(start)) {
        candidate = start;
      } else {
        final elapsed = reference.difference(start).inDays;
        final periods = (elapsed / 14).ceil();
        candidate = start.add(Duration(days: periods * 14));
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
    default:
      final days = <int>{
        ...item.monthlyDays.where((value) => value >= 1 && value <= 31),
        if (item.monthlyDays.isEmpty && item.dayOfMonth != null) item.dayOfMonth!,
      }.toList()
        ..sort();
      final candidates = <DateTime>[
        for (final day in days) _safeDate(reference.year, reference.month, day),
        if (item.monthlyLastDay)
          DateTime(reference.year, reference.month + 1, 0),
      ]..sort();
      DateTime? selected;
      for (final date in candidates) {
        if (!date.isBefore(reference)) {
          selected = date;
          break;
        }
      }
      if (selected == null) {
        final nextMonth = DateTime(reference.year, reference.month + 1, 1);
        final nextPossible = <DateTime>[
          for (final day in days) _safeDate(nextMonth.year, nextMonth.month, day),
          if (item.monthlyLastDay)
            DateTime(nextMonth.year, nextMonth.month + 1, 0),
        ]..sort();
        candidate = nextPossible.isEmpty ? nextMonth : nextPossible.first;
      } else {
        candidate = selected;
      }
      break;
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
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month';
}
