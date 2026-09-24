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
