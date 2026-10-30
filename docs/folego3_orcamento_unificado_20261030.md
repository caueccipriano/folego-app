# FÔLEGO 3.0 — um lugar para o orçamento

## Decisão de produto
Em **Futuro → Plano**, o resumo do mês passa a apresentar os dois controles no mesmo contexto: limites por categoria (já existentes) e teto flexível (novo controle compacto inline). A pessoa pode **ajustar o teto flexível sem sair do Plano**; o detalhamento avançado continua disponível por "detalhes dos gastos flexíveis".

**Importante:** teto flexível e soma dos limites por categoria **não são a mesma métrica**. Não somamos os dois, não transferimos dinheiro entre eles e não interpretamos os valores como saldo bancário.

## Comportamentos preservados
- Limites por categoria continuam com editor mensal/recorrente e confirmações atuais.
- O teto flexível continua usando exatamente as RPCs `get_flexible_budget_overview` e `set_flexible_budget_limit`; nenhuma migração ou alteração financeira.
- Quando o backend devolve teto herdado das categorias (`explicit_limit=false`), mostrar "valor herdado"; não afirmar que o usuário configurou um teto próprio.
- Meses anteriores são somente consulta, e o módulo obedece à privacidade de valores ocultos.
- A leitura do teto tem estado de erro/repetir próprio, sem bloquear o restante do Plano.
- Mudança de mês ou espaço financeiro invalida leituras antigas e nunca mostra dados de outro espaço.

## QA
- Testes do novo componente: teto herdado, edição explícita, privacidade e troca de espaço.
- Testes Flutter, QA visual de temas, cross-device e build PWA.
- Se um teste falhar, não integrar até corrigir.

O acesso de compatibilidade ao orçamento flexível avançado e os acessos a partir da Home continuam funcionando. Após validar o fluxo centralizado em produção, pode-se reavaliar se vale ocultar atalhos adicionais.
