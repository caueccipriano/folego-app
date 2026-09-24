# Fôlego v1 — revisão de segurança de release

Data: 24/09/2026

## Controles confirmados

- RLS continua habilitada nas tabelas do produto.
- `premium_grants` é somente leitura para usuários autenticados e expõe apenas `user_id`, `grant_type` e `valid_until`.
- Usuários autenticados não recebem permissão de INSERT/UPDATE/DELETE em `premium_grants`.
- O app não contém `service_role` nem chave administrativa.
- Os 15 RPCs `SECURITY DEFINER` atualmente expostos a `authenticated` foram revisados e todos exigem `auth.uid()` e uma checagem de acesso ao espaço por `private.can_write_space` ou `private.is_space_member`.
- A leitura de Premium usa o RPC `get_my_premium_grant()` com contexto do usuário autenticado.
- Logs de autenticação e detalhes opcionais foram reduzidos para tipo do erro em modo de debug, sem imprimir e-mail, token, JWT ou stack trace completo.
- Exclusão de conta é iniciável dentro do aplicativo.
- A função `delete-account` exige JWT válido, resolve o usuário pela sessão autenticada e só então usa a chave administrativa no servidor.
- A exclusão foi conferida contra as FKs: `financial_spaces.owner_id` e os dados financeiros associados usam `ON DELETE CASCADE`; o único vínculo direto com `auth.users` em `automation_rules.created_by` usa `RESTRICT` e é limpo explicitamente antes da remoção da conta.

## Avisos do linter avaliados

### SECURITY DEFINER executável por authenticated
O linter do Supabase marca os RPCs porque eles são `SECURITY DEFINER`. Neste projeto isso é intencional: as funções fazem a autorização explicitamente antes de ler ou alterar dados e usam `SET search_path = ''`.

Não revogar EXECUTE indiscriminadamente: esses RPCs fazem parte do contrato do cliente.

### `quanto_automation_config` com RLS sem policy
É uma tabela separada do escopo Fôlego. RLS sem policy não abre dados; ao contrário, bloqueia acesso via API. Não alterar como parte desta release sem revisar o produto QUANTO.

### Proteção contra senhas vazadas
O linter ainda reporta **Leaked Password Protection Disabled** no Supabase Auth.

Antes da publicação comercial, habilitar no dashboard do Supabase a proteção contra senhas comprometidas. Essa configuração não é alterável pelo conector de banco usado nesta preparação.

## Gate final
Antes de publicar:
1. confirmar a proteção contra senhas vazadas;
2. testar criação/login/reset/exclusão de conta em dispositivo real;
3. testar RLS com dois usuários distintos;
4. testar Trial/Premium/Cortesia/Vitalício;
5. revisar Data Safety/App Privacy contra os SDKs da build exata.

## Auditoria adicional — 24/09/2026

- As **39 tabelas** do schema `public` estão com RLS habilitada.
- As policies expostas ao cliente usam o papel `authenticated`; as exceções servidor-only revisadas possuem condição `false` para acesso do cliente.
- O app usa a chave **publishable** moderna do Supabase, não uma chave administrativa.
- Nenhum arquivo de assinatura, `.env`, chave privada, `key.properties`, `google-services.json` ou `GoogleService-Info.plist` foi encontrado na árvore atual da release.
- O repositório continua **público**. Licença proprietária, CODEOWNERS, Dependabot, `.gitignore` e checks de higiene reduzem risco operacional, mas **não escondem o código-fonte**. Tornar o repositório privado é o único controle efetivo contra leitura/clonagem pública.
- Na verificação atual, o repositório não tinha forks, stars ou watchers registrados. Isso não prova que ninguém tenha baixado o código enquanto esteve público.

### Pendências externas que continuam bloqueando o selo de segurança da v1

1. Tornar o repositório de código privado e manter apenas os recursos públicos necessários em uma superfície separada.
2. Habilitar **Leaked Password Protection** no Supabase Auth.
3. A superfície legal pública já foi desacoplada do GitHub Pages em uma Edge Function pública do Supabase. Depois da troca de visibilidade, validar apenas se o PWA Web também precisa continuar público; as URLs de Privacidade, Termos, Suporte e Exclusão não dependem mais do repositório público.

## Hardening adicional do banco — 24/09/2026

- O papel anônimo (`anon`) ficou sem privilégios diretos em tabelas do schema `public`.
- O papel anônimo ficou sem `EXECUTE` em RPCs do schema `public`.
- O papel anônimo ficou sem uso das sequences públicas revisadas.
- Os privilégios de `authenticated` foram reduzidos: `TRUNCATE`, `REFERENCES` e `TRIGGER` foram removidos das tabelas públicas; permanecem apenas as operações de dados necessárias e ainda sujeitas a RLS/policies.
- Default privileges de objetos criados pelo papel `postgres` foram endurecidos para não conceder acesso automático a `anon`, nem privilégios de tabela desnecessários a `authenticated`.
- Uma simulação com um JWT de usuário autenticado inexistente retornou **zero linhas** para perfis, espaços financeiros, contas, lançamentos, cartões e concessões Premium.
- As funções de configuração e entrega de push que acessam material de servidor permanecem executáveis apenas por `service_role`.

Observação: os default privileges pertencentes a `supabase_admin` não puderam ser alterados pela sessão de migração do projeto. Isso não reabriu objetos atuais; os grants efetivos atuais foram revisados e endurecidos. Novos objetos continuam exigindo revisão de grants/RLS no checklist de segurança.

### Superfície pública independente do código
A Edge Function `folego-public` serve páginas públicas de Privacidade, Termos, Suporte e Exclusão de conta. A exclusão externa autentica o usuário diretamente contra o Supabase Auth e chama a função protegida `delete-account`; a página pública não contém chave administrativa.
