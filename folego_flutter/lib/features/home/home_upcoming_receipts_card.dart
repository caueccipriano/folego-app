import 'package:flutter/material.dart';

import '../../core/utils/error_translator.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/income_amount_confirmation.dart';
import '../../data/models/upcoming_financial_event.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_agenda.dart';
import '../../data/repositories/folego_repository_income_confirmations.dart';
import '../../shared/widgets/section_card.dart';

/// Calendário de entradas sem fazer previsão de salários.
//// Os valores da recorrência/agenda jamais são usados como valores confirmados.
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
        widget.repository.getFinancialAgenda(
          spaceId,
          startDate: start,
          endDate: until,
          limit: 200,
        ),
        widget.repository.listIncomeAmountConfirmations(
          spaceId: spaceId,
          from: start,
          until: until,
        ),
        widget.repository.getRegisteredIncomeForMonth(
          spaceId: spaceId,
          periodMonth: start,
        ),
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

  Future<void> _editAmount(UpcomingFinancialEvent event) async {
    if (_savingKey != null) return;
    final key = IncomeAmountConfirmation.occurrenceId(
      event.sourceId, event.dueDate,
    );
    final existing = _confirmed[key];
    final controller = TextEditingController(
      text: existing?.amount.toStringAsFixed(2).replaceAll('.', ',') ?? '',
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
                  '${event.title} · ${Formatters.fullDate.format(event.dueDate)}',
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
                  'Este valor foi informado por você. Ele não significa '
                  'recebimento efetivo e não altera o saldo disponível.',
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(-1),
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
      if (selection < 0) {
        await widget.repository.clearIncomeAmount(
          spaceId: widget.spaceId,
          recurringItemId: event.sourceId,
          dueDate: event.dueDate,
        );
      } else {
        await widget.repository.confirmIncomeAmount(
          spaceId: widget.spaceId,
          recurringItemId: event.sourceId,
          dueDate: event.dueDate,
          amount: selection,
        );
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorTranslator.forDisplay(error))),
      );
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = _income.map((event) {
      final key = IncomeAmountConfirmation.occurrenceId(
        event.sourceId, event.dueDate,
      );
      return (event: event, confirmation: _confirmed[key]);
    }).toList(growable: false);
    final confirmed = all.where((value) => value.confirmation != null).toList();
    final total = confirmed.fold<double>(
      0, (sum, value) => sum + value.confirmation!.amount,
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
              '${all.length - confirmed.length} sem valor confirmado'
              ' · ${confirmed.length} com valor informado',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (all.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Nenhuma receita recorrente pendente neste período.'),
              )
            else
              for (final value in all.take(5)) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        Formatters.shortDate.format(value.event.dueDate),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(value.event.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            value.confirmation == null
                                ? 'Valor a confirmar'
                                : Formatters.money(value.confirmation!.amount),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _savingKey == null
                          ? () => _editAmount(value.event) : null,
                      child: Text(value.confirmation == null
                          ? 'Informar' : 'Editar'),
                    ),
                  ],
                ),
              ],
            if (all.length > 5 || widget.onOpenAgenda != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onOpenAgenda,
                  child: const Text('Ver agenda completa'),
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
