# Fôlego ↔ Google Sheets

Integração bidirecional entre o app Fôlego (Supabase) e a planilha `Controle Financeiro 2026`.

## Arquitetura

- O app Flutter continua lendo e gravando no Supabase.
- A planilha continua usando o Web App/Apps Script V3.3 existente para o atalho do iPhone.
- `FolegoSync.gs` é adicionado ao mesmo projeto Apps Script, sem substituir `doPost()` e sem trocar a URL do Web App existente.
- O Apps Script chama a Edge Function `sheet-sync` do Supabase usando um token exclusivo armazenado em Script Properties.
- `service_role` nunca é exposto no Flutter, na planilha ou no Apps Script; ele existe apenas no ambiente da Edge Function.

## O que sincroniza

Planilha → Fôlego:
- despesas em conta;
- receitas;
- compras em cartão;
- benefícios/Flash;
- novas transferências quando origem e destino são identificáveis;
- categoria e descrição de lançamentos econômicos já existentes;
- IDs estáveis para impedir duplicação.

Fôlego → planilha:
- novos lançamentos confirmados originados no app;
- categoria compatível com a taxonomia plana da planilha;
- conta/cartão;
- compras no cartão também entram no bloco `Compras No Cartão`, preservando as fórmulas de parcelas/faturas já existentes.

Eventos cancelados do app não são importados. Movimentações históricas já baselinadas (transferências/pagamentos) não são reclassificadas automaticamente.

## Instalação no Apps Script existente

1. Abra `Controle Financeiro 2026` → Extensões → Apps Script.
2. Crie um arquivo chamado `FolegoSync.gs` e cole o conteúdo de `FolegoSync.gs` deste diretório.
3. Em Configurações do projeto → Propriedades do script, crie `FOLEGO_SYNC_TOKEN` com o token fornecido separadamente. Nunca coloque esse token em uma célula ou no GitHub.
4. Salve e execute `folegoSyncInstall()` uma única vez. Autorize as permissões solicitadas.
5. Execute `folegoSyncStatus()` para verificar `ok: true` e `triggerCount: 1`.

O instalador cria um gatilho a cada 5 minutos. Não é necessário substituir nem recriar a implantação do Web App V3.3, porque este arquivo não declara `doPost()`.

## Colunas técnicas da planilha

Na aba `Lancamentos`, as colunas U:W são reservadas e podem permanecer ocultas:
- U: `Sync Fôlego`
- V: `Sync em`
- W: `Sync hash`

O primeiro `folegoSyncInstall()` marca os lançamentos já existentes como `BASE`. Isso evita reimportar todo o histórico e protege pagamentos de cartão e transferências antigas contra dupla contagem.

## Segurança

A Edge Function valida simultaneamente o ID da planilha e o hash do token. O cadastro de integração no Supabase não é legível por `anon`/`authenticated`. As funções de escrita usadas pela integração são executáveis apenas por `service_role` e não ficam disponíveis para o cliente Flutter.

Se o token for exposto, gere outro, atualize o hash no Supabase e substitua somente a Script Property `FOLEGO_SYNC_TOKEN`.
