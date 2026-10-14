# FÔLEGO Premium via Asaas (PWA) — CANDIDATO DE HOMOLOGAÇÃO

**Situação em 14/10/2026:** candidato na PR #118; tabelas isoladas criadas no Fôlego Dev pela migração `folego_asaas_sandbox_isolation_20261014` e duas funções *sandbox-only* implantadas. Nenhuma chave ou link configurado/verificado; endpoints têm travas explícitas desligadas. Nenhuma cobrança realizada e nenhuma alteração no PWA, movimentações ou acesso Premium de usuários existentes. Testes Node e `deno check` aprovados no GitHub Actions. Sem homologação ponta a ponta.

## Escopo e preço a homologar

- Mensal: R$ 9,90; link Asaas **RECURRENT / MONTHLY**; 7 dias gratuitos somente se uma implementação real de trial for homologada, caso contrário não anunciar trial.
- Anual fundador: R$ 89,90; link separado **RECURRENT / YEARLY**; lançamento posterior ao mensal.
- Usuários Free mantêm lançamentos, contas e controles atuais sem retrocesso ou exclusão.
- Sincronização pessoal FÔLEGO ↔ Controle Financeiro 2026, saldos, comentários e ACK ficam completamente fora do escopo.
- Separar dados financeiros de usuários e espaços, sem reutilizar tabelas do EDITALUME, nem dar acesso FÔLEGO por pagamento EDITALUME.
- A versão PWA usa Asaas; não reutilizar RevenueCat/native billing das lojas nem escrever em `store_subscriptions` ou `premium_grants`.

## Fluxo seguro proposto

1. Cliente entra no FÔLEGO com **e-mail confirmado**; backend valida o JWT com Supabase Auth.
2. Endpoint de intenção cria registro (user_id, e-mail verificado, plano e ID aleatório) só para conta autenticada. Não aceitar user_id/e-mail fornecido pelo navegador.
3. O backend **Asaas Sandbox**, isolado da produção, consulta por API o link de cobrança do plano e confere ID, URL, valor, recorrência, atividade. Só então devolve URL de checkout.
4. Cliente conclui pagamento no Asaas. Voltar ao aplicativo **não** concede Premium.
5. Webhook com token separado e validação do evento salva ID em ledger idempotente, consulta **novamente** assinatura, link, cliente e pagamentos na API do Asaas. Valida mesma conta, plano, valor, origem e efetiva liquidação. Eventos fora de ordem/repetidos não geram benefícios extras.
6. Backend calcula período pago por faturas confirmadas, considera estornos/atrasos/cancelamento, e atualiza **somente** uma tabela própria `folego_asaas_entitlements`. O app consulta uma visão/RPC por `auth.uid()` que combina os benefícios web, cortesia e loja sem sobrescrever fontes.
7. Conta Premium perde privilégios após expiração verificável, mas **não perde dados nem acesso Free**. Suspensão não cancela automaticamente a assinatura: precisa existir fluxo de cancelamento ou suporte.
8. Reconciliação agendada recupera eventos perdidos e emite alerta se pagamento não puder ser associado. Nunca marcar pagamento por webhook sozinho.

## Reutilizável do EDITALUME

Referência: `CIPRI-studios/editalume`, arquivos:
- `supabase/functions/editalume-pro-billing-intent/index.ts`
- `supabase/functions/editalume-pro-billing-webhook/index.ts`
- `supabase/functions/editalume-pro-billing-webhook/core.mjs`
- `docs/ASAAS_PRO_RECORRENCIA_SETUP.md`

**Não copiar** os IDs/URLs da assinatura de R$49,90, projeto Supabase, tokens, domínio CORS, e-mail, banco ou callbacks para FÔLEGO.

O código `verified-payment-policy.mjs` nesta pasta é SOMENTE uma barreira preliminar, sem cálculo de vencimento ou gravação de acesso. Ele não pode ser usado isoladamente para conceder Premium: faltam vínculo autenticação↔assinatura, RLS, período pago, estorno e idempotência.

## Preparação que ainda falta antes de ativar qualquer cobrança

- [ ] Confirmar no Asaas os termos comerciais, identificação pública da CIPRI Studios e operação do Sandbox.
- [ ] Criar novo link **mensal sandbox R$ 9,90** para FÔLEGO (recorrente MONTHLY) e salvar URL e ID da API. Plano anual somente após homologar mensal. NÃO reutilizar link EDITALUME.
- [ ] Preencher secrets Asaas Sandbox no **Supabase Fôlego Dev** (aba Edge Function Secrets): `FOLEGO_ASAAS_SANDBOX_API_KEY`, `FOLEGO_ASAAS_SANDBOX_MONTHLY_LINK_ID`, `FOLEGO_ASAAS_SANDBOX_MONTHLY_LINK_URL`, `FOLEGO_ASAAS_SANDBOX_WEBHOOK_TOKEN`. Não informar valores no GitHub/chat; a chave de produção do EDITALUME não funciona no Sandbox e não é legível automaticamente por outro projeto Supabase.
- [ ] No Asaas **Sandbox**, configurar um webhook próprio com URL `https://ycumrvkwqizlnehelhek.supabase.co/functions/v1/folego-asaas-webhook-sandbox`, token igual ao segredo do Supabase (mínimo 32 caracteres) e eventos PAYMENT_*/SUBSCRIPTION_* documentados.
- [ ] Somente após instalar segredos, liberar flags `FOLEGO_ASAAS_SANDBOX_CHECKOUT_ENABLED=true` e `FOLEGO_ASAAS_SANDBOX_WEBHOOK_ENABLED=true` para transações **fictícias** e homologação; produção continua bloqueada.
- [x] Aplicada migração nova com tabelas de intenção, eventos e assinaturas isoladas ao **Fôlego Dev** (RLS ativo; privilégios de tabela revogados a anon e authenticated). Contagens iniciais: 0/0/0. Apenas função de leitura de produção, não vinculada ao app. SQL versionado nesta branch.
- [x] Implantadas duas Edge Functions distintas **somente sandbox** em Fôlego Dev, checkout com JWT obrigatório e webhook com token próprio, sem ativação. CORS atual do checkout: `https://caueccipriano.github.io` (testes); migrar para domínio comercial no lançamento.
  - `folego-asaas-checkout-sandbox` (versão 1, bloqueio `FOLEGO_ASAAS_SANDBOX_CHECKOUT_ENABLED` desligado).
  - `folego-asaas-webhook-sandbox` (versão 1, bloqueio `FOLEGO_ASAAS_SANDBOX_WEBHOOK_ENABLED` desligado).
  - QA sintético em GitHub Actions: node tests e `deno check` verdes; não constitui teste com API Asaas real.
- [ ] Integrar botão no FÔLEGO para usuários autenticados, sem ativar recursos pagos antes da confirmação. **Não alterado nesta branch.**
- [ ] Testar 2 usuários diferentes, cobrança confirmada, pendente, duplicada, estornada, expirada, cancelada, falta de webhook, reembolso, outro produto/plano e restauração após reconciliação.
- [ ] Preservar e homologar os acessos Free, cortesia e RevenueCat (sem sobrescrever fontes), mais testes no iPhone real.
- [ ] Preparar domínio e hospedar PWA comercial fora de GitHub Pages (GitHub Pages não permite uso principal como SaaS comercial). GitHub continua repositório.
- [ ] Publicar política de privacidade, termos, preços/renovação, reembolso, suporte e forma de cancelar assinaturas.
- [ ] Somente com QA final e autorização expressa, criar links **de produção** separados e habilitar venda real.

## Rodar a bateria local

```bash
node --test ops/asaas-folego/verified-payment-policy.test.mjs
```

Não requer chave Asaas, credenciais, internet, banco financeiro nem API de produção.

Referências oficiais: https://docs.asaas.com/docs/criando-um-link-de-pagamentos | https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits
