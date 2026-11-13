import 'package:flutter/material.dart';

import '../../core/utils/error_translator.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/income_amount_confirmation.dart';
import '../../data/models/income_date_schedule.dart';
import '../../data/models/upcoming_financial_event.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_agenda.dart';
import '../../data/repositories/folego_repository_income_confirmations.dart';
import '../../data/repositories/folego_repository_income_dates.dart';
import '../../shared/widgets/section_card.dart';

/// Calendário de entradas sem fazer previsão de salários.
/// Os valores da recorrência/agenda jamais são usados como valores confirmados.
class HomeUpcomingReceiptsCard extends StatefulWidget {
  const HomeUpcomingReceiptsCard({
    super.key,
    required this.repository,
    required this.spaceId,
    this.onOpenAgenda,
  });

  final FolegoRepository repository;
  final String spaceId;
  final VoidCallback? onOpenAgenda;

  @override
  State<HomeUpcomingReceiptsCard> createState() =>
      _HomeUpcomingReceiptsCardState();
}

class _HomeUpcomingReceiptsCardState extends State<HomeUpcomingReceiptsCard> {
  bool _loading = true;
  String? _error;
  String? _savingKey;
  List<UpcomingFinancialEvent> _income = const [];
  Map<String, IncomeAmountConfirmation> _confirmed = const {};
  List<IncomeDateSchedule> _dateSchedules = const [];
  Map<String, IncomeDateAmount> _dateAmounts = const {};
  double? _registeredThisMonth;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeUpcomingReceiptsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.repository != widget.repository) {
      _generation++;
      _income = const [];
      _confirmed = const {};
      _dateSchedules = const [];
      _dateAmounts = const {};
      _registeredThisMonth = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final spaceId = widget.spaceId;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final until = start.add(const Duration(days: 44));

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        // Future.sync turns a synchronous test-double/repository failure
        // into a handled Future, so optional Home cards cannot crash Home.
        Future<dynamic>.sync(() => widget.repository.getFinancialAgenda(
          spaceId,
          startDate: start,
          endDate: until,
          limit: 200,
        )),
        Future<dynamic>.sync(() => widget.repository.listIncomeAmountConfirmations(
          spaceId: spaceId,
          from: start,
          until: until,
        )),
        Future<dynamic>.sync(() => widget.repository.getRegisteredIncomeForMonth(
          spaceId: spaceId,
          periodMonth: start,
        )),
        Future<dynamic>.sync(() => widget.repository.listIncomeDateSchedules(spaceId)),
        Future<dynamic>.sync(() => widget.repository.listIncomeDateAmounts(
          spaceId: spaceId, from: start, until: until,
        )),
      ]);
      if (!mounted || generation != _generation || spaceId != widget.spaceId) {
        return;
      }
      final events = (results[0] as List<UpcomingFinancialEvent>)
          .where((event) => event.isIncome && event.isRecurring &&
              event.status == 'pending' && !event.dueDate.isBefore(start))
          .toList(growable: false)
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final confirmations = results[1] as List<IncomeAmountConfirmation>;
      setState(() {
        _income = events;
        _confirmed = {
          for (final value in confirmations) value.occurrenceKey: value,
        };
        _registeredThisMonth = results[2] as double;
        _dateSchedules = results[3] as List<IncomeDateSchedule>;
        _dateAmounts = {
          for (final amount in results[4] as List<IncomeDateAmount>)
            amount.key: amount,
        };
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation || spaceId != widget.spaceId) {
        return;
      }
      setState(() {
        _loading = false;
        _error = ErrorTranslator.forDisplay(error);
      });
    }
  }


  Future<void> _addSchedule() async {
    if (_savingKey != null) return;
    final name = TextEditingController();
    int? day;
    _NewIncomeDate? choice;
    try {
      choice = await showDialog<_NewIncomeDate>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Adicionar data de recebimento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Defina quando costuma receber. O valor não é obrigatório.'),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('income-date-name'),
                  controller: name,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Salário, adiantamento, benefício...',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: const ValueKey('income-date-day'),
                  initialValue: day,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Data mensal'),
                  items: [
                    for (var d = 1; d <= 31; d++)
                      DropdownMenuItem(value: d, child: Text('Dia $d')),
                    const DropdownMenuItem(
                      value: 32,
                      child: Text('Último dia do mês'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => day = value),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Só a data será cadastrada. Nenhum dinheiro será previsto ou lançado.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: name.text.trim().isEmpty || day == null
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        _NewIncomeDate(name.text.trim(), day!),
                      ),
                child: const Text('Salvar data'),
              ),
            ],
          ),
        ),
      );
    } finally {
      name.dispose();
    }
    if (choice == null || !mounted) return;
    setState(() => _savingKey = 'new-schedule');
    try {
      final today = DateTime.now();
      await widget.repository.addIncomeDateSchedule(
        spaceId: widget.spaceId,
        label: choice.label,
        dayOfMonth: choice.day == 32 ? null : choice.day,
        lastDayOfMonth: choice.day == 32,
        startsOn: DateTime(today.year, today.month, today.day),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorTranslator.forDisplay(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  Future<void> _removeSchedule(_ReceiptRow row) async {
    if (_savingKey != null || row.scheduleId == null) return;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover data mensal?'),
        content: Text(
          'A data ${row.label} deixará de aparecer nas próximas semanas. '
          'Os valores informados nela também serão retirados do calendário. '
          'Nenhum lançamento financeiro será alterado.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remover data')),
        ],
      ),
    );
    if (allowed != true || !mounted) return;
    setState(() => _savingKey = row.scheduleId);
    try {
      await widget.repository.removeIncomeDateSchedule(
        spaceId: widget.spaceId,
        scheduleId: row.scheduleId!,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorTranslator.forDisplay(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  Future<void> _editAmount(_ReceiptRow row) async {
    if (_savingKey != null) return;
    final key = row.key;
    final existing = row.amount;
    final controller = TextEditingController(
      text: existing?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
    final formKey = GlobalKey<FormState>();

    double? selection;
    try {
      selection = await showDialog<double>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Informar valor confirmado'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.label} · ${Formatters.fullDate.format(row.dueDate)}',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('income-confirmation-amount-input'),
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor informado',
                    prefixText: 'R\$ ',
                    hintText: '0,00',
                  ),
                  validator: (text) {
                    final parsed = Formatters.parseMoney(text ?? '').toDouble();
                    if (!parsed.isFinite || parsed <= 0 ||
                        parsed > 999999999999.99) {
                      return 'Informe um valor válido maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'O valor foi informado por você. Não significa recebimento '
                  'efetivo e não altera o saldo disponível.',
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(-1.0),
                child: const Text('Retirar valor'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop(
                  Formatters.parseMoney(controller.text).toDouble(),
                );
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (selection == null || !mounted) return;
    setState(() => _savingKey = key);
    try {
      if (row.scheduleId != null) {
        if (selection < 0) {
          await widget.repository.clearScheduledIncomeAmount(
            spaceId: widget.spaceId,
            scheduleId: row.scheduleId!,
            dueDate: row.dueDate,
          );
        } else {
          await widget.repository.confirmScheduledIncomeAmount(
            spaceId: widget.spaceId,
            scheduleId: row.scheduleId!,
            dueDate: row.dueDate,
            amount: selection,
          );
        }
      } else if (row.recurringId != null) {
        if (selection < 0) {
          await widget.repository.clearIncomeAmount(
            spaceId: widget.spaceId,
            recurringItemId: row.recurringId!,
            dueDate: row.dueDate,
          );
        } else {
          await widget.repository.confirmIncomeAmount(
            spaceId: widget.spaceId,
            recurringItemId: row.recurringId!,
            dueDate: row.dueDate,
            amount: selection,
          );
        }
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorTranslator.forDisplay(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final until = from.add(const Duration(days: 44));
    final all = <_ReceiptRow>[
      for (final event in _income)
        _ReceiptRow(
          label: event.title,
          dueDate: event.dueDate,
          recurringId: event.sourceId,
          amount: _confirmed[IncomeAmountConfirmation.occurrenceId(
            event.sourceId, event.dueDate,
          )]?.amount,
          subtitle: 'Receita recorrente',
        ),
      for (final schedule in _dateSchedules)
        for (final date in schedule.datesBetween(from, until))
          _ReceiptRow(
            label: schedule.label,
            dueDate: date,
            scheduleId: schedule.id,
            amount: _dateAmounts[IncomeDateAmount.amountKey(
              schedule.id, date,
            )]?.amount,
            subtitle: schedule.whenLabel,
          ),
    ]..sort((a, b) {
        final byDate = a.dueDate.compareTo(b.dueDate);
        return byDate == 0 ? a.label.compareTo(b.label) : byDate;
      });
    final confirmed = all.where((value) => value.amount != null).toList();
    final total = confirmed.fold<double>(
      0, (sum, value) => sum + value.amount!,
    );

    return SectionCard(
      child: Column(
        key: const ValueKey('home-upcoming-receipts'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.south_west_rounded, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Próximos recebimentos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Atualizar recebimentos',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 19),
              ),
            ],
          ),
          Text(
            'Próximos 45 dias · sem previsão automática de valores',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('income-add-date'),
              onPressed: _savingKey == null ? _addSchedule : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar data sem valor'),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading && _registeredThisMonth == null)
            const Center(child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ))
          else if (_error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Não foi possível carregar os recebimentos.'),
                const SizedBox(height: 6),
                Text(_error!, style: theme.textTheme.bodySmall),
                TextButton(onPressed: _load, child: const Text('Tentar novamente')),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _ReceiptMetric(
                    title: 'Lançado no mês',
                    value: Formatters.money(_registeredThisMonth),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReceiptMetric(
                    title: 'Confirmado a receber',
                    value: confirmed.isEmpty
                        ? 'Nenhum valor' : Formatters.money(total),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              '${all.length - confirmed.length} sem valor informado'
              ' · ${confirmed.length} com valor informado',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (all.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Sem datas cadastradas neste período. Adicione uma acima.'),
              )
            else
              for (final value in all.take(10)) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        Formatters.shortDate.format(value.dueDate),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(value.label,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(value.subtitle, style: theme.textTheme.labelSmall),
                          Text(
                            value.amount == null
                                ? 'Valor a confirmar'
                                : Formatters.money(value.amount),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _savingKey == null
                          ? () => _editAmount(value) : null,
                      child: Text(value.amount == null
                          ? 'Informar' : 'Editar'),
                    ),
                    if (value.scheduleId != null)
                      IconButton(
                        key: ValueKey('income-remove-${value.scheduleId}'),
                        tooltip: 'Remover data recorrente',
                        onPressed: _savingKey == null
                            ? () => _removeSchedule(value) : null,
                        icon: const Icon(Icons.more_vert, size: 19),
                      ),
                  ],
                ),
              ],
            if (all.length > 10)
              Text('${all.length - 10} datas adicionais neste período.',
                  style: theme.textTheme.bodySmall),
            if (widget.onOpenAgenda != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onOpenAgenda,
                  child: const Text('Abrir agenda financeira'),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Valores confirmados aqui são apenas informativos. '
              'O saldo só muda quando a receita for lançada como recebida.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptMetric extends StatelessWidget {
  const _ReceiptMetric({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            Text(value,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewIncomeDate {
  const _NewIncomeDate(this.label, this.day);
  final String label;
  final int day;
}

class _ReceiptRow {
  const _ReceiptRow({
    required this.label,
    required this.dueDate,
    required this.subtitle,
    required this.amount,
    this.recurringId,
    this.scheduleId,
  });

  final String label;
  final DateTime dueDate;
  final String subtitle;
  final double? amount;
  final String? recurringId;
  final String? scheduleId;

  String get key {
    if (scheduleId != null) {
      return IncomeDateAmount.amountKey(scheduleId!, dueDate);
    }
    return IncomeAmountConfirmation.occurrenceId(recurringId!, dueDate);
  }
}
