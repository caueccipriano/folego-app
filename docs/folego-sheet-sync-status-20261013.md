# Fôlego — status da integração com Google Sheets

## Objetivo
Mostrar ao membro do espaço financeiro os **horários registrados no backend** de comunicação entre Google Sheets e Fôlego, sem abrir a configuração privada da integração.

## Contrato técnico
- RPC: `public.get_folego_sheet_sync_status(p_space_id uuid)`
- Permissão: `EXECUTE` apenas para `authenticated`, com verificação de `auth.uid()` e participação no `space_id`; identidades não autorizadas recebem SQLSTATE `42501`.
- Campos públicos: `configured`, `enabled`, `last_push_at`, `last_pull_at`.
- Campos privados que **nunca** aparecem no RPC: `spreadsheet_id`, `token_hash`, IDs de integração e conteúdo financeiro.
- Origem: tabela `sheet_sync_integrations` mantida apenas pelo backend; política RLS de negação direta permanece sem alterações.

## Sentido confirmado no código Edge Function `sheet-sync` v18
- **push**: uma solicitação da planilha enviou linhas para a API Fôlego. `last_push_at` é atualizado depois de percorrer o lote, que pode conter erros por linha. Não significa que todo o lote foi aceito.
- **pull**: a planilha consultou o backend Fôlego para obter linhas. `last_pull_at` é atualizado após o pull. Não confirma que a planilha aplicou todas as linhas.
- Ações separadas de comentários `notes_pull`/`notes_push` não alteram estes timestamps.

## Experiência
Perfil → Dados e aplicativo → **Planilha conectada**. Mostra estados desconectado/habilitado/desativado/erro, os dois horários locais, aviso de não conciliação e botão de nova consulta. Consulta inicial e retry não gravam nenhum lançamento.

## Validação
- Aplicada no Supabase **Fôlego Dev**, versões `20261013223924` + `20261013224007`.
- Verificado `anon_allowed=false`, `user_allowed=true`.
- Leitura com identidade membro: passa sem vazamento de segredos.
- Leitura com identidade estranha: bloqueada `42501`.
- Flutter model/widget: datas, estados, erro seguro, isolamento de `spaceId`.
- RLS de `sheet_sync_integrations`, app de terceiros, dados do usuário, planilha, categorias, comentários e valores **não foram alterados**.

## Limites / próxima fase
Esses timestamps não medem filas internas, aplicação da planilha, divergências nem sucesso por linha. Para dizer “totalmente sincronizado” seria necessário um protocolo de confirmação e reconciliação bidirecional com contadores e versões. Esta fase não presume tal garantia.

Não publicar antes de os testes Flutter/Playwright passarem e de validar o app instalado no iPhone.
