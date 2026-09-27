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
    final english = Localizations.localeOf(context).languageCode == 'en';
    final steps = <({String title, String help, bool done, int tab})>[
      (title: english ? 'Add your first account' : 'Adicione sua primeira conta', help: english ? 'Enter your bank and current balance.' : 'Informe seu banco e o saldo atual.', done: state.hasAccount, tab: 3),
      (title: english ? 'Record your income' : 'Registre sua renda', help: english ? 'Add your paycheck or another source of income.' : 'Cadastre seu salário ou outra entrada.', done: state.hasConfirmedIncome, tab: 1),
      (title: english ? 'Add recurring bills' : 'Organize despesas fixas', help: english ? 'Include rent, subscriptions and regular bills.' : 'Inclua aluguel, assinaturas e contas recorrentes.', done: state.recurringExpenseCount > 0, tab: 1),
      (title: english ? 'Set your budget' : 'Configure seu orçamento', help: english ? 'Choose how much you plan to spend.' : 'Defina quanto pretende gastar.', done: state.budgetConfigured, tab: 2),
      (title: english ? 'Add a card (optional)' : 'Adicione um cartão (opcional)', help: english ? 'Track purchases and card statements.' : 'Acompanhe compras e faturas.', done: state.hasCard, tab: 3),
      (title: english ? 'Plan your emergency fund (optional)' : 'Planeje sua reserva (opcional)', help: english ? 'Set a goal for unexpected expenses.' : 'Escolha uma meta para imprevistos.', done: state.reserveConfigured, tab: 2),
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
              Expanded(child: Text(english ? 'Your Fôlego starts here' : 'Seu Fôlego começa aqui', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(tooltip: english ? 'Do this later' : 'Fazer depois', onPressed: onDismiss, icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 6),
            Text(english ? 'Let’s organize your money. Skip any step and return whenever you want.' : 'Vamos organizar seu dinheiro juntos. Você pode pular qualquer etapa e voltar depois.'),
            const SizedBox(height: 12),
            Semantics(label: english ? '$done of 6 steps completed' : '$done de 6 etapas concluídas',
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
              icon: const Icon(Icons.refresh), label: Text(english ? 'Refresh my progress' : 'Atualizar meu progresso')),
            TextButton(onPressed: onDismiss, child: Text(english ? 'Explore the app for now' : 'Explorar o app por enquanto')),
          ],
        ),
      ),
    );
  }
}
