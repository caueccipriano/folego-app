# FÔLEGO — hospedagem candidata, sem migração

Cloudflare Pages está preparado como destino de um build Flutter estático, com backend Supabase independente. Nenhum projeto/domínio/DNS foi criado nesta execução. Não há acesso Cloudflare conectado confirmado. O preview Vercel já existente é apenas evidência de build, não homologação comercial nem aprovação do plano de hospedagem.

## Construção e empacotamento

```bash
cd folego_flutter
flutter pub get
flutter analyze
flutter test test/premium_sandbox_screen_test.dart test/pwa_web_contract_test.dart
flutter build web --release --base-href / --dart-define=FOLEGO_ASAAS_SANDBOX_UI=true
cd ..
python ops/hosting/prepare_cloudflare.py --version COMMIT_SHA
```

Publicar apenas o diretório `folego_flutter/build/web` em um projeto Pages de TESTE após autenticação e seleção da conta correta. NÃO ativar domínio comercial, mudar Site URL do Supabase, redirecionar o endereço GitHub nem migrar usuários nesta etapa. O script apenas escreve headers de cache/segurança, fallback SPA e versões; não acessa conta Cloudflare ou segredos.

Subdomínio de teste: escolher nome livre no próprio painel; disponibilidade não verificada. Novo domínio definitivo: pendente de escolha e eventual autorização de custo. HTTPS deve ser verificado no domínio efetivamente criado.

## Configuração após obter o endereço real

- Supabase Auth: acrescentar URL exata de teste aos Redirect URLs, preservando todas as existentes. Não substituir Site URL nesta fase.
- Inspecionar callbacks reais de autenticação e recuperação; não cadastrar wildcards amplos.
- `FOLEGO_ASAAS_ALLOWED_ORIGIN`: configurar a origem exata do preview de testes.
- Checkout Sandbox: configurar callback de retorno ao preview; callback só navega, nunca libera acesso.
- Testar login, recuperação, retorno do checkout, rotas `/legal/`, instalação iOS/Android e atualizações sem apagar dados de conta.
- Não cachear respostas de Auth/billing. Headers `_headers` servem assets estáticos; APIs Supabase já enviam `no-store` nas funções billing.
- Garantir que placeholders `__FOLEGO_BUILD_VERSION__` e `__FOLEGO_CACHE_VERSION__` não permaneçam no artefato final.

## Documentos e atendimento — bloqueios de lançamento

Os textos atuais `/legal/terms.html` e `/legal/privacy.html` já mencionam Asaas e a preservação das cortesias vitalícias. Antes de venda web: finalizar identidade legal e contato validado de suporte/privacidade, dados necessários para cobrança, renovação, cancelamento e tratamento de reembolso. Não publicar contato, CNPJ, política financeira ou prazo inventado.

Proposta para revisão: mensal R$9,90; anual R$89,90 apenas quando homologado; nenhuma promessa de trial implementado; cartão recorrente prioritário; Pix comum exige pagamento em cada ciclo; Pix Automático exige autorização específica e validação própria. Benefícios atuais/cortesias/vitalícios devem ser somados por fonte no backend, nunca sobrescritos pelo cliente ou pela cobrança.

Cancelamento e expiração: definir e implementar política de acesso até fim do período já pago, diferenciando interrupção de renovação, cobrança aberta e estorno. Exclusão de conta não pode deixar recorrência ativa silenciosamente: fluxo precisa tratar isso antes do lançamento.

Fontes oficiais consultadas:
- https://developers.cloudflare.com/pages/configuration/headers/
- https://docs.asaas.com/docs/criando-um-link-de-pagamentos
- https://docs.asaas.com/docs/pix-automatico
- https://docs.asaas.com/docs/diferen%C3%A7a-entre-pix-autom%C3%A1tico-e-assinaturas-1
