# Fôlego 3.0 — menos notificações, uma ação por vez

## Notificações
- Em Perfil → notificações, botão **usar só avisos essenciais** é uma opção voluntária, não uma migração automática de preferências existentes.
- Ao escolher, desativa apenas: resumo diário, chamada após 90 minutos, resumo semanal e avisos informativos por movimentação.
- Mantém os estados atuais dos alertas de vencimentos, faturas, dívidas, itens atrasados, limites do orçamento e cartões e gastos relevantes; respeita o interruptor geral e a permissão do aparelho.
- Tom, horários, notificações por tipo e histórico continuam em **ver mais opções**.
- Operação salva todas as quatro preferências em conjunto pela API existente; falhas exibem erro e restauram o estado anterior.

## Insights
- Em Futuro → Plano, exibe só **uma próxima ação** no topo dos insights: primeiro uma pendência verificada (abre a auditoria existente), senão a primeira sugestão de categoria (abre o modal existente de confirmação), senão não exibe mais um cartão.
- O botão da sugestão não grava nem altera valores automaticamente. Se a edição estiver desabilitada (mês anterior), não oferece ação de ajuste.
- Mantém os três indicadores distintos (despesa econômica, saída de caixa e disponível estimado), auditoria completa e sugestões adicionais sob os expanders existentes.
- Valores na ação obedecem ao modo privativo.

## Limites
- Não altera banco, Supabase, cron, lógica de vencimentos, deduplicação, saldo, orçamento, lançamentos ou notificações já entregues.
- O Fôlego **não desliga os lembretes existentes automaticamente**; o usuário deve escolher o modo essencial.
- Não cria inferências sobre tipo de gasto nem assume que uma pendência financeira seja um erro.

## Critérios de aceite
- Testes de modo essencial, auditoria de prioridade e privacidade.
- Testes de notificações existentes, Plan, Flutter analyze, QA visual, integração e cross-device.
- Publicar só com todas as verificações aprovadas.
