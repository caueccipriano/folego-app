import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/wallet_detail.dart';

class InstallmentRelief {
  const InstallmentRelief(this.item, this.fromMonth, this.cents);
  final WalletInstallmentPosition item;
  final DateTime fromMonth;
  final int cents;
}

/// Only complete schedules with an actual last due date qualify.
/// These are reference installment values, never additions to available cash.
List<InstallmentRelief> installmentRelief(
  Iterable<WalletInstallmentPosition> items, DateTime reference,
) {
  final start = DateTime(reference.year, reference.month);
  final end = DateTime(start.year, start.month + 7);
  final seen = <String>{};
  final result = <InstallmentRelief>[];
  for (final item in items) {
    if (!seen.add(item.purchaseId) || item.completed) { continue; }
    final last = item.endingOn;
    final amount = item.lastInstallmentAmount;
    final next = item.nextDueDate;
    if (last == null || next == null || amount == null ||
        !amount.isFinite || amount <= 0 ||
        DateTime(next.year, next.month, next.day).isBefore(
          DateTime(reference.year, reference.month, reference.day))) { continue; }
    final from = DateTime(last.year, last.month + 1);
    if (from.isAfter(start) && from.isBefore(end)) {
      result.add(InstallmentRelief(item, from, (amount * 100).round()));
    }
  }
  result.sort((a, b) => a.fromMonth.compareTo(b.fromMonth));
  return result;
}

class InstallmentReliefCard extends StatefulWidget {
  const InstallmentReliefCard({super.key, required this.items, required this.onOpen});
  final List<WalletInstallmentPosition> items;
  final ValueChanged<WalletInstallmentPosition> onOpen;
  @override
  State<InstallmentReliefCard> createState() => _InstallmentReliefCardState();
}

class _InstallmentReliefCardState extends State<InstallmentReliefCard> {
  int _months = 3;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: FinancialPrivacy.hidden,
    builder: (context, hidden, _) {
      final now = DateTime.now();
      final rows = installmentRelief(widget.items, now);
      final end = DateTime(now.year, now.month + _months + 1);
      final visible = rows.where((row) => row.fromMonth.isBefore(end)).toList();
      final total = visible.fold<int>(0, (sum, row) => sum + row.cents);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('quando as parcelas deixam de vencer', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final months in [3, 6]) ChoiceChip(
                  label: Text('$months meses'), selected: _months == months,
                  onSelected: (_) => setState(() => _months = months),
                ),
              ]),
              const SizedBox(height: 8),
              Text('valor de referência das últimas parcelas: ${hidden ? 'R\$ ••••' : Formatters.money(total / 100)}'),
              const Text('É a soma dos valores das últimas parcelas das compras abaixo. Pode aliviar compromissos futuros; não é dinheiro disponível hoje, limite do cartão ou economia acumulada no período.'),
              if (visible.isEmpty) const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('nenhum término com dados suficientes neste horizonte'),
              ),
              for (final row in visible) ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.item.displayName),
                subtitle: Text('${row.item.cardName} · última parcela em ${Formatters.fullDate.format(row.item.endingOn!)}\nsem nova parcela a partir de ${Formatters.monthYear.format(row.fromMonth)}'),
                trailing: Text(hidden ? 'R\$ ••••' : Formatters.money(row.cents / 100)),
                onTap: () => widget.onOpen(row.item),
              ),
              Text('Consulta baseada nas ${widget.items.length} compras carregadas (até 60). Compras fora da consulta, cronogramas incompletos e parcelas vencidas não entram nesta projeção. Novas compras podem ocupar o espaço previsto.'),
            ],
          ),
        ),
      );
    },
  );
}
