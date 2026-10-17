# FÔLEGO — verificação de prontidão comercial (14/10/2026)

> Este documento é um checkpoint técnico, não uma autorização para cobrar nem uma certificação jurídica. O PWA existente continua independente da planilha particular do proprietário.

## Situação conferida (somente leitura)

- Implantação PWA mais recente validada anteriormente na branch `feat/transactions-recurring`.
- Supabase Fôlego Dev, somente contagens: 6 usuários no Auth, 6 perfis, 6 espaços financeiros, 6 membros; nenhum usuário sem membro, nem espaço sem membro.
- Trigger no cadastro: `auth.users -> private.handle_new_user()` está instalado; esta auditoria **não** criou uma conta fictícia de produção para testar o trigger.
- RLS habilitado em `financial_spaces`, `space_members`, `financial_events` e nas três tabelas de Asaas sandbox. Políticas de leitura usam associação ao espaço, mas revisão de segurança end-to-end por contas A/B continua pendente.
- Código de primeiro acesso: introdução opcional, conta inicial e entradas feitas no ritmo do usuário; nenhuma conexão de Google Sheets ou banco é obrigatória.
- Patch nesta PR: tratamento de erro + retry no término da introdução e no logout, com mensagens privadas, controles mutuamente exclusivos e novo teste de 390px.
- Integração Google Sheets é configurável por espaço e não aparece para usuários sem integração.
- Asaas: PR #118 **draft**, tabelas sandbox com contagem inicial de 0 intenções/0 eventos/0 assinaturas e flags desligadas. Sem links, credenciais, cobrança ou direito Premium ativo derivados da homologação.
- O app disponível aos clientes mantém recursos Free básicos; **não retirar funções de usuários existentes** sem revisão de contrato e comunicação.

## Bloqueios para venda real

1. **Cadastro novo independente:** teste completo de registro, confirmação de e-mail, criação de espaço/membro e onboarding por duas contas fictícias controladas, sem misturar dados (sem usar usuários reais).
2. **Permissões e privacidade:** testes RLS A/B para notas, contas, eventos, faturas, notificações, exportação, revisão financeira, alterações de e-mail e exclusão.
3. **Asaas sandbox:** conta própria FÔLEGO, link mensal recorrente R$9,90, retorno verificado via API, token/webhook, idempotência, estornos/atrasos/cancelamento, renovação e expirados. Nunca reutilizar credenciais ou assinaturas do EDITALUME.
4. **Trials:** 7 dias grátis são **proposta**, não oferecer até que trial, data inicial, cancelamento e cobrança futura tenham sido testados ponta a ponta.
5. **Acesso Premium:** verificação server-side por usuário e plano; preservar Free e cortesias existentes; recusar upgrades por redirecionamento ou webhook não verificado.
6. **Canal comercial:** revisar hospedagem e domínio próprios, termos, política de privacidade, suporte, reembolso/cancelamento e comunicação do preço antes de aceitar usuários pagantes.
7. **Qualidade:** validar acessibilidade, iPhone PWA, atualizações e logout, limites de orçamentos/cartões, cadastro com dados vazios, falhas intermitentes, volume e backup/restauração.

## Critério de publicação desta PR

- `flutter analyze`, testes de onboarding comercial, Flutter validation, auth integration e QA Playwright aprovados;
- nenhuma migração, credencial, webhook ou mudança de saldo;
- somente código de UI seguro e CI atualizado;
- publicar na branch que realmente alimenta o PWA **após** os testes;
- validar o deploy final por GitHub Actions.

## Proteções do produto

O FÔLEGO é para usuários sem planilhas. Revisão/categorias são universais. Diagnóstico de Sheets e ACK só fazem sentido para quem possui a integração. Fluxos de billing devem ficar isolados por usuário, produto e ambiente. Nunca liberar ou cobrar Premium sem confirmação verificável do provedor e do backend.
