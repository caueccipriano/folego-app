import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/intelligence/cash_runway_preparation.dart';

/// Read-only preview of a hypothetical outflow on a selected forecast date.
class RunwayWhatIfCard extends StatefulWidget {
  const RunwayWhatIfCard({super.key, required this.preparation});
  final CashRunwayPreparation preparation;
  @override
  State<RunwayWhatIfCard> createState() => _RunwayWhatIfCardState();
}

class _RunwayWhatIfCardState extends State<RunwayWhatIfCard> {
  double _purchase = 0;
  bool _forGoal = false;
  DateTime? _selectedDate;
  final TextEditingController _amountController = TextEditingController(text: '0');
  bool _invalidAmount = false;
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final runway = widget.preparation.runway;
    if (runway == null || runway.days.isEmpty) return const SizedBox.shrink();
    final en = Localizations.localeOf(context).languageCode == 'en';
    final currency = NumberFormat.currency(
      locale: en ? 'en_US' : 'pt_BR', symbol: 'BRL',
    );
    final selectedDate = _selectedDate == null ||
            _selectedDate!.isBefore(runway.days.first.date) ||
            _selectedDate!.isAfter(runway.days.last.date)
        ? runway.days.first.date
        : _selectedDate!;
    final dayKey = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final effectivePurchase = _invalidAmount ? 0.0 : _purchase;
    final simulatedBalance = runway.balanceAtPayday - effectivePurchase;
    final newlyAffected = runway.days.where((day) =>
        !day.date.isBefore(dayKey) && day.closingBalance >= 0 && day.closingBalance - effectivePurchase < 0).toList();
    final firstNewShortfall = newlyAffected.isEmpty ? null : newlyAffected.first.date;
    final alreadyNegative = runway.firstNegativeDay != null;
    final alreadyNegativeBeforeScenario = runway.days.any((day) =>
        day.date.isBefore(dayKey) && day.closingBalance < 0);
    final simulationReady = !_invalidAmount && effectivePurchase > 0;
    final date = DateFormat.yMd(en ? 'en_US' : 'pt_BR');
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(en ? 'Simulate a purchase or savings contribution' : 'Simule uma compra ou um aporte'),
      subtitle: Text(en ? 'Simulation only — no transaction or goal contribution is created'
          : 'Apenas simulação — nenhum lançamento ou aporte real é criado'),
      children: [
        if (widget.preparation.guidanceNeedsReview)
          Text(en
              ? 'Caution: overdue obligations or incomplete agenda data make this simulation provisional. Review your records before making a decision.'
              : 'Atenção: contas vencidas ou agenda incompleta tornam esta simulação provisória. Revise seus registros antes de decidir.',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _forGoal,
          onChanged: (value) => setState(() => _forGoal = value),
          title: Text(en ? 'Simulate a savings contribution' : 'Simular aporte para uma meta'),
        ),
        Text(_forGoal
            ? (en ? 'Hypothetical contribution' : 'Aporte hipotético')
            : (en ? 'Hypothetical purchase' : 'Compra hipotética')),
        Text(currency.format(effectivePurchase)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(en ? 'Simulation date' : 'Data da simulação'),
          subtitle: Text(DateFormat.yMd(en ? 'en_US' : 'pt_BR').format(selectedDate)),
          trailing: const Icon(Icons.calendar_month_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: runway.days.first.date,
              lastDate: runway.days.last.date,
            );
            if (picked != null && mounted) setState(() => _selectedDate = picked);
          },
        ),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: en ? 'Exact amount (BRL)' : 'Valor exato (BRL)',
            helperText: en ? 'Use a comma or dot for cents' : 'Use vírgula ou ponto para centavos',
            errorText: _invalidAmount
                ? (en ? 'Enter a value between 0 and 1,000,000' : 'Informe um valor entre 0 e 1.000.000')
                : null,
          ),
          onChanged: (raw) {
            final value = double.tryParse(raw.trim().replaceAll(',', '.'));
            final valid = value != null && value.isFinite && value >= 0 && value <= 1000000;
            setState(() {
              _invalidAmount = !valid;
              if (valid) _purchase = value;
            });
          },
        ),
        Slider(
          value: effectivePurchase.clamp(0.0, 2000.0), min: 0, max: 2000, divisions: 40,
          label: currency.format(effectivePurchase),
          onChanged: (value) => setState(() {
            _purchase = value;
            _invalidAmount = false;
            _amountController.text = value.toStringAsFixed(0);
          }),
        ),
        if (!_invalidAmount)
          ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(en ? 'Balance before next income after simulation'
              : 'Saldo antes da próxima entrada após a simulação'),
          trailing: Text(currency.format(simulatedBalance)),
        ),
        if (simulationReady && firstNewShortfall != null)
          Text(en
              ? 'This scenario introduces a new shortfall on ${date.format(firstNewShortfall)}.'
              : 'Esta simulação cria uma nova falta de saldo em ${date.format(firstNewShortfall)}.',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (!_invalidAmount && alreadyNegative)
          Text(en
              ? alreadyNegativeBeforeScenario
                  ? 'A shortfall already occurs before the selected date; this simulation cannot fix it.'
                  : 'Your existing schedule already shows a shortfall. Review scheduled bills independently of this simulation.'
              : alreadyNegativeBeforeScenario
                  ? 'Já existe falta de saldo antes da data escolhida; esta simulação não resolve esse problema.'
                  : 'Sua programação já apresenta falta de saldo. Revise as contas previstas independentemente desta simulação.'),
        if (simulationReady && firstNewShortfall == null && !alreadyNegative &&
            !widget.preparation.guidanceNeedsReview)
          Text(en
              ? 'No new negative day found in the registered schedule.'
              : 'Nenhum novo dia negativo encontrado na programação cadastrada.'),
        Text(en
            ? 'Assumes this amount leaves your cash accounts on the selected date and every other scheduled event stays unchanged. Does not update a goal. Excludes unregistered bills and reserved money.'
            : 'Considera a saída desse valor das contas na data selecionada, sem alterar os demais eventos. Não atualiza metas. Não inclui contas não cadastradas nem dinheiro reservado.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
