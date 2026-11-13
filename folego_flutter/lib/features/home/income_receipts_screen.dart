import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/upcoming_financial_event.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_agenda.dart';
import '../../data/repositories/folego_repository_income_receipts.dart';

/// Calendário informativo. Valores de recorrências e projeções não são
/// considerados confirmados; apenas os digitados nesta tela são somados.
/// Um valor conhecido NÃO significa que o dinheiro entrou na conta.
class IncomeReceiptsScreen extends StatefulWidget {
  const IncomeReceiptsScreen({
    super.key,
    required this.spaceId,
    required this.repository,
  });

  final String spaceId;
  final FolegoRepository repository;

  @override
  State<IncomeReceiptsScreen> createState() => _IncomeReceiptsScreenState();
}

class _IncomeReceiptsScreenState extends State<IncomeReceiptsScreen> {
  List<UpcomingFinancialEvent> _incomeEvents = const [];
  Map<String, double> _confirmedAmounts = const {};
  double? _receivedThisMonth;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    FinancialPrivacy.hidden.addListener(_privacyChanged);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    FinancialPrivacy.hidden.removeListener(_privacyChanged);
    super.dispose();
  }

  void _privacyChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final request = ++_generation;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final until = DateTime(today.year, today.month, today.day + 60);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait<dynamic>([
        widget.repository.getFinancialAgenda(
          widget.spaceId,
          startDate: today,
          endDate: until,
          limit: 200,
        ),
        widget.repository.listIncomeReceiptConfirmations(
          spaceId: widget.spaceId,
          from: today,
          until: until,
        ),
        widget.repository.getRegisteredIncomeForMonth(
          spaceId: widget.spaceId,
          periodMonth: today,
        ),
      ]);
      if (!mounted || request != _generation) return;

      final events = (responses[0] as List<UpcomingFinancialEvent>)
          .where((event) =>
              event.isIncome &&
              event.isRecurring &&
              !event.realized &&
              event.dayOffset >= 0)
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final amounts = responses[1] as List<IncomeReceiptConfirmation>;
      setState(() {
        _incomeEvents = events;
        _confirmedAmounts = {
          for (final confirmation in amounts)
            confirmation.key: confirmation.amount,
        };
        _receivedThisMonth = responses[2] as double;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar os recebimentos. Tente novamente.';
      });
    }
  }

  double? _confirmedFor(UpcomingFinancialEvent event) =>
      _confirmedAmounts[incomeReceiptKey(event.sourceId, event.dueDate)];

  Future<void> _edit(UpcomingFinancialEvent event) async {
    if (_saving) return;
    final oldAmount = _confirmedFor(event);
    final controller = TextEditingController(
      text: oldAmount == null
          ? ''
          : oldAmount.toStringAsFixed(2).replaceAll('.', ','),
    );
    String? validation;
    // null = cancelar, -1 = retirar a confirmação, >0 = valor conhecido.
    final result = await showDialog<num?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Informar valor conhecido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${event.title} · ${Formatters.fullDate.format(event.dueDate)}'),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('income-receipt-amount-input'),
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Valor confirmado (R\$)',
                  hintText: 'Deixe em branco enquanto não souber',
                  errorText: validation,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Informe apenas o valor que você já sabe. '
                'Isso não registra recebimento, não altera o saldo '
                'e não substitui a movimentação bancária.',
              ),
            ],
          ),
          actions: [
            if (oldAmount != null)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, -1),
                child: const Text('Remover valor'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('income-receipt-save'),
              onPressed: () {
                final amount = Formatters.parseMoney(controller.text);
                if (!amount.isFinite || amount <= 0) {
                  setDialogState(() {
                    validation = 'Digite um valor positivo já confirmado';
                  });
                  return;
                }
                Navigator.pop(dialogContext, amount);
              },
              child: const Text('Salvar valor'),
            ),
          ],
        ),
      ),
    );
    // Evita descartar o controller antes de o diálogo terminar a transição.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      if (result == -1) {
        await widget.repository.removeIncomeReceiptConfirmation(
          spaceId: widget.spaceId,
          recurringItemId: event.sourceId,
          dueDate: event.dueDate,
        );
      } else {
        await widget.repository.saveIncomeReceiptConfirmation(
          spaceId: widget.spaceId,
          recurringItemId: event.sourceId,
          dueDate: event.dueDate,
          amount: result,
        );
      }
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar esse valor. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final known = _incomeEvents
        .map(_confirmedFor)
        .whereType<double>()
        .toList(growable: false);
    final knownTotal = known.fold<double>(0, (sum, value) => sum + value);
    final unknownCount = _incomeEvents.length - known.length;
    final border = AppColors.border(brightness);
    final surface = AppColors.surface(brightness);
    final muted = AppColors.secondaryText(brightness);

    return Scaffold(
      appBar: AppBar(title: const Text('Próximos recebimentos')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const ValueKey('income-receipts-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Valores conhecidos nos próximos 60 dias',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Formatters.money(knownTotal),
                    key: const ValueKey('income-receipts-known-total'),
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$unknownCount recebimento${unknownCount == 1 ? '' : 's'} sem valor informado',
                    key: const ValueKey('income-receipts-unknown-count'),
                  ),
                  if (_receivedThisMonth != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Receitas já registradas neste mês: '
                      '${Formatters.money(_receivedThisMonth)}',
                      style: TextStyle(color: muted),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'As datas vêm da agenda de recorrências. '
                    'O total inclui somente valores digitados por você, '
                    'não estimativas. Nenhum valor futuro entra no saldo.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Tentar novamente')),
                ],
              )
            else if (_incomeEvents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nenhuma entrada recorrente cadastrada para os '
                  'próximos 60 dias. Cadastre as datas nas recorrências '
                  'para acompanhá-las aqui.',
                ),
              )
            else
              ..._incomeEvents.map((event) {
                final confirmed = _confirmedFor(event);
                return Card(
                  key: ValueKey(
                    'income-receipt-${incomeReceiptKey(event.sourceId, event.dueDate)}',
                  ),
                  margin: const EdgeInsets.only(bottom: 9),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8,
                    ),
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${Formatters.fullDate.format(event.dueDate)} · '
                      '${confirmed == null ? 'valor a confirmar' : 'valor informado · ainda não recebido'}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          confirmed == null
                              ? '—'
                              : Formatters.money(confirmed),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          confirmed == null ? 'informar' : 'editar',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                    enabled: !_saving,
                    onTap: () => _edit(event),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
