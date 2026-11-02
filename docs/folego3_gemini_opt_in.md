# Gemini como provedor único do Fôlego

O assistente financeiro `financial-ai` usa exclusivamente a API Gemini do Google.
Não há fallback para OpenAI, nem seleção por `FOLEGO_AI_PROVIDER`.

**Segredo obrigatório no Supabase Edge Function Secrets:** `GEMINI_API_KEY`.
A chave nunca deve estar no PWA, no Flutter, nos commits nem em URLs.
**Modelo padrão:** `gemini-3.5-flash-lite`. Pode ser definido outro modelo
compatível no segredo opcional `FOLEGO_GEMINI_MODEL`.

O endpoint GET autenticado de `financial-ai` retorna `provider: gemini`
e `configured: true/false`, sem expor a chave e sem consumir cota.
Caso a chave esteja ausente, a consulta é indisponibilizada e nenhuma
pergunta Premium é descontada.

A autenticação JWT, o isolamento por espaço financeiro, a quota Premium,
o reembolso em caso de falha e o processamento de totais agregados permanecem.
O assistente é somente leitura e nunca modifica lançamentos.

## Validação

1. Executar `deno test --no-check supabase/tests/gemini_adapter_test.ts supabase/tests/financial_category_context_test.ts` e `deno check supabase/functions/financial-ai/index.ts`.
2. Verificar status GET autenticado: `provider: gemini` e `configured: true`.
3. Fazer uma pergunta autenticada e confirmar resposta `provider: gemini`.
4. Confirmar a falha segura sem chave e o reembolso da quota em falhas.
