import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import 'demo_ledger.dart';
import 'discovery_model.dart';
import 'discovery_screen.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});
  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _ledger = DemoLedger();
  bool? _dark;
  Future<void> _addExpense(BuildContext context) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('simular um gasto'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: description,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'descrição'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Dê um nome ao gasto.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'valor em reais',
                    hintText: '25,00',
                  ),
                  validator: (value) {
                    final parsed = Formatters.parseMoney(value ?? '')
                        .toDouble();
                    return parsed.isFinite && parsed > 0 && parsed <= 999999
                        ? null
                        : 'Informe um valor entre 0,01 e 999.999.';
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Somente nesta demonstração. Nada será salvo na sua conta.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(dialogContext, (
                description.text,
                Formatters.parseMoney(amount.text).toDouble(),
              ));
            },
            child: const Text('simular gasto'),
          ),
        ],
      ),
    );
    if (mounted && result != null)
      setState(() => _ledger.addExpense(result.$1, result.$2));
    // Controllers remain alive until the dialog's exit animation completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    description.dispose();
    amount.dispose();
  }

  Future<void> _details(BuildContext context, DiscoveryEntry entry) async {
    final actionable = _ledger.pending.any((item) => item.id == entry.id);
    final complete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.subtitle),
            if (entry.amount != null) Text(Formatters.money(entry.amount)),
            const SizedBox(height: 12),
            const Text(
              'Dados fictícios. Uma conclusão simulada remove o lembrete; não representa pagamento ou movimentação.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('voltar'),
          ),
          if (actionable)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('simular conclusão'),
            ),
        ],
      ),
    );
    if (mounted && complete == true) setState(() => _ledger.complete(entry));
  }

  Future<void> _explore(BuildContext context, bool pendingOnly) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => DiscoveryScreen(
          identity: 'demo',
          pendingOnly: pendingOnly,
          load: () async => _ledger.data,
          onOpen: (entry) => _details(routeContext, entry),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = _dark ?? Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: dark ? AppTheme.dark() : AppTheme.light(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Fôlego · demonstração'),
            actions: [
              IconButton(
                tooltip: dark ? 'testar modo claro' : 'testar modo escuro',
                onPressed: () => setState(() => _dark = !dark),
                icon: Icon(
                  dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'experimente à vontade',
                    style: AppTypography.display(context, fontSize: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tudo aqui é fictício e fica somente nesta sessão. Ao sair, a demonstração é descartada. Sua conta e sua planilha não são acessadas.',
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('saldo fictício · conta dia a dia'),
                          const SizedBox(height: 12),
                          Text(
                            Formatters.money(_ledger.balance),
                            style: AppTypography.money(context, fontSize: 32),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'O saldo sozinho não indica quanto está livre para gastar. Existem compromissos previstos abaixo.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: () => _addExpense(context),
                        child: const Text('simular gasto'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _explore(context, false),
                        icon: const Icon(AppIcons.search),
                        label: const Text('buscar nos exemplos'),
                      ),
                      OutlinedButton(
                        onPressed: () => _explore(context, true),
                        child: Text('pendências (${_ledger.pending.length})'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'compromissos e revisões',
                    style: AppTypography.section(context),
                  ),
                  for (final entry in _ledger.pending)
                    ListTile(
                      title: Text(entry.title),
                      subtitle: Text(entry.subtitle),
                      trailing: const Icon(AppIcons.forward),
                      onTap: () => _details(context, entry),
                    ),
                  if (_ledger.pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Você conferiu todos os exemplos.'),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'últimos lançamentos',
                    style: AppTypography.section(context),
                  ),
                  for (final entry in _ledger.transactions.take(6))
                    ListTile(
                      title: Text(entry.title),
                      subtitle: Text(
                        '${entry.subtitle}\n${Formatters.money(entry.amount)}',
                      ),
                      onTap: () => _details(context, entry),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(_ledger.reset),
                    child: const Text('recomeçar demonstração'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('sair da demonstração'),
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
