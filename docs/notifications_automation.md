# Fôlego — Notifications + Automation Foundation 1.0

## Escopo

Esta fundação prepara o Fôlego para lembretes financeiros essenciais e para automações determinísticas futuras, sem introduzir billing, Open Finance, IA, scraping bancário, leitura de notificações/SMS bancários ou um segundo ledger.

## Free x Premium

### FREE

Continuam disponíveis sem degradação artificial:

- lançamentos manuais;
- contas, cartões, benefícios e dívidas;
- Plano, Agenda, Diário e Metas;
- Categorias e Marcadores;
- Recorrências;
- Assinaturas;
- importação CSV/OFX com staging e revisão obrigatória;
- notificações financeiras essenciais.

### Premium futuro

A camada canônica de capabilities é `FeatureEntitlements`.

Capabilities previstas:

- `essentialNotifications` — disponível no FREE;
- `automationRules` — Premium futuro;
- `bankSync` — indisponível nesta versão;
- `automaticTransactionProcessing` — indisponível nesta versão;
- `advancedNotifications` — Premium futuro.

Produção usa `FreeEntitlementProvider`. Testes/dev podem injetar `MockPremiumEntitlementProvider`. Não existe estado pago persistido no cliente e o usuário não consegue se auto-promover.

Não há checkout, paywall real, RevenueCat, Stripe, Play Billing ou App Store Billing neste bloco.

## Notificações essenciais

### Fonte canônica

A Agenda continua sendo a fonte canônica dos compromissos futuros.

Fluxo:

`get_upcoming_events` → `get_notification_upcoming_events` → `NotificationUpcomingEvent` → `FinancialNotificationIntent` → `NotificationService` → adapter.

O Flutter não consulta `recurring_items`, `card_invoices` e `debt_installments` em paralelo para reconstruir vencimentos.

### Tipos cobertos

- compromisso hoje;
- compromisso amanhã;
- compromisso em 3 dias, conforme preferência;
- fatura;
- parcela de dívida;
- recorrência;
- assinatura (`recurrence_kind = subscription`);
- entrada/receita recorrente prevista;
- item atrasado.

Tipos reservados para o futuro podem existir no domínio (`bankSyncCompleted`, `transactionsNeedReview`, `automationApplied`, `automationNeedsReview`, `planThreshold`), mas não são disparados sem fonte real.

### Preferências

`notification_preferences` é user + financial space e possui RLS.

Preferências atuais:

- lembretes financeiros;
- faturas;
- dívidas;
- recorrências;
- assinaturas;
- entradas previstas;
- atrasados;
- antecedência: no dia, 1 dia ou 3 dias;
- horário global, default `09:00`.

A permissão não é solicitada no primeiro frame. Ela só é pedida quando o usuário tenta ativar os lembretes. Negar permissão não bloqueia o app e o usuário pode tentar novamente pelas preferências.

### Timezone

O timezone vem de `financial_spaces.timezone`, o mesmo contexto usado pela Agenda. A projeção calcula `scheduled_at` no backend e devolve `timestamptz` já coerente com o espaço financeiro. Não existe segunda lógica Flutter de “hoje/amanhã/atrasado”.

### IDs determinísticos e dedupe

A chave estável segue o contrato:

`entity_type:entity_id:due_date:reminder_offset:notification_kind`

O `NotificationService` compara a janela desejada com o estado agendado pelo adapter:

- intent já igual → não duplica;
- vencimento alterado → cancela chave antiga e agenda nova;
- evento resolvido/pago ou recorrência/assinatura encerrada → deixa de aparecer na projeção e é cancelado no resync;
- logout → limpa reminders privados;
- troca de financial space → limpa o espaço anterior e sincroniza o novo.

Horizonte atual: 30 dias.

### Deep links

Contrato de navegação:

- fatura → cartão/fatura;
- dívida → detalhe da dívida;
- assinatura → assinatura/recorrência correspondente;
- recorrência → editor/detalhe da recorrência;
- evento geral → Agenda.

Nenhuma rota financeira paralela foi criada.

## Native status

O repositório continua sem `folego_flutter/android/` e `folego_flutter/ios/`.

Status real: **arquitetura preparada**.

O build Web usa `WebSafeNoopNotificationAdapter`, portanto o domínio/preferences/sync são testáveis sem depender de permissão real do browser ou emulador.

### BLOCKED UNTIL NATIVE TARGET EXISTS

Android futuro:

- criar/reconciliar target Android explicitamente;
- Android 13+ notification permission;
- channel(s);
- ícone local notification;
- validar comportamento em background;
- não exigir exact alarm sem necessidade real.

iOS futuro:

- criar/reconciliar target iOS explicitamente;
- permission flow;
- capability/configuração de notifications;
- signing/provisioning real;
- validar scheduling e abertura por deep link em dispositivo/simulador.

Não foram inventadas credenciais push, Firebase secrets, APNs, keystore ou signing.

## NotificationService

`NotificationService` é a fronteira canônica e encapsula adapter/plugin.

Responsabilidades:

- permission status/request;
- schedule;
- cancel;
- cancel por entidade/espaço;
- reschedule por diff determinístico;
- sync upcoming;
- handle open/deep-link contract;
- cleanup de logout;
- cleanup de troca de espaço.

O lifecycle usa `NotificationRuntimeController` e o `RealtimeInvalidationCoordinator` existente. O sync ocorre no espaço ativo, em resume e nas invalidações relevantes, com coalescing/debounce do coordinator. Nenhuma tela cria listener Realtime próprio.

## Automation rules

### Propósito

Recorrência significa “isto acontece novamente no calendário”. Automation Rule significa “quando um candidate parecido aparecer, sugerir/preparar esta classificação”.

`recurring_items` não foi alterado para virar motor de automação.

### Schema

`automation_rules` possui schema restrito, sem JSON DSL arbitrária:

- espaço;
- nome;
- active;
- trigger type;
- match field/type/value;
- source scope;
- direção;
- categoria/classificação;
- action type;
- execution mode;
- priority;
- creator/timestamps.

`automation_rule_runs` registra auditabilidade mínima, sem copiar valor, saldo, merchant ou descrição do candidate.

### Matching

Campos iniciais:

- description;
- merchant.

Tipos:

- equals;
- contains.

Normalização:

- case-insensitive;
- accent-insensitive;
- trim;
- collapse whitespace.

O texto original persistido não é reescrito.

### Precedência

Ordem determinística server-side:

1. source específico antes de `any`;
2. equals antes de contains;
3. maior priority;
4. created_at mais antigo;
5. id como desempate estável.

O preview Flutter segue a mesma intenção de ordenação sem realizar lançamentos.

### Source scope

Uma regra pode ser:

- qualquer origem;
- conta específica;
- cartão específico;
- benefício específico.

O RPC valida que o instrumento específico continua ativo e do tipo correto. Instrumentos arquivados/inativos não classificam novos candidates.

### Categorias

As regras usam `categories` canônicas.

Uma regra que aponta para categoria inativa/não selecionável deixa de ser elegível no motor. O histórico permanece preservado; nenhum evento histórico é reescrito.

### Actions e execution modes

A fundação suporta:

- sugerir categoria;
- preparar categoria para revisão;
- sugerir classificação segura;
- marcar candidate reconhecido.

Modes expostos nesta versão:

- `suggest`;
- `review`.

`automatic` está reservado para futuro Premium + fonte autorizada e não é usado para auto-post nesta versão.

Automation Rule nunca:

- cria transferência;
- paga fatura;
- cria debt;
- deleta lançamento;
- altera saldo;
- faz INSERT direto em `financial_events`;
- faz INSERT direto em `financial_impacts`.

## Importador CSV/OFX

`statement_import_*` continua sendo o staging canônico.

Fluxo atual:

CSV/OFX → parse → staging → dedupe → `apply_automation_rules_to_import_batch` → review → confirmação → contrato financeiro canônico.

As regras só rodam em rows staged que não sejam `exact_duplicate`/`already_imported` e não alteram fingerprint/FITID/dedupe/idempotência.

A confirmação continua obrigatória. O RPC de automação não posta no ledger.

A UI recebe metadata de regra/sugestão em `StatementImportRow`, mantendo a sugestão separada do contrato de confirmação.

O helper `automationRuleDraftFromReviewedImportRow` prepara o fluxo explícito “Sempre fazer assim?” apenas a partir de uma row revisada com tipo/categoria definidos. Nenhuma regra é criada silenciosamente.

## Realtime

Foram adicionados domínios ao coordinator existente:

- `notifications`;
- `automationRules`.

Recorrências, occurrences, invoices, payments e debts invalidam somente o sync de notificações relevante. Alterações de `automation_rules` invalidam apenas o domínio de automação. Não existe segunda infraestrutura Realtime.

`notification_preferences` não invalida Home/Wallet/Lançamentos.

## Segurança e RLS

`notification_preferences`, `automation_rules` e `automation_rule_runs` têm RLS ON.

As policies usam `auth.uid()` e membership/write-space já canônicos.

- preferences: usuário + espaço;
- rules: member para read, writer para mutação;
- runs: read-only para cliente autenticado no mesmo espaço.

O criador e o space da rule são imutáveis por trigger de hardening.

Nenhuma `service_role` foi adicionada ao Flutter.

## Privacidade e logging

O intent não inclui valor financeiro em chave estável e a implementação não deve logar body completo, valores, saldos, descrições, merchant, nomes de conta, rows financeiras, JWT ou tokens.

Debug futuro deve usar `kDebugMode` e payload sanitizado.

## Futuro Open Finance

Arquitetura pretendida, não implementada:

Open Finance → synced candidate → dedupe → automation rules → decision → review/automatic → contrato canônico.

Não há provider bancário, bank credentials, bank sync, scraping, SMS listener, notification listener bancário ou Accessibility Service neste bloco.

## Futuro automatic processing

Auto-post somente poderá existir depois com autorização explícita, entitlement real e uso do RPC financeiro canônico. Mesmo nesse futuro, Automation Rule não deve escrever tabelas de ledger diretamente.

## Futuro billing

Billing real deve substituir a injeção mock por uma fonte de entitlement confiável e não client-editável. Até lá, produção permanece FREE por default e Automações funciona como preview “Premium em breve”; testes/dev podem injetar Premium mock.
