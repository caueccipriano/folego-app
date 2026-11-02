import 'package:flutter/material.dart';

/// Explicit, local-only actions on a completed financial explanation.
/// Parent hides the toolbar while privacy mode is enabled.
class FinancialAiAnswerActions extends StatelessWidget {
  const FinancialAiAnswerActions({
    super.key,
    required this.enabled,
    required this.onCopy,
    required this.onClear,
  });

  final bool enabled;
  final VoidCallback onCopy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Wrap(
    key: const ValueKey('financial-ai-answer-actions'),
    spacing: 8,
    runSpacing: 4,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('financial-ai-copy-answer'),
        onPressed: enabled ? onCopy : null,
        icon: const Icon(Icons.content_copy_rounded, size: 18),
        label: const Text('copiar resposta'),
      ),
      TextButton.icon(
        key: const ValueKey('financial-ai-clear-answer'),
        onPressed: enabled ? onClear : null,
        icon: const Icon(Icons.close_rounded, size: 18),
        label: const Text('limpar resposta'),
      ),
    ],
  );
}
