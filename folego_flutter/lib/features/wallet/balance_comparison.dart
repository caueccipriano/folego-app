import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  const BalanceComparison({super.key, required this.balance, this.reviewKey, this.benefit = false});
  final num balance;
  final String? reviewKey;
  final bool benefit;
  @override
  State<BalanceComparison> createState() => _BalanceComparisonState();
}

class _BalanceComparisonState extends State<BalanceComparison> {
  final _input = TextEditingController();
  final _preferences = SharedPreferencesAsync();
  DateTime? _reviewedAt;
  bool _reviewError = false;
  bool _saving = false;
  int _generation = 0;
  @override
  void initState() { super.initState(); _loadReview(); }
  @override
  void didUpdateWidget(covariant BalanceComparison oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reviewKey != widget.reviewKey) {
      _input.clear();
      _reviewedAt = null;
      _reviewError = false;
      _saving = false;
      _loadReview();
    }
  }
  Future<void> _loadReview() async {
    final generation = ++_generation;
    final key = widget.reviewKey;
    if (key == null) { return; }
    try {
      final raw = await _preferences.getString(key);
      if (!mounted || generation != _generation) { return; }
      setState(() { _reviewedAt = DateTime.tryParse(raw ?? ''); _reviewError = false; });
    } catch (_) {
      if (mounted && generation == _generation) { setState(() => _reviewError = true); }
    }
  }
  Future<void> _markReviewed() async {
    final key = widget.reviewKey;
    final cents = balanceInputCents(_input.text);
    if (key == null || _saving || cents != (widget.balance * 100).round()) { return; }
    final generation = _generation;
    final at = DateTime.now().toUtc();
    setState(() => _saving = true);
    try {
      await _preferences.setString(key, at.toIso8601String());
      if (!mounted || generation != _generation) { return; }
      setState(() { _reviewedAt = at; _reviewError = false; _saving = false; });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() { _reviewError = true; _saving = false; });
      }
    }
  }
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
        title: Text(widget.benefit ? 'conferir saldo do benefício' : 'conferir com o banco'),
        subtitle: const Text('comparação temporária · não altera o saldo'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Text(widget.benefit ? 'Compare com o saldo do aplicativo do benefício no mesmo momento.' : 'Use o saldo em conta do extrato, sem incluir limite de cheque especial. Compare registros do mesmo momento.'),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            obscureText: hidden,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: widget.benefit ? 'saldo no benefício (R\$)' : 'saldo no banco (R\$)',
              hintText: 'ex.: 1.234,56',
              errorText: _input.text.isNotEmpty && cents == null
                  ? 'use um valor como 123,45'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'saldo registrado no Fôlego: ${hidden ? '••••' : Formatters.money(widget.balance)}',
          ),
          if (difference != null) ...[
            Text(
              'diferença (banco − Fôlego): ${hidden ? '••••' : Formatters.money(difference / 100)}',
            ),
            Text(
              difference == 0 ? 'os valores coincidem nesta comparação.' : 'confira as movimentações abaixo: podem faltar registros, existir duplicidades ou haver diferença de horário. nenhuma taxa ou ajuste foi criado.',
            ),
          ],
          const Text('O valor digitado fica apenas nesta tela e é descartado ao sair.'),
          const SizedBox(height: 12),
          Text(_reviewError
              ? 'não consegui consultar ou salvar a data da conferência'
              : _reviewedAt == null
                  ? 'nenhuma conferência manual registrada neste aparelho'
                  : 'última conferência manual neste aparelho: ${Formatters.fullDate.format(_reviewedAt!.toLocal())} às ${_reviewedAt!.toLocal().hour.toString().padLeft(2, '0')}:${_reviewedAt!.toLocal().minute.toString().padLeft(2, '0')}'),
          OutlinedButton(
            onPressed: widget.reviewKey != null && difference == 0 && !_saving ? _markReviewed : null,
            child: Text(_saving ? 'registrando conferência' : 'confirmei o saldo no extrato'),
          ),
          const Text('A data só é registrada ao confirmar valores coincidentes. Ela não garante que o saldo continue atualizado e não é sincronizada entre aparelhos. Nenhum ajuste financeiro é criado.'),
        ],
      );
    },
  );
}

String accountReviewKey(String userId, String spaceId, String accountId) =>
    'folego.account_review.v1/$userId/$spaceId/$accountId';
