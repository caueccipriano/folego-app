# Fôlego

**Saiba quanto você realmente pode gastar hoje sem apertar amanhã.**

Aplicativo de organização financeira pessoal em Flutter, com backend Supabase e arquitetura preparada para assinatura Premium via RevenueCat.

## Produto v1

### Free
- Fôlego diário e resumo financeiro;
- lançamentos manuais;
- histórico e filtros;
- planejamento mensal;
- contas, cartões, benefícios e dívidas;
- recorrências e assinaturas;
- metas e diário financeiro;
- lembretes financeiros essenciais;
- categorias, tema, conta, privacidade e exclusão de conta.

### Premium
Preço de lançamento planejado: **R$ 9,90/mês**, com oferta de **7 dias grátis** configurada pela loja.

Recursos:
- projeções e cenários futuros;
- automações de classificação;
- importação CSV/OFX;
- exportação CSV;
- capabilities de notificações avançadas.

Estados suportados: Free, Trial, Premium, Cortesia e Vitalício.

## Stack
- Flutter;
- Supabase Auth/Postgres/Edge Functions;
- RevenueCat para compras e entitlement;
- GitHub Actions para análise, testes e builds.

## Segurança
- cliente usa somente publishable key do Supabase;
- RLS protege dados por usuário/espaço;
- nenhuma `service_role` fica no app;
- concessões Premium manuais são controladas no backend;
- conta pode ser apagada pelo próprio usuário;
- logs de autenticação não incluem erro completo, e-mail, token ou stack trace.

## Executar localmente

### Dependências
Instale Flutter/Dart compatíveis com o `pubspec.yaml` e rode:

```bash
flutter doctor
```

### Gerar runners nativos
O repositório mantém o produto Flutter e gera os runners nativos de forma controlada.

macOS/Linux:

```bash
./scripts/bootstrap_flutter.sh
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap_flutter.ps1
```

Package Android planejado:

```text
com.caueccipriano.folego
```

### Configuração
Supabase pode ser sobrescrito por `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

RevenueCat na build de loja:

```bash
--dart-define=REVENUECAT_ANDROID_API_KEY=...
--dart-define=REVENUECAT_IOS_API_KEY=...
```

Use apenas chaves públicas de SDK no cliente. Nunca inclua chave secreta administrativa.

## QA
A branch `release/folego-v1` executa:
- `flutter analyze`;
- testes de entitlement e gates Premium;
- regressões de projeções;
- regressões de recorrências;
- regressões de notificações/automações;
- build Web;
- geração do scaffold nativo;
- compilação Android;
- snapshot da suíte legada para triagem.

Veja `docs/release_qa_v1.md`.

## Lojas
Materiais preparados em:
- `docs/store/google_play_listing_pt_BR.md`;
- `docs/store/google_play_data_safety.md`;
- `docs/store/app_store_listing_pt_BR.md`;
- `docs/store/app_store_privacy.md`;
- `docs/legal/`.

A publicação só deve acontecer após configurar contas de desenvolvedor, URLs públicas legais/suporte, RevenueCat, assinatura da build e testes em dispositivo físico.
