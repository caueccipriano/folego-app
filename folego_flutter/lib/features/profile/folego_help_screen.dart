import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';

/// Product FAQ: explanations only. Never reads, infers, or edits user finances.
class FolegoHelpScreen extends StatelessWidget {
  const FolegoHelpScreen({super.key, required this.onContact});

  final VoidCallback onContact;

  static const questions = <(String, String)>[
    (
      'por onde eu começo?',
      'cadastre uma conta ou cartão e depois seus primeiros gastos e '
      'recebimentos. você não precisa conectar banco nem planilha para usar o fôlego.',
    ),
    (
      'por que pagar uma fatura não aparece como um gasto novo?',
      'a compra é considerada quando é feita, ou por competência nas parcelas. '
      'pagar a fatura movimenta o saldo da conta, mas não deve duplicar a despesa.',
    ),
    (
      'como funcionam compras parceladas?',
      'registre o valor e a quantidade de parcelas. o planejamento considera '
      'os compromissos futuros cadastrados. confira datas e valores da fatura '
      'com o emissor do cartão.',
    ),
    (
      'por que o saldo é diferente do aplicativo do meu banco?',
      'o fôlego calcula a partir dos lançamentos registrados. compras, '
      'transferências e pagamentos ausentes ou em processamento podem causar '
      'diferenças. confira o extrato antes de ajustar valores.',
    ),
    (
      'como importar um extrato com segurança?',
      'na área de lançamentos, importe CSV ou OFX, escolha a conta e revise '
      'as transações sugeridas. possíveis duplicidades ficam para conferência. '
      'nada é confirmado sem sua ação.',
    ),
    (
      'qual a diferença entre gasto e transferência?',
      'gasto é uma despesa. transferência entre contas suas movimenta o '
      'dinheiro de lugar e não representa um gasto novo.',
    ),
    (
      'as simulações registram compras?',
      'não. simular uma compra ou mudança de renda mostra apenas o possível '
      'impacto com base nos dados cadastrados. só um comando explícito de '
      'salvar no planejamento altera esse planejamento.',
    ),
    (
      'o fôlego acessa meus dados bancários automaticamente?',
      'não assuma sincronização bancária. sem conexão específica e autorizada, '
      'os valores refletem o que foi registrado ou importado no aplicativo.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = AppColors.primaryText(brightness);
    final muted = AppColors.secondaryText(brightness);
    return Scaffold(
      appBar: AppBar(title: const Text('ajuda')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: const ValueKey('help-center-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 64),
              children: [
                Text('entenda seu fôlego.',
                    style: AppTypography.display(
                      context, fontSize: 27, color: ink,
                    )),
                const SizedBox(height: 7),
                Text(
                  'respostas rápidas, sem complicar seu dinheiro.',
                  style: AppTypography.body(
                    context, fontSize: 12, color: muted,
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < questions.length; i++) ...[
                  Material(
                    color: AppColors.surface(brightness),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      side: BorderSide(color: AppColors.border(brightness)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      key: ValueKey('help-question-$i'),
                      title: Text(
                        questions[i].$1,
                        style: AppTypography.body(context, fontSize: 13,
                            fontWeight: FontWeight.w700, color: ink),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Text(
                          questions[i].$2,
                          style: AppTypography.body(context, fontSize: 12,
                              color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                ],
                const SizedBox(height: 8),
                Text('faltou alguma coisa?',
                    style: AppTypography.section(context, fontSize: 17)),
                const SizedBox(height: 8),
                Text(
                  'conte sua dúvida, sugestão ou problema. não envie senhas, '
                  'números de cartão ou informações financeiras sensíveis.',
                  style: AppTypography.body(context, fontSize: 12, color: muted),
                ),
                const SizedBox(height: 13),
                FilledButton.icon(
                  key: const ValueKey('help-contact'),
                  onPressed: onContact,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('enviar sugestão'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
