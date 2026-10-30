# Fôlego 3.0 — menos tarefas, mesmos dados

## O que sai da rotina

- O convite **revisar minhas finanças** e seu checklist diário deixam de ocupar a tela Hoje. O motor e a tela legados permanecem no código, sem apagar histórico; conferência de lançamentos continua em Perfil → Dados e aplicativo → Revisar lançamentos.
- A lista de últimas movimentações no **celular** sai da primeira dobra e passa para **seu mês em detalhes**, junto dos resumos e da projeção. Movimentos continua sendo a entrada principal para o histórico completo.
- O atalho extra **contas e metas** sai do Plano (Futuro) em todas as larguras. Os mesmos destinos continuam disponíveis: **Mais → contas, cartões e dívidas / metas**; os próximos compromissos também aparecem na tela Hoje e nas telas específicas.

## O que não sai

- Check-in inteligente somente quando há pendências ou exceções relevantes.
- Gráficos e detalhamento de orçamento, rosca de categorias, projeções, simulação de compra, contas, dívidas, cartões, diário opcional, perfil, notificações e integração com o Supabase.
- Resumo financeiro, sincronização, saldos, faturas, regras de importação, pagamentos, classificações e preferências.

## Critérios de QA

- flutter analyze e testes Flutter, inclusive `folego3_less_routine_test.dart`;
- Flutter smoke, Playwright cross-device e QA de temas;
- build PWA e deploy da branch de publicação;
- inspeção de iPhone: Hoje mostra o número de gasto diário, insight e pendências importantes; últimos movimentos aparecem ao abrir **seu mês em detalhes**; **Futuro** não repete **contas e metas**.

Escopo somente de apresentação e navegação. Sem migrações, exclusão de dados, alterações em RLS, Supabase ou lógica financeira.
