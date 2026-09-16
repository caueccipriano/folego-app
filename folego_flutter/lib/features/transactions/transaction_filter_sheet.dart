import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/transaction_filters.dart';

const Map<String, String> transactionEventTypeLabels = {
  'income': 'receita',
  'expense': 'gasto',
  'transfer': 'transferência',
  'card_purchase': 'compra no cartão',
  'card_payment': 'pagamento de fatura',
  'debt_payment': 'pagamento de dívida',
  'refund': 'estorno',
  'reimbursement': 'reembolso',
  'reserve_transfer': 'reserva',
  'benefit_credit': 'crédito de benefício',
  'benefit_expense': 'gasto de benefício',
  'adjustment': 'ajuste',
  'opening_balance': 'saldo inicial',
};

String transactionEventTypeLabel(String type) {
  return transactionEventTypeLabels[type] ?? type.replaceAll('_', ' ');
}

Future<TransactionFilters?> showTransactionFilters({
  required BuildContext context,
  required TransactionFilters initial,
  required TransactionFilterOptions options,
}) {
  final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
  if (compact) {
    return showModalBottomSheet<TransactionFilters>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: TransactionFilterSheet(initial: initial, options: options),
      ),
    );
  }

  return showDialog<TransactionFilters>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: TransactionFilterSheet(initial: initial, options: options),
      ),
    ),
  );
}

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({
    super.key,
    required this.initial,
    required this.options,
  });

  final TransactionFilters initial;
  final TransactionFilterOptions options;

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late TransactionFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      currentDate: now,
      initialDateRange: _draft.startDate != null && _draft.endDate != null
          ? DateTimeRange(start: _draft.startDate!, end: _draft.endDate!)
          : null,
      helpText: 'filtrar por período',
      cancelText: 'cancelar',
      confirmText: 'usar período',
    );
    if (range == null || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(startDate: range.start, endDate: range.end);
    });
  }

  void _toggleType(String type, bool selected) {
    final types = Set<String>.from(_draft.eventTypes);
    if (selected) {
      types.add(type);
    } else {
      types.remove(type);
    }
    setState(() => _draft = _draft.copyWith(eventTypes: types));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'filtros',
                      style: AppTypography.section(
                        context,
                        fontSize: 20,
                        color: primary,
                      ),
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
            Divider(height: 1, color: border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel('período'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickPeriod,
                      icon: const Icon(AppIcons.calendar, size: 18),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_periodLabel(_draft)),
                      ),
                    ),
                    if (_draft.hasPeriod)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(
                            () => _draft = _draft.copyWith(
                              startDate: null,
                              endDate: null,
                            ),
                          ),
                          child: const Text('remover período'),
                        ),
                      ),
                    const SizedBox(height: 18),
                    _SectionLabel('tipo'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: transactionEventTypeLabels.entries.map((entry) {
                        return FilterChip(
                          label: Text(entry.value),
                          selected: _draft.eventTypes.contains(entry.key),
                          onSelected: (selected) =>
                              _toggleType(entry.key, selected),
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 20),
                    _FilterDropdown(
                      label: 'categoria',
                      value: _draft.categoryId,
                      allLabel: 'todas as categorias',
                      items: [
                        for (final category in widget.options.categories)
                          _FilterOption(category.id, category.breadcrumb),
                      ],
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(categoryId: value),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FilterDropdown(
                      label: 'conta',
                      value: _draft.accountId,
                      allLabel: 'todas as contas',
                      items: [
                        for (final account in widget.options.accounts)
                          _FilterOption(account.id, account.name),
                      ],
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(accountId: value),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FilterDropdown(
                      label: 'cartão',
                      value: _draft.cardId,
                      allLabel: 'todos os cartões',
                      items: [
                        for (final card in widget.options.cards)
                          _FilterOption(card.id, card.name),
                      ],
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(cardId: value),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FilterDropdown(
                      label: 'benefício',
                      value: _draft.benefitAccountId,
                      allLabel: 'todos os benefícios',
                      items: [
                        for (final benefit in widget.options.benefits)
                          _FilterOption(benefit.id, benefit.name),
                      ],
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(
                          benefitAccountId: value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'contas e benefícios ficam separados para não misturar saldo em dinheiro com saldo de benefício.',
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(
                        TransactionFilters.empty(),
                      ),
                      child: const Text('limpar filtros'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: const Text('aplicar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.label(
        context,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String allLabel;
  final List<_FilterOption> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final availableIds = items.map((item) => item.id).toSet();
    final selected = value != null && availableIds.contains(value) ? value! : '';

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: '', child: Text(allLabel)),
        ...items.map(
          (item) => DropdownMenuItem(
            value: item.id,
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (next) => onChanged(next == null || next.isEmpty ? null : next),
    );
  }
}

class _FilterOption {
  const _FilterOption(this.id, this.label);
  final String id;
  final String label;
}

String _periodLabel(TransactionFilters filters) {
  if (filters.startDate == null && filters.endDate == null) {
    return 'qualquer período';
  }
  if (filters.startDate != null && filters.endDate != null) {
    return '${_date(filters.startDate!)} — ${_date(filters.endDate!)}';
  }
  if (filters.startDate != null) {
    return 'a partir de ${_date(filters.startDate!)}';
  }
  return 'até ${_date(filters.endDate!)}';
}

String _date(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
