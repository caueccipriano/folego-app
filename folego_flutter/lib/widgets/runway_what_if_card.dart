import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/intelligence/cash_runway_preparation.dart';

/// Preview only: assumes an optional purchase is paid today.
class RunwayWhatIfCard extends StatefulWidget {
  const RunwayWhatIfCard({super.key, required this.preparation});
  final CashRunwayPreparation preparation;
  @override
  State<RunwayWhatIfCard> createState() => _RunwayWhatIfCardState();
}

class _RunwayWhatIfCardState extends State<RunwayWhatIfCard> {
  double _purchase = 0;
  bool _forGoal = false;
  @override
  Widget build(BuildContext context) {
    final runway = widget.preparation.runway;
    if (runway == null || runway.days.isEmpty) return const SizedBox.shrink();
    final en = Localizations.localeOf(context).languageCode == 'en';
    final currency = NumberFormat.currency(
      locale: en ? 'en_US' : 'pt_BR', symbol: 'BRL',
    );
    final simulatedBalance = runway.balanceAtPayday - _purchase;
    final newlyAffected = runway.days.where((day) =>
        day.closingBalance >= 0 && day.closingBalance - _purchase < 0).toList();
    final firstNewShortfall = newlyAffected.isEmpty ? null : newlyAffected.first.date;
    final alreadyNegative = runway.firstNegativeDay != null;
    final date = DateFormat.yMd(en ? 'en_US' : 'pt_BR');
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(en ? 'Simulate a purchase or savings contribution' : 'Simule uma compra ou um aporte'),
      subtitle: Text(en ? 'Simulation only — no transaction or goal contribution is created'
          : 'Apenas simulação — nenhum lançamento ou aporte real é criado'),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _forGoal,
          onChanged: (value) => setState(() => _forGoal = value),
          title: Text(en ? 'Simulate a savings contribution' : 'Simular aporte para uma meta'),
        ),
        Text(_forGoal
            ? (en ? 'Hypothetical contribution' : 'Aporte hipotético')
            : (en ? 'Hypothetical purchase' : 'Compra hipotética')),
        Text(currency.format(_purchase)),
        Slider(
          value: _purchase, min: 0, max: 2000, divisions: 40,
          label: currency.format(_purchase),
          onChanged: (value) => setState(() => _purchase = value),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(en ? 'Balance before next income after simulation'
              : 'Saldo antes da próxima entrada após a simulação'),
          trailing: Text(currency.format(simulatedBalance)),
        ),
        if (_purchase > 0 && firstNewShortfall != null)
          Text(en
              ? 'This scenario introduces a new shortfall on ${date.format(firstNewShortfall)}.'
              : 'Esta simulação cria uma nova falta de saldo em ${date.format(firstNewShortfall)}.',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (alreadyNegative)
          Text(en
              ? 'Your existing schedule already shows a shortfall. Review scheduled bills independently of this simulation.'
              : 'Sua programação já apresenta falta de saldo. Revise as contas previstas independentemente desta simulação.'),
        if (_purchase > 0 && firstNewShortfall == null && !alreadyNegative)
          Text(en
              ? 'No new negative day found in the registered schedule.'
              : 'Nenhum novo dia negativo encontrado na programação cadastrada.'),
        Text(en
            ? 'Assumes this amount leaves your cash accounts today and every other scheduled event stays unchanged. Does not update a goal. Excludes unregistered bills and reserved money.'
            : 'Considera a saída desse valor das contas hoje, sem alterar os demais eventos. Não atualiza metas. Não inclui contas não cadastradas nem dinheiro reservado.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
