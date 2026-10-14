# FÔLEGO — entregas e pendências de lançamento (14/10/2026)

## Regras inegociáveis
- As seis contas pioneiras mantêm acesso Premium vitalício (sem cobrança).
- Nenhuma outra conta recebe Premium por associação ao endereço de e-mail ou data de login.
- O app funciona sem Google Sheets, integração bancária ou dados do proprietário.
- Saldo, transações, cartões, faturas, compromissos e integrações são privados por usuário/espaço.
- Alterações de pagamento exigem teste de sandbox, conciliação e autorização explícita antes de usar produção.
- Não publicar sem Flutter analyze, testes e QA iPhone/Android.

## Publicação e PWA
- [x] Ajustada concorrência de builds por branch em PR.
- [ ] Revisar PR e integrar na branch canônica de deploy.
- [ ] Impedir que builds de branches secundárias publiquem em GitHub Pages.
- [ ] Confirmar rollback e atualizar somente com interação do usuário quando houver edição não salva.
- [ ] Testar PWA instalado em iOS: login, retorno do background, notificações, saldo e upgrade da versão.

## Onboarding de novos usuários
- [x] Mensagem orienta registrar uma conta e primeira entrada/despesa; sem planilha obrigatória.
- [ ] Acompanhar eventos consentidos de primeiro cadastro e primeiro lançamento.
- [ ] Testar ponta-a-ponta uma conta fictícia nova sem dados de pessoas reais.
- [ ] Testar importação de arquivo sintético e limites Free.

## Admin e programa pioneiro
- [x] Criada tabela de admins em schema privado; somente conta proprietária autorizada.
- [x] RPC do painel verifica o usuário autenticado no banco de dados.
- [x] Painel apresenta cadastros, e-mails confirmados, últimos logins, acesso vitalício e feedback.
- [x] Feedback armazenado em tabela separada com RLS e sem dados financeiros.
- [x] Tela de feedback e painel administrativo adicionadas à branch de revisão.
- [ ] Testar como admin e como usuário sem permissão e validar fluxo iPhone.
- [ ] Implantar retenção, sinalização de erros e consentimento antes de telemetria.

## Asaas e monetização
- [x] Concessão lifetime existente e validada (6 de 6 usuários atuais).
- [x] Edge Functions de checkout/webhook sandbox identificadas em Supabase.
- [ ] Testar criação de assinatura sandbox (sem dinheiro real).
- [ ] Confirmar webhooks autenticados, idempotência e política de retry.
- [ ] Confirmar impossibilidade de checkout ou cobrança dos seis Premium vitalícios.
- [ ] Validar períodos pagos, estornos, cancelamento e expiração no backend.
- [ ] Confirmar recursos incluídos em Free e Premium sem quebrar usuários existentes.
- [ ] Validar preço e tratamento legal com revisão humana antes da cobrança.
- [ ] Somente então ativar credenciais de produção e disponibilizar checkout real.

## Pré-lançamento
- [x] Landing com CTA para app, links legais e preço de R$ 9,90 explicitamente previsto.
- [x] Atualizados Termos e Privacidade para mencionar potencial integração Asaas web.
- [ ] Validar todas as informações legais e canais de suporte.
- [ ] Abrir piloto fechado e coletar feedback antes de marketing pago.
- [ ] Métricas: cadastro > primeiro evento financeiro > retorno real no dia 7 e 30 > conversão paga.
- [ ] Anunciar lançamento apenas depois de validação de pagamentos e suporte.

## Registro auditável
Em 14/10/2026: seis contas, seis Premium vitalícios sem validade; nenhuma receita demonstrada.
Logins em 30 dias não substituem métrica de usuário ativo.
O endpoint público de marketing não realiza pagamento.
