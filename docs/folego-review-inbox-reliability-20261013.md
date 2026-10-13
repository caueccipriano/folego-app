# Fôlego — central de revisão confiável (13/10/2026)

## Escopo
Aprimorar o acesso à caixa de entrada de classificações sem aplicar qualquer categoria automaticamente.

## Problema confirmado
Antes, o repositório consultava até 500 eventos econômicos confirmados e só **depois** filtrava `metadata.needs_classification` no cliente. Isso podia omitir pendências antigas se o histórico crescesse além da página inicial. Além disso, a interface mostrava um ícone de conclusão mesmo quando a consulta das pendências tinha falhado.

## Correções
- A consulta do Supabase filtra `metadata->>needs_classification = true` **antes** da ordenação e do limite; mantém o filtro defensivo `hidden != true` no cliente e o `space_id` obrigatório.
- A mensagem da fila diferencia registros sem categoria dos que já possuem categoria, mas ainda estão sinalizados para revisão.
- A tela de Transações distingue `loading`, `unavailable`, `zero` e `count > 0`. Quando a API falha, ela não usa o ícone de \"concluído\"; tocar para abrir a fila refaz a consulta, mantendo a fila fechada se persistir a falha.
- As recomendações do Autopilot continuam exigindo revisão/consentimento; categorias, saldos e lançamentos não são modificados por esta entrega.
- O rodapé passa a explicar que a sincronização da categoria com a planilha depende da integração ativa, sem prometer aplicação completa.

## Segurança e testes
- `financial_events` segue sob RLS atual e filtrado pelo `space_id`.
- Confirmação agregada read-only em Fôlego Dev: 16 eventos econômicos confirmados com `needs_classification` e não ocultos; 4 sem categoria e 12 com categoria ainda sinalizada para conferência. Isso não comprova divergência real com a planilha e pode mudar com novas sincronizações.
- Nenhuma migração, alteração de política, Apps Script, dado bancário ou categoria.
- Testes puros de flags, payloads ausentes, composição das contagens e estado de consulta desconhecido.
- CI Flutter analyze/test, integração e Playwright obrigatórios para o PR.

## Pendências futuras
- O limite da fila continua 500 *pendências*, e não é uma contagem total irrestrita. Paginação e total oficial exigem API dedicada ou protocolo de cursor, sem expor os dados de outros espaços.
- Conciliação financeira real requer leitura e confirmação bidirecional de eventos, versões e estados por linha; este PR melhora apenas a central de **classificação**.
- QA físico no iPhone segue como gate de aceitação real.
