# Gemini opcional no Fôlego

A função financial-ai continua usando OpenAI por padrão. Gemini será usado
apenas com FOLEGO_AI_PROVIDER=gemini e GEMINI_API_KEY definidos
como secrets no Supabase. A chave nunca pertence ao PWA nem ao repositório.

Modelo padrão: gemini-3.5-flash-lite (configurável via FOLEGO_GEMINI_MODEL).

Somente os totais agregados já aceitos pela função são enviados ao modelo.
Permanecem autenticação JWT, quota Premium, reembolso em falhas, limite de
pergunta e ausência de dados transacionais individuais.

Após configurar secrets, validar uma pergunta autenticada e o caso de erro
antes de confirmar o uso no ambiente real.