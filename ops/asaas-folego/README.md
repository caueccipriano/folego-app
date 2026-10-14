# FÔLEGO Premium via Asaas (PWA) — CANDIDATO DE HOMOLOGAÇÃO

**Situação:** preparo em branch isolada. Não cobrar, não publicar o checkout, não ativar entitlements e não alterar o app em uso.

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
- [ ] Criar **dois novos links sandbox** FÔLEGO e salvar URLs e IDs exatos (não reutilizar links do EDITALUME).
- [ ] Separar secrets Asaas Sandbox no Supabase do FÔLEGO; NUNCA publicá-los no GitHub, Dart, Flutter, Pages ou chat.
- [ ] Revisar e aplicar migração própria para intenção, assinatura, ledger e entitlement com RLS negando escrita de clientes. **Não migrado nesta branch.**
- [ ] Adaptar as duas Edge Functions em endpoint distinto e **sandbox only**; definir CORS do domínio comercial validado. **Não implantadas nesta branch.**
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
