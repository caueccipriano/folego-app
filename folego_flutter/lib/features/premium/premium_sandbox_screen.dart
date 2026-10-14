import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'checkout_navigation.dart';

/// Visible only in explicitly configured test builds. Never grants app rights.
class PremiumSandboxScreen extends StatefulWidget {
  const PremiumSandboxScreen({super.key, required this.client, this.loadOverride});
  final SupabaseClient client;

  @visibleForTesting
  final Future<Map<String, dynamic>> Function()? loadOverride;

  @override
  State<PremiumSandboxScreen> createState() => _PremiumSandboxScreenState();
}

class _PremiumSandboxScreenState extends State<PremiumSandboxScreen> {
  bool _busy = true;
  bool _ready = false;
  bool _confirmed = false;
  String _status = 'consultando o ambiente de testes';
  String? _paidUntil;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final Object? data;
      if (widget.loadOverride != null) {
        data = await widget.loadOverride!();
      } else {
        final response = await widget.client.functions.invoke(
          'folego-asaas-checkout-sandbox', method: HttpMethod.get,
        );
        data = response.data;
      }
      if (data is! Map || data['environment'] != 'sandbox') {
        throw StateError('invalid_billing_status');
      }
      if (!mounted) return;
      setState(() {
        _ready = data['ready'] == true;
        _confirmed = data['paymentConfirmed'] == true;
        _paidUntil = data['paidUntil'] as String?;
        _status = _confirmed
            ? 'pagamento fictício confirmado pelo backend'
            : data['status'] == 'pending_or_expired'
                ? 'pagamento pendente ou período encerrado'
                : 'nenhuma assinatura de teste confirmada';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ready = false;
        _confirmed = false;
        _paidUntil = null;
        _status = 'teste indisponível. confira seu login e a configuração Sandbox';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout() async {
    if (_busy || !_ready || _confirmed) return;
    setState(() => _busy = true);
    try {
      final response = await widget.client.functions.invoke(
        'folego-asaas-checkout-sandbox', body: {'plan': 'monthly'},
      );
      final data = response.data;
      if (data is! Map || data['environment'] != 'sandbox' ||
          data['ready'] != true || data['checkoutUrl'] is! String ||
          !openSandboxCheckout(data['checkoutUrl'] as String)) {
        throw StateError('checkout_locked');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('não foi possível abrir o checkout de testes')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fôlego Premium')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('AMBIENTE DE TESTES · SEM COBRANÇA REAL'),
        const SizedBox(height: 16),
        Text('mais espaço para planejar', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text('R\$ 9,90/mês', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Text('Plano anual previsto: R\$ 89,90. Ainda indisponível.'),
        const SizedBox(height: 20),
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Free', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Seu controle financeiro e seus recursos atuais continuam disponíveis.'),
            SizedBox(height: 16),
            Text('Premium · em homologação', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Automações avançadas em preparação. Projeções e importação/exportação já existentes não serão retiradas nesta etapa.'),
          ],
        ))),
        const SizedBox(height: 16),
        Text(_status, key: const Key('billing-status')),
        if (_paidUntil != null) Text('Período de teste confirmado até: $_paidUntil'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy || !_ready || _confirmed ? null : _checkout,
          child: const Text('assinar mensal · Sandbox'),
        ),
        TextButton(onPressed: _busy ? null : _refresh, child: const Text('verificar pagamento')),
        const Text('Voltar do checkout não confirma o pagamento. Esta tela consulta apenas a assinatura fictícia e não altera seu acesso atual.'),
        const SizedBox(height: 16),
        const Text('Renovação mensal por cartão será validada no Asaas. Pix comum exige novo pagamento; Pix Automático depende de autorização e homologação próprias.'),
        const SizedBox(height: 16),
        const Text('Gerenciamento e cancelamento ainda não estão disponíveis nesta versão de testes. Não haverá venda pública antes de concluir esses fluxos.'),
      ]),
    )),
  );
}
