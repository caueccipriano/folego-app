import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FolegoFeedbackScreen extends StatefulWidget {
  const FolegoFeedbackScreen({super.key, required this.client});
  final SupabaseClient client;

  @override
  State<FolegoFeedbackScreen> createState() => _FolegoFeedbackScreenState();
}

class _FolegoFeedbackScreenState extends State<FolegoFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _kind = 'idea';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() { _sending = true; _error = null; });
    try {
      await widget.client.from('folego_product_feedback').insert({
        'kind': _kind,
        'message': _messageController.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'não foi possível enviar sua sugestão. tente novamente.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const options = [
      ('idea', 'ideia'),
      ('bug', 'problema'),
      ('praise', 'elogio'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('enviar sugestão')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('ajude a melhorar o Fôlego', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          const Text(
            'Conte sua experiência. Não envie saldos, números de cartão, senhas ou outros dados financeiros.',
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option.$2),
                selected: _kind == option.$1,
                onSelected: _sending ? null : (_) => setState(() => _kind = option.$1),
              ),
          ]),
          const SizedBox(height: 18),
          Form(key: _formKey, child: TextFormField(
            controller: _messageController,
            enabled: !_sending,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'sua mensagem',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final length = value?.trim().length ?? 0;
              if (length < 8) return 'escreva pelo menos 8 caracteres';
              if (length > 2000) return 'máximo de 2.000 caracteres';
              return null;
            },
          )),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send_rounded),
            label: Text(_sending ? 'enviando...' : 'enviar sugestão'),
          ),
        ]),
      ))),
    );
  }
}
