import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Solicita uma opinião sem coletar senhas, cartões ou lançamentos financeiros.
Future<void> showFolegoFeedbackDialog(
  BuildContext context,
  SupabaseClient client,
) async {
  final controller = TextEditingController();
  String kind = 'idea';
  bool sending = false;
  String? error;

  try {
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          scrollable: true,
          title: const Text('ajude a melhorar o Fôlego'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Conte o que está funcionando e o que podemos melhorar.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'sobre o quê?'),
                items: const [
                  DropdownMenuItem(value: 'idea', child: Text('uma ideia')),
                  DropdownMenuItem(value: 'bug', child: Text('um problema')),
                  DropdownMenuItem(value: 'praise', child: Text('um elogio')),
                ],
                onChanged: sending ? null : (value) {
                  if (value != null) setState(() => kind = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 5,
                maxLength: 2000,
                enabled: !sending,
                decoration: const InputDecoration(
                  labelText: 'sua mensagem',
                  hintText: 'o que você mudaria?',
                  border: OutlineInputBorder(),
                ),
              ),
              const Text(
                'Não inclua dados bancários, senhas ou números de cartão.',
                style: TextStyle(fontSize: 12),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending
                  ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text('cancelar'),
            ),
            FilledButton(
              onPressed: sending ? null : () async {
                final text = controller.text.trim();
                if (text.length < 8 || text.length > 2000) {
                  setState(() =>
                      error = 'escreva de 8 a 2.000 caracteres.');
                  return;
                }
                setState(() { sending = true; error = null; });
                try {
                  // O próprio banco usa auth.uid() e RLS para isolar o remetente.
                  await client.from('folego_product_feedback').insert({
                    'kind': kind,
                    'message': text,
                  });
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (_) {
                  if (dialogContext.mounted) {
                    setState(() {
                      error = 'não consegui enviar agora. tente novamente.';
                      sending = false;
                    });
                  }
                }
              },
              child: Text(sending ? 'enviando…' : 'enviar'),
            ),
          ],
        ),
      ),
    );
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('obrigado! sua mensagem foi enviada.')),
      );
    }
  } finally {
    controller.dispose();
  }
}
