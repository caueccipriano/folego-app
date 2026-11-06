import 'package:flutter/material.dart';

/// Suggested question chips only draft text. Never invokes AI or uses a quota.
/// The parent screen must explicitly handle the separate submit action.
class FinancialAiPromptSuggestions extends StatelessWidget {
  const FinancialAiPromptSuggestions({
    super.key,
    required this.enabled,
    required this.onSelected,
  });

  final bool enabled;
  final ValueChanged<String> onSelected;

  // Only verified aggregated totals and comparable periods are available.
  static const questions = <String>[
    'Como está meu mês?',
    'Qual categoria merece atenção?',
    'O que mudou em meus gastos desde o mês anterior?',
    'Qual é a primeira coisa que devo revisar no meu orçamento?',
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    key: const ValueKey('financial-ai-prompt-suggestions'),
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var index = 0; index < questions.length; index++)
        ActionChip(
          key: ValueKey('financial-ai-prompt-$index'),
          tooltip: 'Preencher pergunta sem enviar',
          label: Text(questions[index]),
          onPressed: enabled ? () => onSelected(questions[index]) : null,
        ),
    ],
  );
}
