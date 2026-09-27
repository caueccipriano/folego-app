import 'package:flutter/material.dart';

/// Plain-language help for the most common first-use questions.
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  static const questions = <({String question, String answer})>[
    (question: 'Onde cadastro meu salário ou um Pix recebido?', answer: 'Na tela inicial, toque em Recebi. Informe o valor, de onde veio o dinheiro e em qual conta ele entrou. Você também pode abrir o Histórico e escolher Recebi dinheiro.'),
    (question: 'Como registro uma compra ou conta paga?', answer: 'Toque em Gastei na tela inicial. Informe o valor, o que comprou e como pagou.'),
    (question: 'Qual é a diferença entre saldo e dinheiro disponível?', answer: 'O saldo mostra quanto existe nas contas cadastradas. O dinheiro disponível considera o planejamento e os compromissos conhecidos. Confira se seus saldos e contas futuras estão atualizados.'),
    (question: 'Onde cadastro contas que se repetem?', answer: 'Abra o Histórico e procure a área de contas recorrentes. Cadastre aluguel, assinaturas e outras contas que voltam todo mês.'),
    (question: 'Preciso cadastrar um cartão?', answer: 'Não. Você pode começar apenas com uma conta e seus recebimentos. Adicione cartões quando quiser acompanhar compras e faturas.'),
    (question: 'Como corrigir um valor lançado errado?', answer: 'Abra o Histórico, selecione a movimentação e use a opção de edição quando disponível. Confira os dados antes de salvar.'),
    (question: 'O Fôlego movimenta meu dinheiro?', answer: 'Não. O Fôlego ajuda a registrar e planejar suas finanças. Registrar um recebimento ou gasto no aplicativo não faz uma transferência bancária.'),
    (question: 'Como começo a usar o Fôlego?', answer: 'Cadastre sua primeira conta e o saldo atual. Depois, informe seus recebimentos e as contas que se repetem. Você pode completar as outras etapas mais tarde.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ajuda e perguntas frequentes')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text('Como podemos ajudar?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Respostas simples para começar a cuidar do seu dinheiro.'),
        const SizedBox(height: 16),
        for (final item in questions)
          Card(child: ExpansionTile(
            title: Text(item.question),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(item.answer)],
          )),
      ],
    ),
  );
}
