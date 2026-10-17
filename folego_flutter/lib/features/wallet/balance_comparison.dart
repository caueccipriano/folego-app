import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/utils/formatters.dart';

/// Local comparison only. Never writes an adjustment or persists bank data.
int? balanceInputCents(String raw) {
  final text = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (!RegExp(r'^-?(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,\d{1,2})?$').hasMatch(text)) {
    return null;
  }
  final value = num.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));
  return value == null || !value.isFinite ? null : (value * 100).round();
}

class BalanceComparison extends StatefulWidget {
  const BalanceComparison({super.key, required this.balance});
  final num balance;
  @override
  State<BalanceComparison> createState() => _BalanceComparisonState();
}

class _BalanceComparisonState extends State<BalanceComparison> {
  final _input = TextEditingController();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: FinancialPrivacy.hidden,
    builder: (context, hidden, _) {
      final cents = balanceInputCents(_input.text);
      final difference = cents == null
          ? null
          : cents - (widget.balance * 100).round();
      return ExpansionTile(
        title: const Text('conferir com o banco'),
        subtitle: const Text('comparação temporária · não altera o saldo'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Use o saldo em conta do extrato, sem incluir limite de cheque especial. Compare registros do mesmo momento.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            obscureText: hidden,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: 'saldo no banco (R\$)',
              hintText: 'ex.: 1.234,56',
              errorText: _input.text.isNotEmpty && cents == null
                  ? 'use um valor como 123,45'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'saldo registrado no Fôlego: ${Formatters.money(widget.balance)}',
          ),
          if (difference != null) ...[
            Text(
              'diferença (banco − Fôlego): ${Formatters.money(difference / 100)}',
            ),
            Text(
              difference == 0 ? 'os valores coincidem nesta comparação.' : 'confira as movimentações abaixo: podem faltar registros, existir duplicidades ou haver diferença de horário. nenhuma taxa ou ajuste foi criado.',
            ),
          ],
          const Text(
            'O valor digitado fica apenas nesta tela e é descartado ao sair.',
          ),
        ],
      );
    },
  );
}
