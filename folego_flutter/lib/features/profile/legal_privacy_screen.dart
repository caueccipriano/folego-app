import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class LegalPrivacyScreen extends StatelessWidget {
  const LegalPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);

    return Scaffold(
      appBar: AppBar(title: const Text('privacidade e termos')),
      body: SafeArea(
        child: AppContentContainer.form(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
            children: [
              Text(
                'seus dados, com contexto',
                style: AppTypography.display(context, fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                'um resumo legível de como o Fôlego funciona. A política pública completa será mantida no canal oficial do app.',
                style: AppTypography.body(
                  context,
                  fontSize: 13,
                  color: secondary,
                ),
              ),
              const SizedBox(height: 24),
              const _LegalCard(
                title: 'o que o Fôlego guarda',
                body:
                    'Dados da sua conta, como nome e e-mail, e as informações financeiras que você decide registrar — por exemplo receitas, despesas, contas, cartões, dívidas, orçamentos, recorrências, metas e projeções.',
              ),
              const _LegalCard(
                title: 'para que esses dados servem',
                body:
                    'Para autenticar sua conta, armazenar suas finanças, calcular resumos e planejamento, processar importações solicitadas por você e liberar recursos Premium quando aplicável.',
              ),
              const _LegalCard(
                title: 'o que não fazemos',
                body:
                    'O Fôlego não vende seus dados financeiros e não foi criado para usar suas finanças em publicidade comportamental.',
              ),
              const _LegalCard(
                title: 'serviços necessários',
                body:
                    'Supabase é usado para autenticação e backend. RevenueCat é usado para validar e administrar compras e assinaturas quando o Premium estiver disponível pelas lojas.',
              ),
              const _LegalCard(
                title: 'apagar sua conta',
                body:
                    'Você pode excluir sua conta no Perfil. A ação remove a conta e os dados associados conforme a arquitetura do serviço e obrigações legais aplicáveis.',
              ),
              const _LegalCard(
                title: 'sobre decisões financeiras',
                body:
                    'O Fôlego é uma ferramenta de organização financeira pessoal. Não é banco, instituição de pagamento, consultoria de investimentos ou serviço de crédito. Projeções dependem dos dados informados e não são garantia de resultado futuro.',
              ),
              const SizedBox(height: 8),
              Text(
                'Versão de trabalho · 24/09/2026',
                style: AppTypography.label(
                  context,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.section(context, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: AppTypography.body(
                context,
                fontSize: 12,
                color: AppColors.secondaryText(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
