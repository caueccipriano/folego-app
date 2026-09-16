# Fôlego — release readiness checklist

Target desta fase: **0.9.0+1** (pré-lançamento / beta).

O app está funcionalmente avançado, mas a publicação nativa ainda depende de itens de infraestrutura, legal e store que não devem ser inventados no código. Este documento separa o que já foi validado do que ainda bloqueia uma publicação pública.

## 1. Auditoria de produto

| Área | Estado | Observação |
| --- | --- | --- |
| Auth | A/B | fluxo existente preservado; recuperação, sessão e logout permanecem canônicos; log de listener sanitizado |
| Home | B corrigido | primeiro uso agora explica setup faltante e não apresenta `R$ 0,00` como conclusão quando ainda faltam dados |
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
| Perfil | B | UX funcional; legal e suporte ainda precisam de destinos reais antes da loja |
| Importador | A | CSV/OFX continua staging → preview/revisão → confirmação |
| Onboarding | B corrigido | introdução curta de 4 passos, pulável e sem escrita financeira obrigatória |

Legenda: A pronta; B polimento; C bug visual; D bug funcional; E inconsistência; F microcopy confusa.

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
- [ ] **BEFORE STORE:** habilitar proteção contra senhas vazadas no Supabase Auth e revalidar login/cadastro/recuperação.
- [ ] **BEFORE STORE:** revisar todas as políticas e URLs do projeto Supabase de produção, separado do ambiente Dev.

### Advisors — triagem

**P0**
- Nenhum finding novo de schema identificado após o hardening de acesso anônimo.

**P1**
- Leaked-password protection desabilitado: habilitar antes de publicação pública.
- Garantir projeto Supabase de produção e respectivos redirect/deep-link URLs antes da loja.

**P2**
- `sheet_sync_integrations` com RLS habilitado e sem policy: comportamento atual é deny-by-default; manter enquanto não houver acesso client-side previsto.
- WARNs de `SECURITY DEFINER` para `authenticated`: funções auditadas usam `SET search_path = ''`, `auth.uid()` e checagem de membership/write-space; são RPCs canônicos do app.
- Foreign keys sem índice e índices não usados: acompanhar com métricas reais, sem micro-otimização prévia.
- Índice duplicado histórico em `recurring_items`: remover apenas depois de reconciliar migration history e confirmar dependências.

## 4. Logging, analytics e crash reporting

Analytics e crash reporting **não foram adicionados automaticamente** nesta fase.

Se um provider for escolhido depois, eventos mínimos permitidos:

- `onboarding_completed`
- `transaction_created`
- `transaction_import_completed`
- `plan_created`
- `goal_created`
- `account_created`
- `card_created`
- `category_created`

Nunca enviar em analytics customizado:

- valores financeiros;
- saldo;
- descrição de lançamento;
- merchant;
- nome de instituição digitado pelo usuário;
- dados de dívida;
- arquivo importado ou conteúdo bruto;
- email;
- tokens/session/JWT.

Crash reporting deve sanitizar payloads de backend e metadata financeira antes de envio.

## 5. Versionamento e identidade

- [x] Versão preparada: `0.9.0+1`.
- [x] Nome do produto: **Fôlego**.
- [x] Manifest e metadata Web usam nome/descrição/cores da marca.
- [x] Assets de ícone Web existem.
- [ ] **BEFORE STORE:** revisar visualmente ícones finais de marca em todos os tamanhos; não redesenhados nesta tarefa.

A versão permanece `0.9.x` porque ainda faltam legal, produção e scaffolds/signing nativos. Migrar para `1.0.0+N` somente quando esses bloqueios estiverem resolvidos.

## 6. Web

- [x] PWA manifest preparado para Fôlego.
- [x] Web metadata preparada.
- [x] CI executa `flutter build web --release` sem deploy externo.
- [ ] Conferir console do browser em uma execução manual do artefato antes de produção.

## 7. Android

**BLOCKER para Play Store:** o repositório atual não contém diretório `android/`.

Antes de publicar:

- [ ] gerar/reconciliar o platform scaffold Android de forma controlada;
- [ ] definir `applicationId` definitivo;
- [ ] conferir app name;
- [ ] revisar minSdk/targetSdk;
- [ ] revisar permissões;
- [ ] instalar adaptive icon final;
- [ ] configurar signing via secret/CI ou máquina de release;
- [ ] nunca commitar keystore real ou senhas;
- [ ] executar `flutter build appbundle --release` com configuração real.

O AAB **não deve ser declarado validado** enquanto o platform Android estiver ausente.

## 8. iOS

**BLOCKER para App Store:** o repositório atual não contém diretório `ios/`.

Antes de publicar:

- [ ] gerar/reconciliar platform scaffold iOS em macOS/Xcode;
- [ ] definir bundle identifier definitivo;
- [ ] revisar deployment target;
- [ ] revisar Info.plist e permissões;
- [ ] revisar URL schemes/deep links de auth recovery;
- [ ] instalar AppIcon/LaunchScreen finais;
- [ ] configurar Team/Certificates/Provisioning fora do repo;
- [ ] executar build/archive de release no Xcode.

Nenhuma credencial Apple deve ser inventada ou commitada.

## 9. Legal e suporte

**BEFORE STORE**

- [ ] URL pública e real de Política de Privacidade.
- [ ] URL pública e real de Termos de Uso.
- [ ] canal real de Contato/Suporte.
- [ ] inserir esses destinos no Perfil e nas fichas de loja somente quando existirem.

Não há URLs falsas ou texto jurídico inventado no app.

## 10. Premium / assinatura

- Não foi implementada cobrança nesta fase.
- Não há SDK/paywall/entitlement de assinatura identificado como requisito técnico atual.
- Beta gratuita pode ser publicada sem assinatura.
- Se o lançamento público for pago/premium, billing + entitlement + políticas de restore/cancelamento passam a ser **P0 de produto** antes da loja.

## 11. Supabase / migrations

- [x] Nova migration de hardening aplicada no Dev e registrada no repo com a mesma versão `20260916180631`.
- [ ] **BEFORE STORE:** reconciliar diferenças históricas de versões/nomes entre migrations já aplicadas no Dev e arquivos do repo antes de depender de um deploy from-scratch para produção.
- [ ] Validar migration chain completa em um projeto limpo/staging antes do go-live.
- [ ] Usar projeto/keys/redirects de produção; o fallback atual de build aponta para Fôlego Dev.

Não reescrever migrations já aplicadas para corrigir esse histórico.

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
- Realtime;
- Plan state.

## 13. Known issues

### BLOCKER

- Android platform ausente para Play Store/AAB.
- iOS platform ausente para App Store/archive.
- ambiente Supabase de produção não está configurado como destino padrão de uma release de loja.

### BEFORE STORE

- Política de Privacidade real.
- Termos de Uso reais.
- canal de Suporte real.
- leaked-password protection no Auth.
- reconciliação/ensaio da migration history em ambiente limpo.
- assinatura, bundle/package IDs e store assets nativos.
- revisão visual final dos ícones.

### POST-LAUNCH / APÓS MÉTRICA

- analytics privacy-safe, se houver decisão de produto/provider;
- crash reporting sanitizado, se houver decisão de provider;
- avaliar índices não usados e FKs sem índice com tráfego real;
- avaliar remoção do índice duplicado histórico em `recurring_items` com migration própria e evidência.
