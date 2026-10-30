# FÔLEGO 3.0 — Central Resolver

## Jornada
- Na Home, o atalho **resolver** abre a central diretamente, em vez de abrir o filtro de busca de pendências. O atalho **buscar** continua separado.
- A Central Resolver é um quarto modo da tela existente **organizar meu dinheiro**, com as guias anteriores (comentários, pendências, Outros) preservadas.
- Lê e reúne quatro filas existentes, SEM escrita automática: comprovantes aguardando conciliação, categorias pendentes, despesas "Outros" e eventos sem tipo fixo/variável.
- Mostra a **próxima ação** prioritária no início. As demais pendências ficam em uma expansão voluntária. Se a consulta completa retornar vazia, informa que não há tarefas naquelas filas — não afirma que os saldos bancários foram conciliados.
- Ao tocar numa tarefa, abre o fluxo de revisão já existente: CaptureReviewScreen, TransactionClassificationInbox, editor de categoria Outros com confirmação ou detalhe do lançamento. Nenhum item é pago, excluído, fundido ou categorizado automaticamente.
- Retorna à fila e atualiza a leitura depois de voltar do fluxo original.

## Segurança financeira
- Consultas continuam restritas ao **space_id** e à sessão autenticada, com RLS existente.
- Ao trocar o espaço, apaga categorias e histórico temporários e não exibe um resultado antigo durante uma nova requisição.
- Um mesmo ID em financial_events pode aparecer em múltiplas filas. Exibe apenas a tarefa de maior prioridade: classificação > Outros > comportamento. Um comprovante pertence à tabela própria e tem identidade independente.
- Valores monetários e descrições são mascarados na central se o modo de privacidade estiver ativado.
- Se qualquer fila falhar, mostra opção de repetir, não um falso estado "sem pendências".
- Mantém todos os relatórios, lançamentos, importações e cálculos sem alterações.

## QA
- Casos: prioridade, deduplicação de evento, ID de comprovante independente, datas, fila vazia, acesso Home, privacidade e fluxos mantidos.
- Flutter analyze, regressão completa, QA responsivo, temas, smoke e deploy.
