import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/intelligence/financial_insights_service.dart';

/// Only monthly aggregate totals are shared with the AI provider.
class FinancialAiCard extends StatefulWidget {
  const FinancialAiCard({super.key, required this.service, required this.spaceId});
  final FinancialInsightsService service;
  final String spaceId;
  @override
  State<FinancialAiCard> createState() => _FinancialAiCardState();
}

class _FinancialAiCardState extends State<FinancialAiCard> {
  final _question = TextEditingController();
  bool _busy = false;
  String? _answer;
  @override
  void dispose() { _question.dispose(); super.dispose(); }

  Future<void> _ask() async {
    final question = _question.text.trim();
    if (question.length < 3 || question.length > 500) {
      setState(() => _answer = 'Escreva uma pergunta de 3 a 500 caracteres.');
      return;
    }
    setState(() { _busy = true; _answer = null; });
    try {
      final month = DateTime.now();
      final report = await widget.service.monthly(spaceId: widget.spaceId, month: month);
      final result = await Supabase.instance.client.functions.invoke(
        'financial-ai',
        body: {
          'question': question,
          'context': {
            'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
            'income': report.income,
            'expenses': report.expenses,
            'result': report.result,
          },
        },
      );
      final data = result.data;
      if (!mounted) return;
      if (result.status != 200 || data is! Map || data['answer'] is! String) {
        setState(() => _answer = data is Map && data['error'] is String
            ? data['error'] as String
            : 'O assistente ainda não está disponível. Tente novamente.');
        return;
      }
      setState(() => _answer = data['answer'] as String);
    } catch (_) {
      if (mounted) setState(() => _answer =
          'Não foi possível consultar a IA. Verifique sua conexão, plano e configuração do assistente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pergunte ao Fôlego ✨', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text('Premium · até 30 perguntas por mês. Compartilhamos com a IA apenas totais agregados do mês, nunca seus lançamentos individuais.'),
        const SizedBox(height: 12),
        TextField(
          controller: _question,
          enabled: !_busy,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'O que você quer entender?',
            hintText: 'Como está meu resultado deste mês?',
            border: OutlineInputBorder(),
          ),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _ask,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_busy ? 'Consultando…' : 'Perguntar à IA'),
        ),
        if (_answer != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SelectableText(_answer!),
        ),
      ]),
    ),
  );
}
