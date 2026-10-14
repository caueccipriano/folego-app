# FÔLEGO — auditoria de vínculos por lançamento (13/10/2026)

## Escopo implementado
Painel **somente de leitura** em Perfil → Dados e aplicativo → Integração com planilha → Conferir lançamentos vinculados. Botão visível apenas quando a integração do espaço ativo está configurada e habilitada.

## Base de evidência
O backend atual registra comunicação `last_push_at` / `last_pull_at` e metadados do evento, mas **não recebe um recibo de aplicação da linha na planilha após o pull**. Assim, o painel **não promete reconciliação concluída**, nem iguala um registro sem alerta a uma linha comprovadamente sincronizada.

- Amostra de até **50 registros mais recentes** e até **100 registros marcados para revisão**, consultados separadamente para evitar o sumiço de pendências antigas.
- `space_id` obrigatório; queries de `financial_events` usam o RLS `events_select_member`; `source='sheet-sync'` e `status='confirmed'`. O cliente exige `metadata.sheet_linked=true` e exclui `metadata.hidden=true`.
- Deduplicação por ID e ordenação que coloca pendências primeiro.
- Rótulos verídicos: **Categoria pendente**, **Conferir categoria**, **Sem confirmação de retorno da planilha**.
- Filtro para casos de categoria pendente e para toda a amostra, sem alegar que os contadores abrangem o histórico completo.
- Erros limpam resultados anteriores sem expor mensagens internas; mudanças de `spaceId` descartam resultados em trânsito; valores respeitam a opção de privacidade global.
- Nenhum parâmetro ou segredo da planilha, token, integração privada, IDs de planilha ou resposta sem escopo aparece na interface.

## Verificação somente leitura no banco
Contagem agregada obtida em 13/10/2026: **250** eventos confirmados não ocultos vinculados à planilha, dos quais **16** marcados para revisão, incluindo **4** sem categoria. Os contadores podem mudar e não comprovam divergência entre planilha e app. Nenhum registro foi alterado para gerar este relatório.

## Limites e próximos passos
Este painel é a **primeira etapa da conciliação linha a linha**, não um motor de comparação dos valores da planilha. Para comparar categoria/valor/versão nas duas origens é preciso desenvolver, testar e implantar um protocolo de ACK idempotente na planilha, respeitando edições locais e com auditoria de conflitos. Não fazer isso de forma automática com os usuários atuais.

Não foram criados gatilhos, migrations, tabelas, processos de cobrança ou gravações financeiras. Publicação apenas após Flutter analyze/test, smoke de integração e QA Playwright verdes. Confirmação física do PWA no iPhone permanece separada.
