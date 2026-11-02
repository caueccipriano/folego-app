# Fôlego IA 2.0 — análise por categoria sob demanda

## Funcionamento
O usuário abre Mais → Perguntar ao Fôlego e escolhe uma pergunta. O cliente envia o ID do espaço autenticado. A função Supabase `financial-ai` verifica a sessão e acesso ao espaço por RLS antes de chamar exclusivamente as RPCs já existentes:
- `get_monthly_money_summary`: receita, despesa econômica por competência e resultado do mês.
- `get_budget_overview`: categorias-pai e limites mensais, sem somar subcategorias duas vezes.
- `get_budget_impact_details`: até quatro categorias-pai, nos meses atual e anterior, mesmo número de dias, deduplicação por ID de impacto.

Os detalhes/IDs de lançamentos ficam no servidor; o modelo recebe **só até quatro categorias agregadas** e o resumo. O contexto marca expressamente que uso do orçamento por categoria pode incluir pagamentos de dívida e não equivale à despesa econômica. Percentual só é calculado com base anterior positiva. Meses sem dados ou com consultas incompletas não geram afirmações.

Uma próxima ação determinística (revisar gastos sem categoria, excesso de limite ou alta comparável) aparece ao lado da resposta, com botão para abrir Planejamento. Nenhuma alteração de gasto, categoria ou limite ocorre automaticamente. IA só é acionada mediante clique do usuário, preservando a quota Premium e seu reembolso em falha. O modo de privacidade oculta respostas e impede solicitações.

## Implantação e limites
- Implementar e validar a função `financial-ai` no Supabase correspondente ao domínio PWA.
- A função aceita `spaceId` e mantém compatibilidade com contextos agregados antigos. Para clientes novos, ignora os valores financeiros enviados pelo cliente e busca valores oficiais com a sessão do usuário.
- O provedor permanece **OpenAI por padrão**; Gemini é opcional e requer secrets configurados no Supabase: `FOLEGO_AI_PROVIDER=gemini` e `GEMINI_API_KEY`. Nunca inserir chaves no PWA ou no repositório.
- Não afirmar que o Gemini respondeu até passar teste autenticado real; não é possível verificar por mera existência da Edge Function.
- Não gerar notificações automáticas ou consumir perguntas de IA em background.
- Quatro categorias são uma amostra de maior impacto; não representam automaticamente todas as categorias do mês.

## Verificações
Executar `deno test --no-check supabase/tests/gemini_adapter_test.ts supabase/tests/financial_category_context_test.ts`, `deno check supabase/functions/financial-ai/index.ts`, `flutter analyze`, `flutter test`, QA mobile/desktop, e um teste autenticado em ambiente de desenvolvimento com acesso ao espaço e conta Premium. Verificar acesso negado a outro espaço, período com zero anterior e erro/reembolso do provedor antes de declarar pronto para produção.
