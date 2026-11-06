import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_typography.dart';
import 'financial_ai_status.dart';
import 'financial_ai_answer_view.dart';
import 'financial_ai_answer_actions.dart';
import 'financial_ai_prompt_suggestions.dart';

/// Read-only questions, using the existing authenticated financial-ai function.
/// The user explicitly submits each question; no automatic model requests.
class FinancialAiScreen extends StatefulWidget {
  const FinancialAiScreen({
    super.key,
    required this.client,
    required this.spaceId,
    this.onOpenPlan,
  });

  final SupabaseClient client;
  final String spaceId;
  final VoidCallback? onOpenPlan;

  @override
  State<FinancialAiScreen> createState() => _FinancialAiScreenState();
}

class _FinancialAiScreenState extends State<FinancialAiScreen> {
  final _question = TextEditingController();
  bool _sending = false;
  String? _answer;
  String? _error;
  String? _focusTitle;
  String? _focusDescription;
  String? _answerProvider;
  String? _answerNotice;
  String? _providerName;
  bool? _providerConfigured;
  bool _checkingProvider = true;
  int _requestSerial = 0;
  int _providerSerial = 0;

  @override
  void initState() {
    super.initState();
    _checkProvider();
  }

  /// Status-only check: no AI generation, transactions, or quota use.
  Future<void> _checkProvider() async {
    final client = widget.client;
    final serial = ++_providerSerial;
    if (mounted) setState(() => _checkingProvider = true);
    try {
      final response = await client.functions.invoke(
        'financial-ai', method: HttpMethod.get,
      );
      if (!mounted || widget.client != client || serial != _providerSerial) return;
      final data = response.data;
      setState(() {
        _providerName = data is Map
            ? financialAiProviderName(data['provider']) : null;
        _providerConfigured = data is Map && data['configured'] is bool
            ? data['configured'] as bool : null;
      });
    } catch (_) {
      if (!mounted || widget.client != client || serial != _providerSerial) return;
      setState(() {
        _providerConfigured = null;
        _providerName = null;
      });
    } finally {
      if (mounted && widget.client == client && serial == _providerSerial) {
        setState(() => _checkingProvider = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant FinancialAiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.client != widget.client) {
      // Cancel ownership of in-flight replies before showing a new space.
      // The network call may finish, but it must never lock or repopulate
      // the current screen with an earlier space's information.
      _requestSerial++;
      _sending = false;
      _answer = null;
      _error = null;
      _focusTitle = null;
      _focusDescription = null;
      _answerProvider = null;
      _answerNotice = null;
      _question.clear();
    }
    if (oldWidget.client != widget.client) {
      _providerConfigured = null;
      _providerName = null;
      _checkProvider();
    }
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() => _submit();

  Future<void> _showSummary() => _submit(withoutAi: true);

  Future<void> _submit({bool withoutAi = false}) async {
    if (_sending || FinancialPrivacy.hidden.value ||
        (!withoutAi && _providerConfigured == false)) {
      return;
    }
    final question = withoutAi
        ? 'Como está meu mês?'
        : _question.text.trim();
    if (question.length < 3 || question.length > 500) {
      setState(() => _error = 'Escreva uma pergunta de 3 a 500 caracteres.');
      return;
    }
    final requestedSpaceId = widget.spaceId;
    final requestedClient = widget.client;
    final serial = ++_requestSerial;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _answer = null;
      _focusTitle = null;
      _focusDescription = null;
      _answerProvider = null;
      _answerNotice = null;
    });

    try {
      // The server verifies this space and derives canonical totals.
      // No client-side financial RPC, event IDs or monetary values are sent.
      final response = await requestedClient.functions.invoke(
        'financial-ai',
        body: {
          'question': question,
          'spaceId': requestedSpaceId,
          if (withoutAi) 'mode': 'summary',
        },
      );
      if (!mounted || serial != _requestSerial ||
          widget.spaceId != requestedSpaceId ||
          widget.client != requestedClient) {
        return;
      }
      final payload = response.data;
      final answer = payload is Map ? payload['answer'] : null;
      if (answer is! String || answer.trim().isEmpty) {
        throw const FormatException('Resposta vazia');
      }
      final focus = payload is Map ? payload['focus'] : null;
      final focusTitle = focus is Map ? focus['title'] : null;
      final focusDescription = focus is Map ? focus['description'] : null;
      setState(() {
        _answer = answer.trim();
        _answerProvider = payload is Map
            ? financialAiProviderName(payload['provider']) : null;
        final responseMode = payload is Map ? payload['mode'] : null;
        _answerNotice = responseMode == 'fallback'
            ? 'O provedor de IA não concluiu a resposta. Este resumo foi '
                'calculado pelo Fôlego, sem geração de texto por IA.'
            : responseMode == 'summary'
                ? 'Resumo dos registros financeiros, sem utilizar '
                    'perguntas Premium ou serviços de IA.'
                : null;
        _focusTitle = focusTitle is String ? focusTitle : null;
        _focusDescription = focusDescription is String
            ? focusDescription : null;
      });
    } on FunctionException catch (error) {
      if (!mounted || serial != _requestSerial ||
          widget.spaceId != requestedSpaceId ||
          widget.client != requestedClient) {
        return;
      }
      setState(() => _error =
          financialAiErrorMessage(error.status, error.details));
    } catch (_) {
      if (!mounted || serial != _requestSerial ||
          widget.spaceId != requestedSpaceId ||
          widget.client != requestedClient) {
        return;
      }
      setState(() => _error =
          'Não foi possível consultar o resumo ou a IA agora. '
          'Seus dados continuam intactos.');
    } finally {
      if (mounted && serial == _requestSerial &&
          widget.spaceId == requestedSpaceId &&
          widget.client == requestedClient) {
        setState(() => _sending = false);
      }
    }
  }

  /// Copy only after a deliberate tap. Never place sensitive data on the
  /// clipboard when privacy mode is active, or expose a stale-space toast.
  Future<void> _copyAnswer() async {
    final answer = _answer;
    if (answer == null || FinancialPrivacy.hidden.value) return;
    try {
      await Clipboard.setData(ClipboardData(text: answer));
      if (!mounted || FinancialPrivacy.hidden.value || _answer != answer) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resposta copiada. Compartilhe com cuidado.')),
      );
    } catch (_) {
      if (!mounted || FinancialPrivacy.hidden.value || _answer != answer) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível copiar a resposta.')),
      );
    }
  }

  /// Forget the visible explanation locally; no ledger or server mutation.
  void _clearAnswer() {
    if (_answer == null || FinancialPrivacy.hidden.value) return;
    setState(() {
      _answer = null;
      _answerProvider = null;
      _answerNotice = null;
      _focusTitle = null;
      _focusDescription = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('assistente Fôlego')),
      body: ValueListenableBuilder<bool>(
        valueListenable: FinancialPrivacy.hidden,
        builder: (context, hidden, _) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Text('entenda seu dinheiro',
                    style: AppTypography.section(context, fontSize: 25)),
                  const SizedBox(height: 10),
                  Text(
                    'Pergunte sobre seu orçamento e receba uma resposta curta, '
                    'baseada nos dados confirmados, com uma ação para revisar.',
                    style: AppTypography.body(context, fontSize: 13,
                      color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    key: const ValueKey('financial-ai-provider-status'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18, color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _checkingProvider
                                ? 'verificando a IA...'
                                : _providerConfigured == true
                                    ? '${_providerName ?? 'gemini'} configurado · consultas podem usar cota Premium'
                                    : _providerConfigured == false
                                        ? 'gemini indisponível · resumo sem IA disponível'
                                        : 'não foi possível conferir a IA · resumo sem IA disponível',
                            style: AppTypography.body(context, fontSize: 12),
                          ),
                        ),
                        if (!_checkingProvider)
                          IconButton(
                            key: const ValueKey('financial-ai-refresh-status'),
                            onPressed: _checkProvider,
                            tooltip: 'Verificar novamente',
                            icon: const Icon(Icons.refresh, size: 19),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ExpansionTile(
                    key: const ValueKey('financial-ai-privacy-details'),
                    title: Text('privacidade e limites',
                      style: AppTypography.body(context, fontSize: 12)),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      Text(
                        'Enviamos sua pergunta e somente totais de receitas, '
                        'despesas e até quatro categorias agregadas, '
                        'comparadas por dias equivalentes. A IA não recebe '
                        'movimentações individuais, contas nem cartões. '
                        'Cada consulta pode consumir uma pergunta Premium. No plano '
                        'gratuito da API gemini, o Google pode utilizar o '
                        'conteúdo agregado enviado para melhorar seus '
                        'produtos. Os limites gratuitos não são ilimitados.',
                        style: AppTypography.body(context, fontSize: 12,
                          color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('financial-ai-question'),
                    controller: _question,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    style: AppTypography.body(context, fontSize: 14),
                    enabled: !_sending && !hidden,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'o que você quer entender?',
                      hintText: 'Como está meu resultado neste mês?',
                      border: const OutlineInputBorder(),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _question,
                        builder: (context, draft, _) => draft.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              key: const ValueKey('financial-ai-clear-question'),
                              tooltip: 'Limpar pergunta',
                              onPressed: _sending || hidden
                                  ? null : _question.clear,
                              icon: const Icon(Icons.close_rounded, size: 19),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escolha uma pergunta ou escreva a sua. Só tocar em Perguntar '
                    'envia uma consulta Premium.',
                    style: AppTypography.label(context, fontSize: 12,
                      color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  FinancialAiPromptSuggestions(
                    enabled: !_sending && !hidden,
                    onSelected: (prompt) {
                      _question.value = TextEditingValue(
                        text: prompt,
                        selection: TextSelection.collapsed(offset: prompt.length),
                      );
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: 14),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _question,
                    builder: (context, draft, _) {
                      final ready = draft.text.trim().length >= 3 &&
                          draft.text.trim().length <= 500;
                      return FilledButton.icon(
                        key: const ValueKey('financial-ai-submit'),
                        onPressed: _sending || hidden || !ready ||
                            _providerConfigured == false ? null : _ask,
                        icon: _sending
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome_outlined),
                        label: Text(_sending ? 'consultando...' : 'perguntar'),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const ValueKey('financial-ai-local-summary'),
                    onPressed: _sending || hidden ? null : _showSummary,
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('ver resumo sem IA · não usa cota'),
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
                  if (_answerNotice != null && !hidden) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 18,
                          color: colors.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_answerNotice!,
                          key: const ValueKey('financial-ai-local-notice'),
                          style: AppTypography.body(context,
                            fontSize: 12, color: colors.onSurfaceVariant))),
                      ]),
                    ),
                  ],
                  if (_focusTitle != null && !hidden) ...[
                    const SizedBox(height: 20),
                    Container(
                      key: const ValueKey('financial-ai-focus'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('uma coisa para conferir',
                            style: AppTypography.label(context,
                              color: colors.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          Text(_focusTitle!,
                            style: AppTypography.cardTitle(context)),
                          if (_focusDescription != null) ...[
                            const SizedBox(height: 4),
                            Text(_focusDescription!,
                              style: AppTypography.body(context,
                                color: colors.onSurfaceVariant)),
                          ],
                          if (widget.onOpenPlan != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              key: const ValueKey('financial-ai-open-plan'),
                              onPressed: widget.onOpenPlan,
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('ver no planejamento'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_answer != null && !hidden) ...[
                    const SizedBox(height: 24),
                    Row(children: [
                      Text('resposta',
                        style: AppTypography.cardTitle(context)),
                      const Spacer(),
                      if (_answerProvider != null)
                        Text(_answerProvider == 'Cálculo do Fôlego'
                            ? 'cálculo do Fôlego' : 'via $_answerProvider',
                          key: const ValueKey('financial-ai-answer-provider'),
                          style: AppTypography.label(context,
                            color: colors.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 8),
                    FinancialAiAnswerView(
                      key: const ValueKey('financial-ai-answer'),
                      answer: _answer!,
                    ),
                    const SizedBox(height: 10),
                    FinancialAiAnswerActions(
                      enabled: !_sending,
                      onCopy: () => _copyAnswer(),
                      onClear: _clearAnswer,
                    ),
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
