import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/intelligence/financial_insights_service.dart';

/// Only monthly aggregate totals are shared with the AI provider.
class FinancialAiCard extends StatefulWidget {
  const FinancialAiCard({super.key, required this.service, required this.spaceId, this.embedded = false});
  final FinancialInsightsService service;
  final String spaceId;
  final bool embedded;
  @override
  State<FinancialAiCard> createState() => _FinancialAiCardState();
}

class _FinancialAiCardState extends State<FinancialAiCard> {
  final _question = TextEditingController();
  bool _busy = false;
  String? _answer;
  bool _isError = false;
  @override
  void dispose() { _question.dispose(); super.dispose(); }

  Future<void> _ask() async {
    final question = _question.text.trim();
    if (question.length < 3 || question.length > 500) {
      setState(() => _answer = 'Escreva uma pergunta de 3 a 500 caracteres.');
      return;
    }
    setState(() { _busy = true; _answer = null; _isError = false; });
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
        setState(() { _isError = true; _answer = data is Map && data['error'] is String
            ? data['error'] as String
            : 'O assistente ainda não está disponível. Tente novamente.'; });
        return;
      }
      setState(() => _answer = data['answer'] as String);
    } on FunctionException catch (error) {
      final details = error.details;
      if (mounted) {
        setState(() {
          _isError = true;
          _answer = details is Map && details['error'] is String
              ? details['error'] as String
              : 'O assistente está indisponível no momento. Tente novamente mais tarde.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _isError = true; _answer =
            'Não foi possível conectar ao assistente. Tente novamente em instantes.'; });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.fromLTRB(widget.embedded ? 20 : 18, 16, widget.embedded ? 20 : 18, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.embedded) ...[
          Text('Pergunte ao Fôlego ✨', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
        ],
        Text('Acesso antecipado · até 30 perguntas por mês', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('A IA recebe apenas os totais do mês, nunca seus lançamentos individuais.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ActionChip(label: const Text('Como está meu mês?'),
            onPressed: _busy ? null : () => setState(() => _question.text = 'Como está minha situação financeira neste mês?')),
          ActionChip(label: const Text('Onde posso melhorar?'),
            onPressed: _busy ? null : () => setState(() => _question.text = 'O que posso melhorar no orçamento com os totais disponíveis?')),
        ]),
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
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _busy ? null : _ask,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_busy ? 'Consultando…' : 'Perguntar à IA'),
        )),
        if (_answer != null) Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isError ? theme.colorScheme.errorContainer : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isError ? 'Não foi possível responder' : 'Resposta do Fôlego',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SelectableText(_answer!),
              ]),
            ),
          ),
        ),
      ]),
    );
    return widget.embedded ? content : Card(child: content);
  }
}
