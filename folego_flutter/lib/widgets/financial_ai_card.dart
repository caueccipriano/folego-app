import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/intelligence/financial_insights_service.dart';
import '../core/theme/app_colors.dart';
import '../data/models/monthly_money_summary.dart';
import 'folego_home_section_card.dart';
import 'local_monthly_summary.dart';

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
  int _requestEpoch = 0;
  MonthlyMoneySummary? _localSummary;
  bool _showLocalSummary = false;

  // A widget may be reused when the selected household or repository changes.
  // Never display A's pending financial answer (or start an A request) inside B.
  @override
  void didUpdateWidget(covariant FinancialAiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        !identical(oldWidget.service.repository, widget.service.repository)) {
      _requestEpoch++;
      _question.clear();
      _answer = null;
      _isError = false;
      _busy = false;
      _localSummary = null;
      _showLocalSummary = false;
    }
  }

  @override
  void dispose() {
    _requestEpoch++;
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _question.text.trim();
    if (question.length < 3 || question.length > 500) {
      setState(() {
        _isError = true;
        _answer = 'Escreva uma pergunta de 3 a 500 caracteres.';
      });
      return;
    }
    final epoch = ++_requestEpoch;
    final spaceId = widget.spaceId;
    final repository = widget.service.repository;
    final userId = repository.currentUserId;
    bool current() =>
        mounted &&
        _requestEpoch == epoch &&
        widget.spaceId == spaceId &&
        identical(widget.service.repository, repository) &&
        repository.currentUserId == userId;

    setState(() {
      _busy = true;
      _answer = null;
      _isError = false;
      _localSummary = null;
      _showLocalSummary = false;
    });
    try {
      final month = DateTime.now();
      // Only current totals are needed; an unavailable previous month cannot block the question.
      final summary = await repository.getMonthlyMoneySummary(
        spaceId: spaceId, periodMonth: DateTime(month.year, month.month),
      );
      // A may have signed out or switched spaces while the summary was loading.
      if (!current()) return;
      _localSummary = summary;
      final result = await Supabase.instance.client.functions.invoke(
        'financial-ai',
        body: {
          'question': question,
          'context': {
            'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
            'income': summary.realIncome,
            'expenses': summary.competenceExpenses,
            'result': summary.economicResult,
          },
        },
      );
      final data = result.data;
      if (!current()) return;
      if (result.status != 200 || data is! Map || data['answer'] is! String) {
        setState(() { _isError = true; _answer = data is Map && data['error'] is String
            ? data['error'] as String
            : 'O assistente ainda não está disponível. Tente novamente.'; });
        return;
      }
      setState(() => _answer = data['answer'] as String);
    } on FunctionException catch (error) {
      final details = error.details;
      if (current()) {
        setState(() {
          _isError = true;
          _answer = details is Map && details['error'] is String
              ? details['error'] as String
              : 'O assistente está indisponível no momento. Tente novamente mais tarde.';
        });
      }
    } catch (_) {
      if (current()) {
        setState(() { _isError = true; _answer =
            'Não foi possível conectar ao assistente. Tente novamente em instantes.'; });
      }
    } finally {
      if (current()) {
        setState(() => _busy = false);
      } else if (mounted && _requestEpoch == epoch) {
        // Same widget, but Auth identity changed: drop every old-user trace.
        _requestEpoch++;
        setState(() {
          _busy = false;
          _answer = null;
          _isError = false;
          _question.clear();
          _localSummary = null;
          _showLocalSummary = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = AppColors.primaryPurple(brightness);
    final border = AppColors.border(brightness);
    final muted = AppColors.secondaryText(brightness);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.embedded) ...[
          const FolegoHomeSectionTitle('Pergunte ao Fôlego'),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Icon(Icons.auto_awesome, color: accent, size: 17),
          const SizedBox(width: 7),
          Expanded(child: Text('IA · acesso antecipado',
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Text('Até 30 perguntas por mês. Somente os totais do mês são '
             'enviados, nunca seus lançamentos.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        const SizedBox(height: 14),
        // One accessible horizontal row rather than two oversized chip rows
        // on a 375px iPhone screen.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ActionChip(
              label: const Text('Como está meu mês?'),
              onPressed: _busy ? null : () => setState(() =>
                _question.text = 'Como está minha situação financeira neste mês?'),
            ),
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('Onde posso melhorar?'),
              onPressed: _busy ? null : () => setState(() =>
                _question.text = 'O que posso melhorar no orçamento com os totais disponíveis?'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _question,
          enabled: !_busy,
          maxLength: 500,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Sua pergunta',
            hintText: 'O que você quer entender?',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _busy ? null : _ask,
          icon: const Icon(Icons.auto_awesome, size: 19),
          label: Text(_busy ? 'Consultando…' : 'Perguntar à IA',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        )),
        if (_answer != null) ...[
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isError
                    ? AppColors.background(brightness)
                    : accent.withValues(alpha: .06),
                border: Border.all(
                  color: _isError ? border : accent.withValues(alpha: .28)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_isError ? Icons.info_outline : Icons.auto_awesome,
                    color: accent, size: 17),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _isError ? 'IA indisponível' : 'Resposta do Fôlego',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700),
                  )),
                ]),
                const SizedBox(height: 6),
                SelectableText(_answer!, style: theme.textTheme.bodyMedium),
                if (_isError && _localSummary != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => setState(() =>
                      _showLocalSummary = !_showLocalSummary),
                    icon: Icon(_showLocalSummary
                      ? Icons.expand_less : Icons.assessment_outlined),
                    label: Text(_showLocalSummary
                      ? 'Ocultar resumo automático' : 'Ver resumo sem IA'),
                  ),
                ],
              ]),
            ),
          ),
        ],
        if (_isError && _showLocalSummary && _localSummary != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: .22)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Resumo automático · sem IA',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: accent, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SelectableText(buildLocalMonthlySummary(_localSummary!),
                style: theme.textTheme.bodyMedium),
            ]),
          ),
        ],
      ]),
    );
    return widget.embedded ? content : FolegoHomeSectionCard(child: content);
  }
}
