# Fôlego — proteção de espaços financeiros (13/10/2026)

## Objetivo
Evitar que a interface do Fôlego mostre categorias, marcadores ou contadores de pendências do espaço financeiro anterior após uma mudança de espaço.

## Alterações
- **Perfil → Organização**: recebe `spaceId` selecionado pelo HomeShell, sem voltar a consultar o primeiro espaço no banco.
- **Categorias e marcadores**: descarta respostas assíncronas atrasadas após troca de espaço ou recarregamentos repetidos.
- **Transações → Pendências**: limpa contador e registros ao trocar de espaço, cancela logicamente o resultado antigo com `requestGeneration` e `spaceEpoch` e evita que erro de refresh mantenha contador sem garantia de atualização.
- **Importação**: guarda a resolução assíncrona de espaço quando a tela muda no meio da consulta.
- Testes Flutter com duas categorias sintéticas A/B e resposta A atrasada, além da validação isolada do guard.

## O que não muda
- Nenhum saldo, transação, categoria, fatura, comentário ou vínculo Supabase é gravado por esta correção.
- O banco, a planilha e o Apps Script permanecem intocados.
- O Fôlego continua independente do EU, e a configuração de Push permanece sem mudanças.

## Aceite de release
- Flutter analyze limpo; testes específicos de isolamento; smoke integrado; Playwright e build.
- Verificar manualmente um cenário de alternância de dois espaços em staging isolado. Teste automatizado com fixtures não equivale a QA manual em aparelho.
- Merge somente após aprovação de CI.