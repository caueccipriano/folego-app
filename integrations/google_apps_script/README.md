# Fôlego ↔ Google Sheets

Integração bidirecional entre o app Fôlego (Supabase) e a planilha `Controle Financeiro 2026`.

## Arquitetura e regra de propriedade

- O app Flutter lê e grava no Supabase.
- A planilha mantém o Web App/Apps Script V3.3 usado pelo atalho do iPhone.
- `FolegoSync.gs` entra no MESMO projeto Apps Script e não declara `doPost()`, portanto não troca a URL nem substitui o Web App atual.
- A planilha é fonte de captura para data, valor, descrição, conta/cartão e origem.
- O Fôlego é a fonte da classificação econômica.
- Depois da classificação no app, Categoria + Subcategoria voltam para a mesma linha da planilha.
- O Apps Script chama a Edge Function `sheet-sync` usando `FOLEGO_SYNC_TOKEN` guardado somente em Script Properties.
- `service_role` fica somente no ambiente da Edge Function.

## Planilha → Fôlego

Entram automaticamente:
- despesas em conta;
- receitas;
- compras em cartão e quantidade de parcelas;
- benefícios/Flash;
- novas transferências e pagamentos de cartão quando identificáveis;
- data, valor, descrição, conta/cartão e ID estável do lançamento.

Lançamentos econômicos novos entram no Fôlego para classificação pelo usuário. A categoria antiga da planilha é apenas contexto e não sobrescreve a classificação do app.

## Fôlego → planilha

O retorno atualiza a MESMA linha quando o ID já existe. São sincronizados:
- categoria plana em H, para preservar os dashboards atuais;
- Categoria Fôlego em X;
- Subcategoria Fôlego em Y;
- caminho hierárquico em Z (técnico/oculto);
- compras no cartão completam o número de parcelas no bloco `Compras No Cartão` quando necessário.

Eventos originados diretamente no app que ainda não existem na planilha podem ser acrescentados como novas linhas confirmadas.

## Baseline desta planilha

O histórico até a linha **192** já foi reconstruído e auditado no Fôlego. Por isso o instalador marca apenas as linhas 5:192 como `BASE`.

As linhas **193 em diante não são baselinadas**: no primeiro ciclo elas são enviadas ao app. Isso evita perder lançamentos criados depois da auditoria.

O primeiro pull começa em `2026-06-01`, permitindo preencher Categoria/Subcategoria do histórico existente sem recriar os eventos financeiros.

## Instalação no Apps Script existente

1. Abra `Controle Financeiro 2026` → **Extensões → Apps Script**.
2. No mesmo projeto que contém o V3.3, crie ou substitua o arquivo `FolegoSync.gs` pelo conteúdo deste diretório.
3. Em **Configurações do projeto → Propriedades do script**, crie `FOLEGO_SYNC_TOKEN` com o token fornecido separadamente. Nunca coloque o token em uma célula ou no GitHub.
4. Salve e execute `folegoSyncInstall()` **uma única vez**. Autorize as permissões solicitadas.
5. Depois execute `folegoSyncStatus()` e confira:
   - `ok: true`
   - `triggerCount: 1`
   - `errorRows: 0`
   - `pendingSheetRows: 0` após o primeiro ciclo bem-sucedido.

O instalador cria um gatilho a cada 5 minutos. Não é necessário reimplantar o Web App V3.3.

## Colunas da aba Lancamentos

Compatibilidade existente:
- H: categoria plana usada pelas fórmulas e dashboards atuais.

Sincronização técnica:
- U: `Sync Fôlego` (oculta)
- V: `Sync em` (oculta)
- W: `Sync hash` (oculta)

Hierarquia do Fôlego:
- X: `Categoria Fôlego` (visível)
- Y: `Subcategoria Fôlego` (visível)
- Z: `Caminho Fôlego` (oculta)

## Segurança

A Edge Function valida simultaneamente o ID da planilha e o hash do token. O token não é salvo em células nem no repositório. O cadastro de integração no Supabase permanece interno, e a `service_role` não é exposta ao Flutter ou ao Apps Script.

Se o token for exposto, gere outro, atualize o hash no Supabase e troque somente a Script Property `FOLEGO_SYNC_TOKEN`.
