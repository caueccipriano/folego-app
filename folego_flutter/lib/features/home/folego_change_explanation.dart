import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/folego_snapshot.dart';

/// Component deltas are evidence, not an attribution to individual purchases.
class FolegoChangeExplanation extends StatelessWidget {
  const FolegoChangeExplanation({
    super.key,
    required this.current,
    this.previous,
  });
  final FolegoSnapshot current;
  final FolegoSnapshot? previous;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: FinancialPrivacy.hidden,
    builder: (context, hidden, _) {
      String money(num value) => hidden ? '••••' : Formatters.money(value);
      String change(num value) => '${value > 0 ? '+' : ''}${money(value)}';
      final before = previous;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'o que mudou no meu Fôlego?',
            style: AppTypography.section(context, fontSize: 20),
          ),
          const SizedBox(height: 12),
          if (before == null)
            const Text(
              'este é seu ponto de partida nesta tela. atualize o início depois de um lançamento para comparar com a leitura anterior desta sessão.',
            )
          else ...[
            Text(
              'disponível: ${money(before.spendablePool)} → ${money(current.spendablePool)}',
              style: AppTypography.body(context, fontWeight: FontWeight.w700),
            ),
            Text(
              hidden
                  ? 'variação oculta'
                  : 'variação: ${change(current.spendablePool - before.spendablePool)}',
            ),
            const SizedBox(height: 12),
            Text(
              'o que variou nos componentes:',
              style: AppTypography.body(context, fontWeight: FontWeight.w700),
            ),
            Text(
              'saldo líquido: ${hidden ? '••••' : change(current.liquidBalance - before.liquidBalance)}',
            ),
            Text(
              'reservas protegidas: ${hidden ? '••••' : change(current.protectedBalance - before.protectedBalance)}',
            ),
            Text(
              'compromissos até receber: ${hidden ? '••••' : change(current.mandatoryOutflowsUntilIncome - before.mandatoryOutflowsUntilIncome)}',
            ),
            Text(
              'gastos no teto flexível: ${hidden ? '••••' : change(current.monthlyBudgetUsed - before.monthlyBudgetUsed)}',
            ),
            const Text(
              'essas diferenças não devem ser somadas: caixa e orçamento são restrições diferentes. ajustes, novas previsões e a passagem dos dias também podem mudar o Fôlego.',
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'entenda a leitura atual',
            style: AppTypography.section(context, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text('saldo líquido registrado: ${money(current.liquidBalance)}'),
          Text('parte protegida: ${money(current.protectedBalance)}'),
          Text(
            'compromissos até a próxima entrada: ${money(current.mandatoryOutflowsUntilIncome)}',
          ),
          Text('margem de caixa calculada: ${money(current.cashHeadroom)}'),
          if (current.budgetConfigured) ...[
            Text(
              'teto flexível: ${money(current.monthlyBudgetPlanned)} · usado: ${money(current.monthlyBudgetUsed)}',
            ),
            Text('margem do orçamento: ${money(current.economicHeadroom)}'),
          ],
          const SizedBox(height: 8),
          Text(
            'disponível para decidir: ${money(current.spendablePool)}',
            style: AppTypography.body(context, fontWeight: FontWeight.w700),
          ),
          const Text(
            'o disponível respeita a margem de caixa e, quando configurado, o teto flexível. não é a soma dos saldos das contas. a próxima renda prevista ainda não é dinheiro recebido.',
          ),
          if (current.dailyFolego != null) ...[
            const SizedBox(height: 8),
            Text('referência diária: ${money(current.dailyFolego!)}'),
            const Text(
              'é uma referência até a próxima entrada, não uma autorização de gasto nem um valor que acumula automaticamente.',
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'os valores dependem dos registros do app. confira extratos, faturas e compromissos; lançamentos recentes ajudam a investigar mudanças, mas esta tela não atribui automaticamente a variação a uma compra específica.',
          ),
        ],
      );
    },
  );
}
