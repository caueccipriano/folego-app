import 'package:flutter/material.dart';
import '../../data/models/onboarding_state.dart';

/// Guided setup that uses real backend completion flags, never fake progress.
class SetupChecklist extends StatelessWidget {
  const SetupChecklist({
    super.key,
    required this.state,
    required this.onNavigate,
    required this.onRefresh,
    required this.onDismiss,
  });

  final OnboardingState state;
  final ValueChanged<int> onNavigate;
  final VoidCallback onRefresh;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final steps = <({String title, String help, bool done, int tab})>[
      (title: 'Adicione sua primeira conta', help: 'Informe seu banco e o saldo atual.', done: state.hasAccount, tab: 3),
      (title: 'Registre sua renda', help: 'Cadastre seu salário ou outra entrada.', done: state.hasConfirmedIncome, tab: 1),
      (title: 'Organize despesas fixas', help: 'Inclua aluguel, assinaturas e contas recorrentes.', done: state.recurringExpenseCount > 0, tab: 1),
      (title: 'Configure seu orçamento', help: 'Defina quanto pretende gastar.', done: state.budgetConfigured, tab: 2),
      (title: 'Adicione um cartão (opcional)', help: 'Acompanhe compras e faturas.', done: state.hasCard, tab: 3),
      (title: 'Planeje sua reserva (opcional)', help: 'Escolha uma meta para imprevistos.', done: state.reserveConfigured, tab: 2),
    ];
    final done = steps.where((step) => step.done).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text('Seu Fôlego começa aqui', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(tooltip: 'Fazer depois', onPressed: onDismiss, icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 6),
            const Text('Vamos organizar seu dinheiro juntos. Você pode pular qualquer etapa e voltar depois.'),
            const SizedBox(height: 12),
            Semantics(label: '$done de 6 etapas concluídas',
              child: LinearProgressIndicator(value: done / steps.length, minHeight: 5)),
            const SizedBox(height: 12),
            Flexible(child: ListView.builder(
              shrinkWrap: true,
              itemCount: steps.length,
              itemBuilder: (context, i) {
                final step = steps[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(step.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: step.done ? Theme.of(context).colorScheme.primary : null),
                  title: Text(step.title),
                  subtitle: Text(step.help),
                  trailing: step.done ? null : const Icon(Icons.chevron_right),
                  onTap: step.done ? null : () => onNavigate(step.tab),
                );
              },
            )),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: onRefresh,
              icon: const Icon(Icons.refresh), label: const Text('Atualizar meu progresso')),
            TextButton(onPressed: onDismiss, child: const Text('Explorar o app por enquanto')),
          ],
        ),
      ),
    );
  }
}
