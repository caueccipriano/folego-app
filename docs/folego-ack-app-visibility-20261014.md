# Correção da auditoria: recibos de lançamentos originados no FÔLEGO (14/10/2026)

## Risco corrigido
O protocolo de `pull` envia `source='app'` para a planilha, e a função de ACK registra recibo para este mesmo evento. A versão anterior da auditoria carregava somente `source='sheet-sync'` e filtrava `metadata.sheet_linked=true` **antes** de consultar recibos. Por isso, a primeira classe de confirmações do novo protocolo não apareceria na UI.

## Regra nova
- A amostra recente lê até 50 eventos de origem `sheet-sync` **ou** `app` no espaço financeiro autenticado.
- Busca recibos **antes** de decidir quais itens mostrar, pela RPC já existente que só retorna ACK da `updated_at` atual.
- Exibe evento se há `sheet_linked=true` ou ACK de versão atual. Uma transação só do app sem ACK permanece oculta da auditoria, não recebe rótulo falso.
- Eventos ocultos nunca aparecem, mesmo com recibo; continuam válidas as 100 pendências independentes de categoria.
- O endpoint é read-only e protegido por `space_id` e política RLS atual. Nenhum registro é inserido/atualizado.

## Aceite
Testes incluem app sem recibo (oculto), app com recibo corrente (exibido) e evento oculto com recibo (oculto); PR sujeito à CI Flutter, integração e QA multi-device.

Não ativar ACK no Apps Script só porque esta visualização passou. Ele continuará dependente da revisão do draft #100 e da ponte opt-in #108.
