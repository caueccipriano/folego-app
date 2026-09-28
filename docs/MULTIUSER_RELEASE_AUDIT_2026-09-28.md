# Fôlego — auditoria de lançamento para TODOS os usuários

Data: 28/09/2026. Base revisada: feature branch
\`feat/financial-intelligence-20260926\`, código Flutter, funções Edge e
**metadados** do banco Supabase Dev. Esta revisão não é reconciliação da conta
financeira do desenvolvedor e não usou lançamentos ou saldos individuais de
nenhum cliente. O único relatório agregado de integridade em Dev apontou
**zero linhas** em \`public.import_rows\` no momento da inspeção.

**Escopo de usuários:** pessoa sem login, duas contas independentes A e B,
proprietário, integrante, visualizador de espaço compartilhado, pessoa Free,
Cortesia, Vitalício, Premium de loja, assinante com acesso vencido, usuário em
dispositivo compartilhado e pessoa que exclui a conta. Cobrir personagens
fictícios no teste **não** prova que todos os fluxos reais ou todas as contas
existentes foram testados.

**Precisão da auditoria:** permissões apenas de tabela não permitem concluir que uma função invoker não pode ler uma tabela. Foi consultado `has_column_privilege` para todas as colunas usadas por `get_my_premium_grant`, além da policy. A suposta falha MU-02 foi corrigida no relatório sem alterar o aplicativo.

### Checagens agregadas adicionais (sem dados individuais)

Também foram conferidas referências cruzadas em **todos os registros existentes**
de `financial_events` e `financial_impacts`, retornando apenas contagens:
referências de eventos a categorias fora do espaço: **0**; referência
pai/evento fora do espaço: **0**; impactos a contas fora do espaço:
**0**; impactos a categorias fora do espaço: **0**. Havia **0** linhas
na tabela de importações `import_rows`. Esses resultados representam o
instante da consulta, não uma garantia permanente. A migração proposta
impede novos vínculos cruzados nas importações por API direta.

## Resultado do inventário estático em Dev

- 45 tabelas de aplicação no schema público com RLS habilitada; todas as
  cinco tabelas sem policy são internas e não dão SELECT/INSERT/UPDATE/DELETE
  diretos a \`anon\` ou \`authenticated\`:
  \`ai_question_usage\`, \`financial_intelligence_usage\`,
  \`quanto_automation_config\`, \`store_subscriptions\`,
  \`subscription_webhook_events\`. Não criar policies permissivas nelas.
- \`space_members\` define os papéis \`owner\`, \`admin\`, \`member\` e
  \`viewer\`. \`private.is_space_member\` concede leitura aos integrantes;
  \`private.can_write_space\` concede escrita somente aos três primeiros.
- O advisor sinaliza 17 funções \`SECURITY DEFINER\` executáveis por pessoas
  autenticadas. Isso exige testes com *duas identidades reais de teste*;
  não equivale, por si, a 17 vazamentos comprovados. Exigir revisão de
  autorização por argumentos, relacionamentos e semântica em cada função.
- Advisor do Supabase Auth: proteção contra senhas vazadas **desativada**.
  Fonte e remediação:
  https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Achados verificáveis e bloqueios de lançamento

| ID | Área | Evidência | Ação/critério |
| --- | --- | --- | --- |
| MU-01 | Integridade entre contas / importação | \`import_rows\` aceita INSERT/UPDATE por um writer do próprio espaço, mas suas FKs principais usam apenas UUID do objeto, e não o par \`(objeto_id, space_id)\`. Uma referência pertencente a B podia ser gravada na linha de A conhecendo o UUID, mesmo oculta por RLS. O RPC de confirmação já revalida categoria/conta/fatura — **não há evidência de leitura de dados de B**. | Nova migração \`20260928223000_harden_import_row_cross_space_refs.sql\` adiciona o invariante a toda escrita, inclusive API direta, preservando resoluções de IDs de compras/faturas. Teste sintético reproduz antes e exige bloqueio depois. Pendente Dev e revisão. |
| MU-02 | Cortesia/Vitalício de todos os usuários | **Verificado como protegido após inspeção das permissões por coluna:** `get_my_premium_grant()` usa `SECURITY INVOKER` e `authenticated` já tem SELECT apenas nas colunas `user_id`, `grant_type` e `valid_until`, sujeito a RLS `auth.uid()=user_id`. A tabela completa não tem SELECT, e a nota administrativa não é legível — ambos comportamentos corretos. A checagem inicial exclusivamente com `has_table_privilege` gerou um falso positivo, retirado da PR. | **Nenhuma migração necessária.** Manter teste de regressão de colunas, RLS e acesso próprio no QA autenticado com contas fictícias; não ampliar grants. |
| MU-03 | Cota de cenários para qualquer usuário | Em Dev, \`get_projection\` ainda permite chamadas diretas ajustadas sem debitar cota: a versão anterior cobra no Flutter após a projeção. | PR #11 implementa cobrança atômica no RPC. 39 testes Flutter e suíte sintética de PostgreSQL passaram. Atualizar *cliente antes da migração* para impedir dupla cobrança; testes reais por identidade ainda pendentes. |
| MU-04 | Push em aparelhos compartilhados | \`web_push_subscriptions.endpoint\` é UNIQUE global, associado a um user_id. Logout normal do Perfil limpa inscrição. Bootstrap/onboarding chama \`auth.signOut\` diretamente; mudanças involuntárias de sessão/expiração também precisam verificar limpeza. Não foi demonstrado vazamento em aparelho real. | E2E A ativa push → expira sessão/logout alternativo → B entra no mesmo browser → garantir que B jamais recebe push financeiro de A. Corrigir eventual persistência antes de ativar push ao público. |
| MU-05 | Escopo Premium no servidor | A tela de projeções pede Premium, mas o \`get_projection\` de Dev ainda aceita projeção base (inclusive horizonte 12/24) de qualquer membro autenticado. A Home usa leitura base de 3 meses e simulador Free possui 3 tentativas. | Formalizar divisão Free/Premium do endpoint e testes de bypass via REST sem quebrar Home nem simulador Free. A PR #11 protege cenários ajustados, **não** resolve toda a segmentação de projeção base. |
| MU-06 | IA para clientes | O Home exibe o card financeiro IA somente para um usuário interno e \`consume_premium_ai_question\` também só autoriza esse testador. É beta privada, não funcionalidade universal de assinantes. | Não anunciar IA como benefício geral antes de remover restrições proprietárias, validar grants/assinaturas por servidor, limite individual, custos, privacidade e testes de várias contas. |
| MU-07 | Preço, pagamento e confirmação | \`subscription_service.dart\` e \`docs/revenuecat-launch-checklist.md\` ainda dizem R$14,90. Outra documentação de publicação e decisão de produto apontam R$9,90. Configuração e sandbox reais de Apple/Google/RevenueCat não foram confirmados. Modelo de e-mail de confirmação ainda não foi ativado segundo a documentação. | Issue #12; alinhar exibição/contrato/lojas sem iniciar cobrança, testar compra, restauração, cancelamento, expiração, chargeback, webhooks idempotentes/fora de ordem e cadastro/recuperação. |
| MU-08 | Espaços compartilhados e exclusão | \`financial_spaces.owner_id\` possui FK para \`auth.users\` com \`ON DELETE CASCADE\`. \`delete-account\` apaga o usuário autenticado sem checar se ele é dono de household com outros membros. Exclusão pode apagar o espaço compartilhado dos demais. | Antes de oferecer compartilhamento comercial, definir transferência de titularidade/consentimento e validar exclusão de dono versus membro em cenário A/B. Não operar exclusões reais para testar. |
| MU-09 | Banco seguro versus app seguro | 17 RPCs privilegiados e toda UI/autenticação/dispositivos precisam de testes de fronteira com identidade A/B (UI pública isolada não basta). | Gates de integração autenticada em staging, perfis independentes e cenários negativos; reexecutar advisors ao aplicar cada migração. |

Links internos: PR #11
https://github.com/caueccipriano/folego-app/pull/11,
issue de preço #12
https://github.com/caueccipriano/folego-app/issues/12.

## Critérios globais de aceite, não apenas para a conta do dono

1. **Identidade/privacidade:** sem sessão e sessões expiradas não retornam
   dados privados. A vê somente seus espaços; B vê somente os seus.
   B deve ver o espaço compartilhado de A *somente após* membership explícito,
   e um \`viewer\` deve ser incapaz de inserir/editar/excluir.
2. **Referências financeiras:** tentar acessar e associar UUIDs de outra
   conta em contas, cartões, faturas, categorias, débitos, metas,
   transações, importações, automações e RPCs; todos negados.
3. **Dados de contas novas:** cadastrar contas fictícias isoladas, confirmar
   e-mail, recuperar senha, terminar onboarding sem saldos ficticiamente
   positivos, criar a primeira conta financeira e registrar receita/despesa.
   Verificar erros, empty states, timezone e idioma.
4. **Premium:** Free mantém as funcionalidades contratadas sem pagamento;
   Cortesia/Vitalício e Premium verificados têm funcionalidades devidas;
   expiração, cancelamento, restituição de recibo e troca de conta não
   herdam entitlement indevido. Simulações por UID limitadas atomicamente,
   sem dupla contagem; custos de IA limitados por usuário (quando liberada).
5. **Dispositivos/sessões:** web mobile e desktop, iPhone PWA e Android;
   logout, troca A/B no mesmo browser, push e caches não podem carregar
   nem notificar dados do login anterior.
6. **Assinaturas e conta:** nome/preço/trial/cobrança transparentes por loja,
   restore e revogação, exclusão com migração de espaços compartilhados
   quando aplicável. Aprovação legal e testes nativos físicos.
7. **Regressão:** rodar CI Flutter, Playwright, SQL/RLS simulado, advisor,
   e testes autenticados reais em staging com duas contas **fictícias**.
   Guardar evidências por versão; nunca declarar produção aprovada com
   base somente em testes de mock ou screenshots de um usuário.

## Correções e limites operacionais

A branch deste documento contém **apenas** uma migração proposta para integridade de importações e CI isolado. A suposta correção de permissões Premium foi descartada após verificação detalhada e não integra esta branch.
O controle de cota está em uma PR separada. Antes de aplicar em Dev:
verificar o SHA, o estado da função existente e os privilégios; fazer
preflight de importações legadas e backups apropriados. Nunca implantar uma
migração ou mexer em dados pessoais só para simular dois usuários.

Após CI isolado, validar em staging com contas sintéticas. A limitação do
Vercel e a confirmação real de loja impedem atestar a jornada completa.
Esta auditoria não equivale a certificação de segurança ou liberação comercial.
