# Fôlego — Flutter v0.1

Primeira base mobile do **Fôlego**, conectada ao backend Supabase já construído para o produto.

> **Promessa:** saiba quanto você realmente pode gastar hoje sem apertar amanhã.

## O que já funciona nesta versão

- Supabase inicializado com **publishable key** (nenhuma chave privilegiada no cliente).
- Cadastro e login por e-mail + senha.
- Bootstrap automático de `Minhas Finanças` pelo backend.
- Onboarding em 6 etapas:
  1. conta e saldo atual;
  2. recebimento confirmado;
  3. conta recorrente;
  4. reserva protegida;
  5. cartão + fatura atual;
  6. primeiro orçamento variável.
- Estado do onboarding recuperado por `get_onboarding_state()`.
- Home real consumindo `get_folego_snapshot()`.
- Hero **Seu Fôlego hoje** com valor diário, status e valor até o próximo recebimento.
- Indicadores de caixa disponível, reserva, compromissos e caixa livre.
- Progresso do orçamento variável.
- Registro rápido de **despesa** e **receita** usando as RPCs atômicas do backend.
- Navegação-base: Início, Transações, Plano, Carteira e Perfil.
- Logout.

As abas Transações, Plano e Carteira já existem como estrutura, mas serão implementadas nas próximas versões.

## Backend conectado

O projeto usa o Supabase **Fôlego Dev** em São Paulo (`sa-east-1`). A URL e a publishable key estão em:

`lib/core/config/supabase_config.dart`

A publishable key foi feita para código cliente e continua limitada pelas políticas de RLS e pelas permissões do banco. **Nunca coloque `service_role` ou `sb_secret_...` neste projeto Flutter.**

## Como rodar

### 1. Instale o Flutter

Instale uma versão atual do Flutter com Dart compatível com o `pubspec.yaml` e confirme:

```bash
flutter doctor
```

### 2. Gere o runner nativo sem sobrescrever o código

**Windows / PowerShell:**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap_flutter.ps1
```

Esse script gera o Android em uma pasta temporária e copia apenas o runner nativo.

**macOS / Linux:**

```bash
./scripts/bootstrap_flutter.sh
```

No macOS, o script prepara Android e iOS sem substituir `lib/` ou `pubspec.yaml`. Depois ambos executam:

```bash
flutter pub get
flutter analyze
```

> Para compilar/publicar iOS é necessário um Mac com Xcode. O código Dart é o mesmo nas duas plataformas.

### 3. Execute

Com emulador/simulador ou aparelho conectado:

```bash
flutter run
```

## Configuração por `--dart-define`

A base já possui defaults do projeto de desenvolvimento, mas você pode substituir sem editar código:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

## Arquitetura

```text
Supabase Auth
     ↓
AuthGate
     ↓
Bootstrap
     ├── onboarding incompleto → OnboardingScreen
     └── onboarding completo   → HomeShell
                                  ├── Home
                                  ├── Transações
                                  ├── Plano
                                  ├── Carteira
                                  └── Perfil

Todas as regras financeiras ficam no backend.
Flutter → FolegoRepository → RPCs Supabase → Fôlego Engine
```

A interface **não calcula contabilidade**. Ela apenas envia intenção e apresenta o que o motor retorna.

## RPCs usadas pelo app

Leitura:
- `get_onboarding_state`
- `get_folego_snapshot`

Onboarding:
- `onboarding_create_account`
- `onboarding_configure_income`
- `onboarding_configure_recurring_expense`
- `onboarding_create_card`
- `onboarding_set_budget_item`
- `onboarding_complete`

Registro rápido:
- `register_expense`
- `register_income`

O backend também já possui operações de transferência, compra no cartão e pagamento de fatura para as próximas telas.

## Observação sobre confirmação de e-mail

No Supabase hospedado, confirmação de e-mail costuma estar habilitada. Nesta v0.1, após criar a conta o usuário confirma pelo navegador e volta ao app para entrar com e-mail e senha. Deep link nativo para retornar automaticamente ao Fôlego será configurado junto do polimento de Auth.

## Próximas versões

1. lista real de transações + filtros;
2. formulário completo de registro (PIX, débito, cartão, transferência, reembolso);
3. Carteira com contas, cartões, faturas e dívidas;
4. Planejamento + recorrências + orçamentos completos;
5. simulador **Posso comprar?**;
6. notificações;
7. RevenueCat / Free x Plus;
8. identidade visual final, ícone, splash e publicação nas lojas.


<!-- deploy-recovery 2026-09-24: republish canonical PWA branch after main overwrote GitHub Pages -->
