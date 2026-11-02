import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/folego_repository.dart';
import 'financial_ai_context.dart';

/// Read-only questions, using the existing authenticated financial-ai function.
/// The user explicitly submits each question; no automatic model requests.
class FinancialAiScreen extends StatefulWidget {
  const FinancialAiScreen({
    super.key,
    required this.client,
    required this.repository,
    required this.spaceId,
  });

  final SupabaseClient client;
  final FolegoRepository repository;
  final String spaceId;

  @override
  State<FinancialAiScreen> createState() => _FinancialAiScreenState();
}

class _FinancialAiScreenState extends State<FinancialAiScreen> {
  final _question = TextEditingController();
  bool _sending = false;
  String? _answer;
  String? _error;

  @override
  void didUpdateWidget(covariant FinancialAiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      _answer = null;
      _error = null;
      _question.clear();
    }
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_sending || FinancialPrivacy.hidden.value) return;
    final question = _question.text.trim();
    if (question.length < 3 || question.length > 500) {
      setState(() => _error = 'Escreva uma pergunta de 3 a 500 caracteres.');
      return;
    }
    final requestedSpaceId = widget.spaceId;
    final requestedClient = widget.client;
    final requestedRepository = widget.repository;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _answer = null;
    });

    try {
      // The server calculates money semantics. Never derive balance from
      // transactions on the client or send transaction-level information.
      final monthly = await requestedRepository.getMonthlyMoneySummary(
        spaceId: requestedSpaceId,
      );
      if (!mounted || widget.spaceId != requestedSpaceId ||
          widget.client != requestedClient ||
          widget.repository != requestedRepository) {
        return;
      }
      final response = await requestedClient.functions.invoke(
        'financial-ai',
        body: {
          'question': question,
          'context': financialAiMonthlyContext(
            month: monthly.periodMonth,
            income: monthly.realIncome,
            competenceExpenses: monthly.competenceExpenses,
          ),
        },
      );
      if (!mounted || widget.spaceId != requestedSpaceId) return;
      final payload = response.data;
      final answer = payload is Map ? payload['answer'] : null;
      if (answer is! String || answer.trim().isEmpty) {
        throw const FormatException('Resposta vazia');
      }
      setState(() => _answer = answer.trim());
    } on FunctionException catch (_) {
      if (!mounted || widget.spaceId != requestedSpaceId) return;
      setState(() => _error =
          'A IA não respondeu. Confira seu acesso Premium e a '
          'configuração do provedor. Nenhuma alteração foi feita.');
    } catch (_) {
      if (!mounted || widget.spaceId != requestedSpaceId) return;
      setState(() => _error =
          'Não foi possível consultar o resumo ou a IA agora. '
          'Seus dados continuam intactos.');
    } finally {
      if (mounted && widget.spaceId == requestedSpaceId) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('perguntar ao Fôlego')),
      body: ValueListenableBuilder<bool>(
        valueListenable: FinancialPrivacy.hidden,
        builder: (context, hidden, _) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Text('um olhar sobre seu mês',
                    style: AppTypography.section(context, fontSize: 22)),
                  const SizedBox(height: 10),
                  Text(
                    'A IA usa apenas receitas, despesas por competência '
                    'e resultado mensal consolidados. Não recebe lançamentos '
                    'individuais, nomes de contas ou números de cartão. '
                    'Sua pergunta também é enviada ao provedor de IA.',
                    style: AppTypography.body(context, fontSize: 13,
                      color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey('financial-ai-question'),
                    controller: _question,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    enabled: !_sending && !hidden,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'o que você quer entender?',
                      hintText: 'Como está meu resultado neste mês?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final prompt in const [
                      'Como está meu mês?',
                      'Minha despesa está acima da receita?',
                      'O que os totais dizem sobre meu orçamento?',
                    ])
                      ActionChip(
                        label: Text(prompt),
                        onPressed: _sending || hidden
                            ? null
                            : () => _question.text = prompt,
                      ),
                  ]),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('financial-ai-submit'),
                    onPressed: _sending || hidden ? null : _ask,
                    icon: _sending
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(_sending ? 'consultando...' : 'perguntar'),
                  ),
                  if (hidden) ...[
                    const SizedBox(height: 12),
                    const Text('Desative o modo privativo para consultar '
                      'ou visualizar uma resposta financeira.'),
                  ],
                  if (_error != null && !hidden) ...[
                    const SizedBox(height: 16),
                    Text(_error!, key: const ValueKey('financial-ai-error'),
                      style: TextStyle(color: colors.error)),
                  ],
                  if (_answer != null && !hidden) ...[
                    const SizedBox(height: 24),
                    Text('resposta', style: AppTypography.cardTitle(context)),
                    const SizedBox(height: 8),
                    SelectableText(_answer!,
                      key: const ValueKey('financial-ai-answer'),
                      style: AppTypography.body(context, fontSize: 15)),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'A IA pode errar. Confira números e decisões no '
                    'planejamento. Ela não registra nem edita movimentações.',
                    style: AppTypography.label(context, fontSize: 12,
                      color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
