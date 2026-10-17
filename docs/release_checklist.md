# Fôlego — release readiness checklist

Target desta fase: **0.9.0+1** (pré-lançamento / beta).

O app está funcionalmente avançado, mas a publicação nativa ainda depende de itens de infraestrutura, legal e store que não devem ser inventados no código. Este documento separa o que já foi validado do que ainda bloqueia uma publicação pública.

## 1. Auditoria de produto

| Área | Estado | Observação |
| --- | --- | --- |
| Auth | A/B | fluxo existente preservado; recuperação, sessão e logout permanecem canônicos; log de listener sanitizado |
| Home | B corrigido | primeiro uso explica setup faltante e não apresenta `R$ 0,00` como conclusão quando ainda faltam dados |
| Lançamentos | A | filtros/search/keyset e page size canônicos preservados |
| Novo lançamento / Quick Register | A | fluxo existente preservado |
| Transaction Detail | A | origem amigável de importação preservada |
| Plano | A | scroll/expansão e arquitetura Web 2.0 preservados |
| Carteira | A | Wallet 3.0 e CRUD de instrumentos preservados |
| Contas | A | sem edição direta de saldo |
| Cartões | A | sem mudança de semântica de compra/fatura |
| Benefícios | A | dimensão benefit permanece separada de cash |
| Dívidas | A | Debt 2.0 preservado |
| Agenda | A | fluxo canônico preservado |
| Diário | A | Material/desktop regressions já cobertas |
| Metas | A/B | empty state e CTA já existem; error translation usa helper canônico |
| Categorias | A | categorias/subcategorias/icon_key preservados |
| Perfil | A/B | ganhou Notificações e Automações; legal/suporte ainda dependem de destinos reais |
| Importador | A | CSV/OFX continua staging → dedupe → rules evaluation → preview/revisão → confirmação canônica |
| Notificações | A arquitetura | preferences, projection, intents, service, lifecycle e Web no-op prontos; Android/iOS ausentes |
| Automações | A fundação | rules determinísticas + RLS + audit log + importer integration; produção continua Free/preview |
| Onboarding | B corrigido | introdução curta de 4 passos, pulável e sem escrita financeira obrigatória |

Legenda: A pronta; B polimento; C bug visual; D bug funcional; E inconsistência; F microcopy confusa.

### Notifications + Automation Foundation 1.0

- [x] `FeatureEntitlements` é a fonte canônica de capabilities.
- [x] Produção default = FREE.
- [x] Essential notifications permanecem FREE.
- [x] Automation Rules ficam Premium futuro, com mock injetável em teste/dev.
- [x] Nenhum billing/checkout/paywall real foi adicionado.
- [x] `notification_preferences` é user + financial space com RLS.
- [x] Agenda (`get_upcoming_events`) permanece a fonte canônica de vencimentos.
- [x] `get_notification_upcoming_events` usa timezone do financial space e janela de 30 dias.
- [x] Faturas, dívidas, recorrências, assinaturas, entradas previstas e atrasados entram na projeção.
- [x] Chaves de reminder são determinísticas e não incluem valor financeiro.
- [x] Logout e troca de financial space limpam o contexto anterior.
- [x] Realtime usa o coordinator existente e domínios coalescidos.
- [x] `automation_rules` usa schema restrito, precedence determinística e source scope.
- [x] `automation_rule_runs` é audit log read-only para cliente autenticado.
- [x] Automação roda somente após staging/dedupe do importador.
- [x] Rules não escrevem diretamente no ledger.
- [x] Review do importador continua obrigatória.
- [x] Metadata de automação é exposta no `StatementImportRow` sem alterar o contrato de confirmação.
- [x] Helper explícito de “Sempre fazer assim” prepara uma rule de review; nenhuma rule é criada silenciosamente.
- [x] Migration reconciliadora `20260917101500_finalize_notifications_automation_foundation.sql` aplicada no Dev.
- [x] SQL rollback test de boundaries/RLS executado no Dev.
- [ ] Android local notifications — BLOCKED UNTIL NATIVE TARGET EXISTS.
- [ ] iOS local notifications — BLOCKED UNTIL NATIVE TARGET EXISTS.

## 2. Qualidade de UX

- [x] Design system central em `AppColors`, `AppTypography`, `AppIcons`, `AppBreakpoints` e `AppContentContainer`.
- [x] Unbounded reservada para marca/títulos/destaques; Manrope permanece em corpo, labels e controles.
- [x] Home de primeiro uso não conclui valor financeiro sem setup suficiente.
- [x] Onboarding é curto e pode ser pulado.
- [x] Metas já possui empty state específico e CTA.
- [x] Importador possui erros amigáveis e não expõe stack/SQLSTATE/RPC ao usuário.
- [x] Ações destrutivas financeiras relevantes continuam com confirmação quando há risco real.
- [x] Light e dark usam o mesmo design system e contrastes semânticos centrais.
- [x] Breakpoints oficiais continuam sendo a referência para mobile/tablet/desktop.
- [ ] Revisão manual em dispositivos físicos deve ser feita antes de produção pública, principalmente teclado, safe areas e fontes do sistema.

## 3. Segurança e privacidade

- [x] Nenhum `service_role` é usado pelo Flutter.
- [x] Nenhum `SUPABASE_SERVICE_ROLE`, `sb_secret_` ou private key foi encontrado no repositório durante a auditoria.
- [x] A chave Supabase presente no cliente é publishable/anon, apropriada para app cliente.
- [x] RPCs financeiros auditados exigem `auth.uid()` e membership/write-space.
- [x] Execução anônima desnecessária de RPCs SECURITY DEFINER foi revogada na migration `20260916180631_harden_release_rpc_anonymous_access.sql`.
- [x] O importador usa file picker e não precisa de acesso amplo ao storage.
- [x] Arquivo CSV/OFX original não é armazenado indefinidamente no backend.
- [x] Listener de auth não imprime exception completa/stack em produção.
- [x] `notification_preferences`, `automation_rules` e `automation_rule_runs` têm RLS ON.
- [x] `automation_rule_runs` não possui grant de escrita para `authenticated`.
- [x] `automation_rules.space_id` e `created_by` são imutáveis por trigger de hardening.
- [x] Nenhum dado de banco, push, billing ou provider externo foi inventado.
- [ ] **BEFORE STORE:** habilitar proteção contra senhas vazadas no Supabase Auth e revalidar login/cadastro/recuperação.
- [ ] **BEFORE STORE:** revisar todas as políticas e URLs do projeto Supabase de produção, separado do ambiente Dev.

### Advisors — triagem

Executar Security Advisors e Performance Advisors após qualquer DDL final. Findings devem ser classificados como A (introduzido), B (pré-existente) ou C (informativo). Corrigir apenas A neste bloco; não abrir scope histórico sem relação com Notifications/Automation.

## 4. Logging, analytics e crash reporting

Analytics e crash reporting **não foram adicionados automaticamente** nesta fase.

Nunca enviar/logar em telemetry customizada:

- valores financeiros;
- saldo;
- descrição de lançamento;
- merchant;
- nome de instituição digitado pelo usuário;
- dados de dívida;
- arquivo importado ou conteúdo bruto;
- notification body completo;
- email;
- tokens/session/JWT.

Crash reporting futuro deve sanitizar payloads de backend e metadata financeira antes de envio.

## 5. Versionamento e identidade

- [x] Versão preparada: `0.9.0+1`.
- [x] Nome do produto: **Fôlego**.
- [x] Manifest e metadata Web usam nome/descrição/cores da marca.
- [x] Assets de ícone Web existem.
- [ ] **BEFORE STORE:** revisar visualmente ícones finais de marca em todos os tamanhos.

A versão permanece `0.9.x` porque ainda faltam legal, produção e scaffolds/signing nativos. Migrar para `1.0.0+N` somente quando esses bloqueios estiverem resolvidos.

## 6. Web

- [x] PWA manifest preparado para Fôlego.
- [x] Web metadata preparada.
- [x] Notifications usa adapter Web-safe/no-op; build Web não depende de plugin nativo.
- [x] CI executa `flutter build web --release` sem deploy externo.
- [ ] Conferir console do browser em uma execução manual do artefato antes de produção.

## 7. Android

**BLOCKER para Play Store e para validar notificações locais:** o repositório atual não contém diretório `android/`.

Antes de publicar/validar notifications nativas:

- [ ] gerar/reconciliar o platform scaffold Android de forma controlada;
- [ ] definir `applicationId` definitivo;
- [ ] revisar minSdk/targetSdk;
- [ ] configurar Android 13+ notification permission;
- [ ] criar channels e ícone de notification;
- [ ] validar comportamento em background;
- [ ] não exigir exact alarm sem necessidade;
- [ ] configurar signing fora do repo;
- [ ] executar `flutter build appbundle --release` com configuração real.

O AAB e notifications nativas **não devem ser declarados validados** enquanto o target Android estiver ausente.

## 8. iOS

**BLOCKER para App Store e para validar notificações locais:** o repositório atual não contém diretório `ios/`.

Antes de publicar/validar notifications nativas:

- [ ] gerar/reconciliar platform scaffold iOS em macOS/Xcode;
- [ ] definir bundle identifier definitivo;
- [ ] revisar deployment target;
- [ ] configurar notification permission/capability;
- [ ] validar scheduling e deep links;
- [ ] configurar Team/Certificates/Provisioning fora do repo;
- [ ] executar build/archive de release no Xcode.

Nenhuma credencial Apple/APNs foi inventada ou commitada.

## 9. Legal e suporte

**BEFORE STORE**

- [ ] URL pública e real de Política de Privacidade.
- [ ] URL pública e real de Termos de Uso.
- [ ] canal real de Contato/Suporte.
- [ ] inserir esses destinos no Perfil e nas fichas de loja somente quando existirem.

Não há URLs falsas ou texto jurídico inventado no app.

## 10. Premium / assinatura

- [x] `FeatureEntitlements` concentra a decisão de capabilities.
- [x] Release atual usa FREE como default.
- [x] `MockPremiumEntitlementProvider` existe somente por injeção para teste/dev.
- [x] Essential notifications permanecem FREE.
- [x] Automation Rules estão preparadas para Premium futuro.
- [x] Não existe billing real, checkout ou paywall real nesta fase.
- [x] Não existe estado pago client-editável.

## 11. Supabase / migrations

- [x] Migration de hardening de RPCs aplicada no Dev e registrada no repo.
- [x] Foundation concorrente de Notifications/Automation foi auditada sem reescrever migration aplicada.
- [x] Migration posterior `20260917101500_finalize_notifications_automation_foundation.sql` reconcilia trigger/index/projeção necessária para replay futuro.
- [x] Repo e Dev estão alinhados no schema/contrato final deste bloco.
- [ ] O histórico de versões concorrentes (`16233716`, `16233816`, `16235122`) não é idêntico entre Dev e repo; isso é histórico conhecido e não foi reescrito.
- [ ] **BEFORE STORE:** validar migration chain completa em projeto limpo/staging antes do go-live.
- [ ] Usar projeto/keys/redirects de produção; o fallback atual de build aponta para Fôlego Dev.

Não reescrever migrations já aplicadas para corrigir histórico.

## 12. Testes / CI

Antes de cada release candidate:

```bash
flutter pub get
flutter analyze
flutter test -r expanded
flutter build web --release
```

Obrigatório:

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test -r expanded` → `All tests passed!`
- [ ] `flutter build web --release` → success
- [ ] SQL rollback tests relevantes → success
- [ ] Security/Performance Advisors auditados
- [ ] GitHub Actions verde no SHA exato da release candidate

Regressões que devem continuar cobertas:

- card purchase;
- invoice payment;
- recurring card e occurrences;
- transaction pagination, filters e search;
- transaction classification;
- Agenda;
- Debt 2.0;
- Categories;
- Wallet 3.0;
- CSV/OFX importer;
- Notifications/Automation foundation;
- Realtime;
- Plan state.

## 13. Known issues

### BLOCKER

- Android platform ausente para Play Store/AAB e validação real de local notifications.
- iOS platform ausente para App Store/archive e validação real de local notifications.
- ambiente Supabase de produção não está configurado como destino padrão de uma release de loja.

### BEFORE STORE

- Política de Privacidade real.
- Termos de Uso reais.
- canal de Suporte real.
- leaked-password protection no Auth.
- ensaio da migration chain em ambiente limpo.
- assinatura, bundle/package IDs e store assets nativos.
- revisão visual final dos ícones.

### POST-LAUNCH / APÓS MÉTRICA

- provider real de billing/entitlements, se Premium for comercializado;
- Open Finance/bank sync somente via provider autorizado e candidate staging;
- analytics privacy-safe, se houver decisão de produto/provider;
- crash reporting sanitizado, se houver decisão de provider;
- avaliar índices não usados e FKs sem índice com tráfego real.
