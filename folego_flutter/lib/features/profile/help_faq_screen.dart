import 'package:flutter/material.dart';
import '../../core/preferences/app_preferences.dart';

typedef FaqEntry = ({String ptQuestion, String ptAnswer, String enQuestion, String enAnswer});

/// Searchable bilingual help. This screen follows the device locale until
/// the full application has passed the English localization release gate.
class HelpFaqScreen extends StatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> {
  final TextEditingController _search = TextEditingController();
  bool _showEnglish = false;

  static const questions = <FaqEntry>[
    (ptQuestion: 'Não recebi meu e-mail de confirmação. O que faço?', ptAnswer: 'Confira o spam e a aba Promoções. Verifique se o endereço está correto e toque em Reenviar e-mail na tela de confirmação. Aguarde alguns minutos antes de tentar novamente.', enQuestion: 'I did not receive my confirmation email. What should I do?', enAnswer: 'Check your spam and promotions folders. Verify your email address and tap Resend email on the confirmation screen. Wait a few minutes before trying again.'),
    (ptQuestion: 'Onde cadastro meu salário ou um Pix recebido?', ptAnswer: 'Na tela inicial, toque em Recebi. Informe o valor, de onde veio o dinheiro e em qual conta ele entrou. No Histórico, você também pode escolher Recebi dinheiro.', enQuestion: 'Where do I add my paycheck or money I received?', enAnswer: 'On Home, tap Recebi (Money received). Enter the amount, where the money came from, and the account it went into. You can also open Histórico (History) and choose Recebi dinheiro.'),
    (ptQuestion: 'Como registro uma compra ou conta paga?', ptAnswer: 'Na tela inicial, toque em Gastei. Informe o valor, o que comprou e como pagou.', enQuestion: 'How do I record a purchase or bill?', enAnswer: 'On Home, tap Gastei (Money spent). Enter the amount, what you paid for, and how you paid.'),
    (ptQuestion: 'Qual é a diferença entre saldo e dinheiro disponível?', ptAnswer: 'Saldo é o valor registrado nas suas contas. Dinheiro disponível leva em conta seu planejamento e os compromissos conhecidos. Mantenha os saldos e as contas futuras atualizados.', enQuestion: 'What is the difference between balance and available money?', enAnswer: 'Balance is the money recorded in your accounts. Available money also considers your plan and known upcoming commitments. Keep your account balances and future bills up to date.'),
    (ptQuestion: 'Onde cadastro contas que se repetem?', ptAnswer: 'Abra o Histórico e procure a área de contas recorrentes. Cadastre aluguel, assinaturas e outras contas que voltam todo mês.', enQuestion: 'Where do I add recurring bills?', enAnswer: 'Open Histórico (History) and find recurring items. Add rent, subscriptions, and other bills that repeat.'),
    (ptQuestion: 'Preciso cadastrar um cartão?', ptAnswer: 'Não. Comece com uma conta e seus recebimentos. Adicione cartões quando quiser acompanhar compras e faturas.', enQuestion: 'Do I need to add a credit card?', enAnswer: 'No. Start with an account and your income. Add cards later if you want to track purchases and statements.'),
    (ptQuestion: 'Como corrijo um valor errado?', ptAnswer: 'Abra o Histórico, selecione a movimentação e use a opção de edição quando disponível. Confira os dados antes de salvar.', enQuestion: 'How do I correct an incorrect amount?', enAnswer: 'Open Histórico (History), select the transaction, and use Edit when available. Check the details before saving.'),
    (ptQuestion: 'O Fôlego movimenta meu dinheiro?', ptAnswer: 'Não. O Fôlego ajuda a registrar e planejar suas finanças. Cadastrar um recebimento ou gasto não realiza uma transferência bancária.', enQuestion: 'Does Fôlego move money between my bank accounts?', enAnswer: 'No. Fôlego helps you record and plan your finances. Recording income or spending does not initiate a bank transfer.'),
    (ptQuestion: 'Como começo a usar o Fôlego?', ptAnswer: 'Cadastre sua primeira conta e o saldo atual. Depois, informe seus recebimentos e as contas que se repetem. Complete as outras etapas quando quiser.', enQuestion: 'How do I get started?', enAnswer: 'Add your first account and its current balance. Then record your income and recurring bills. Complete the remaining steps whenever you are ready.'),
  ];

  @override
  void initState() {
    super.initState();
    final preference = AppPreferences.languagePreference.value;
    _showEnglish = preference == AppLanguagePreference.english ||
        (preference == AppLanguagePreference.system &&
         WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'en');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final en = _showEnglish;
    final query = _search.text.trim().toLowerCase();
    final filtered = questions.where((entry) {
      final combined = '${entry.ptQuestion} ${entry.ptAnswer} ${entry.enQuestion} ${entry.enAnswer}'.toLowerCase();
      return combined.contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(en ? 'Help & FAQs' : 'Ajuda e perguntas frequentes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(en ? 'How can we help?' : 'Como podemos ajudar?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(en ? 'Simple answers to common questions. The rest of the app is currently available in Brazilian Portuguese.' : 'Respostas simples para cuidar do seu dinheiro.'),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: en ? 'Search questions' : 'Buscar uma dúvida',
              suffixIcon: query.isEmpty ? null : IconButton(
                tooltip: en ? 'Clear search' : 'Limpar busca',
                onPressed: () { _search.clear(); setState(() {}); },
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _showEnglish = !_showEnglish),
              icon: const Icon(Icons.language),
              label: Text(en ? 'Português' : 'English'),
            ),
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(en ? 'No matching questions. Try another term.' : 'Nenhuma pergunta encontrada. Tente outro termo.'),
            ),
          for (final entry in filtered)
            Card(child: ExpansionTile(
              key: ValueKey(entry.ptQuestion),
              title: Text(en ? entry.enQuestion : entry.ptQuestion),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(en ? entry.enAnswer : entry.ptAnswer)],
            )),
        ],
      ),
    );
  }
}
