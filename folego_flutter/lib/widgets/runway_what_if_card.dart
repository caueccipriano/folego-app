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
  @override
  Widget build(BuildContext context) {
    final runway = widget.preparation.runway;
    if (runway == null || runway.days.isEmpty) return const SizedBox.shrink();
    final en = Localizations.localeOf(context).languageCode == 'en';
    final currency = NumberFormat.currency(
      locale: en ? 'en_US' : 'pt_BR', symbol: 'BRL',
    );
    final simulatedBalance = runway.balanceAtPayday - _purchase;
    final affected = runway.days.where((day) =>
        day.closingBalance - _purchase < 0).toList();
    final firstShortfall = affected.isEmpty ? null : affected.first.date;
    final date = DateFormat.yMd(en ? 'en_US' : 'pt_BR');
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(en ? 'What if I buy something today?' : 'E se eu comprar algo hoje?'),
      subtitle: Text(en ? 'Simulation only — no transaction is created'
          : 'Apenas simulação — nenhum lançamento é criado'),
      children: [
        Text(en ? 'Hypothetical purchase: ${currency.format(_purchase)}'
            : 'Compra hipotética: ${currency.format(_purchase)}'),
        Slider(
          value: _purchase, min: 0, max: 2000, divisions: 40,
          label: currency.format(_purchase),
          onChanged: (value) => setState(() => _purchase = value),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(en ? 'Balance before next income after purchase'
              : 'Saldo antes da próxima entrada após a compra'),
          trailing: Text(currency.format(simulatedBalance)),
        ),
        if (firstShortfall != null)
          Text(en
              ? 'Possible shortfall starting ${date.format(firstShortfall)}.'
              : 'Possível falta de saldo a partir de ${date.format(firstShortfall)}.',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        Text(en
            ? 'Assumes the purchase is paid in cash today and every other scheduled event stays unchanged. Excludes unregistered bills and reserved money.'
            : 'Considera pagamento à vista hoje, sem alterar os demais eventos previstos. Não inclui contas não cadastradas nem dinheiro reservado.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
