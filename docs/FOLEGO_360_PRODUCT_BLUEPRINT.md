# Fôlego 360 — independent premium product, not a clone

Status: product blueprint + first read-only, all-user Panorama 360 slice in a separate draft PR. This is NOT the app's production state, not a promise of installed Open Finance or certified AI advice, and not an authorization to turn on billing.

## Positioning

**Organize what happened. Plan what comes next. Know what can be spent safely.**

Official source review (2026-09-29):
- Organizze: https://ajuda.organizze.com.br/hc/pt-br/articles/6105543338771-O-que-%C3%A9-o-Organizze — accounts, cards, budgets, due alerts, custom categories, financial reports and optional banking connections. Current provider: https://www.organizze.com.br/
- Mobills: https://www.mobills.com.br/pricing/ — connected cards/accounts where available, monthly planning, financial goals, chart summaries and bill reminders.
- Fôlego: existing project-specific money semantics and features documented in this repository: safe-to-spend snapshot, mandatory outflows, protected balance, budget RPCs, goal contributions, card competence, cash-flow/nonexpense separation, recurring rules, statement-import staging, projections and role-aware financial spaces.

Use competitors as **feature research** only. No competitor source code, branded UI, copy, scraped customer data, privileged premium account access, reverse engineered private APIs or misleading "same premium features" claims.

## Product pillars and implementation sequence

| Pillar | Existing foundation in Fôlego | First integrated step | Later paid experience / hard dependency |
| --- | --- | --- | --- |
| Daily accounts/cards | Wallet, account/benefit separation, card invoices/payments, transactions, import staging | Link existing read-only monthly economics + spendable summary | Complete invoice/category UX QA, import duplicate triage and permission-safe automation |
| Monthly planning | Budget parents and subcategories, monthly/recurring flexible budgets | Panorama 360 summarizes existing parent-only budget totals; opens real budget editor | Comparative monthly chart, thresholds and explainable, user-approved rule engine |
| Goals and reserves | Savings goals and per-goal contributions | Panorama 360 shows active goals progress without treating contributions as liquid/invested cash | Goal funding schedule and low-risk forecast simulations with explicit assumptions |
| Future cash clarity | Server safe-to-spend snapshot, 30-day upcoming events, economic monthly summary | One privacy-aware, **read-only** Panorama 360 bringing four currently separate sources together | Explainable multi-month simulations, confidence/missing-data indicators and actionable recommendations |
| Banking/import | CSV/OFX staging and classification already exist | Make all new overview metrics consume canonical existing records | Open Finance only through consented, licensed intermediary with lawful contract and real per-user ongoing cost |
| Premium product | RevenueCat native integration skeleton, explicit paywall with no web billing | Keep Panorama core free for useful onboarding; premium = genuinely optional deeper insights | Sandbox purchase/restore/refund/revocation and true localized store prices must pass before activation |

## The first concrete deliverable

A new **Panorama 360** screen, accessible from Home as its own clearly labeled control:
- Total spendable until next income from **the existing server snapshot**, never recomputed from gross bank balance or by subtracting the same invoice twice.
- Explicitly separate **protected balance**; never call that balance "free to spend", and never treat goal contributions as bank deposits automatically.
- Current month's **economic income vs economic expenditure** from the canonical monthly-money RPC; credit card payments, transfers and investment movements remain cash movements, not a second expense.
- Parent-level category monthly budget summary only; never sum parent+children together.
- Active savings goals with target/progress, labeling contributions as *recorded toward the goal*, not proof of actual invested or safeguarded money.
- Nearest distinct upcoming pending outflows; do not add their total to the snapshot's mandatory-outflows figure because they may already be included.
- Partial failure/empty setup states (not fake zeros): a failed API cannot be interpreted as "no bills / no spending / no goals"; each section can be independently unavailable.
- Every query remains **financial-space scoped** and RLS-authorized. Changing spaces reinitializes loading and invalidates previous screen results. Privacy masking goes through the existing money formatter. No financial AI claims for deterministic metrics.

This slice intentionally requires no SQL migration, new customer data, bank access, browser instrumentation, notifications, third-party APIs or Premium charge. Backend/Flutter UI integration must pass static analysis + synthetic widget/unit testing before review. No direct connected Dev writes or deployment.

## Second microdelivery: comparable historical months (draft, not deployed)

This follow-up adds a read-only monthly comparison beneath the current-month
economic summary. It uses the same canonical `get_monthly_money_summary` RPC
**for the last TWO COMPLETED months** (e.g., in September compare July and
August, not incomplete September against complete August). Backend failures
and missing comparison periods remain **unavailable** rather than fabricated
zeroes. Verified months with no recorded movements receive a distinct
recorded-empty state; the UI never assumes all external bank activity has
been imported.

Metrics are the canonical `realIncome`, `competenceExpenses`, and
`economicResult` already used by the main dashboard. A card payment,
same-owner transfer or reserve movement cannot be added again as a new
expense. An absolute expense difference is informational, NOT an assessment
that the user spent irresponsibly and not a percentage when the baseline
month has no entries. Historical amounts listen to the global Fôlego
privacy-mask toggle and immediately hide when it changes.

This optional history fetch is financial-space scoped and read-only,
parallel to other queries. A missing historical response never suppresses
already verified current-month balances, budgets or goals. No banking
connector, client-side reclassification, new DB table, cron job or paywall
is introduced. Authentication/RLS and physical-device release gates from
the first slice remain mandatory.

## Third microdelivery: budget watch (draft, no notifications)

Reuse existing **RLS-scoped, current-month parent category budget rows**
from the Panorama 360's already-loaded budget overview. The watchlist
highlights up to three categories that have crossed each category's
configured warning threshold (or Fôlego's default 70% fallback). Sorting
prioritizes exceeded categories by actual recorded overspend, followed by
the nearest remaining limits. Zero/unconfigured budgets, children already
aggregated into parents and invalid negative/non-finite values cannot
trigger a false warning.

This is an **informational read-only comparison against recorded data**,
not a forecast, bank-sync claim, scheduled Push notification or advice
to change spending. An unavailable budget RPC returns an unknown state;
an empty or safely used budget returns no alert. Protected cash,
card-payment cash movement and goal contributions are not reclassified
or re-aggregated here. In global hide-values mode, both monetary amounts
**and progress bars** disappear immediately so masked values cannot be
inferred from precise percentage indicators.

The initial design keeps the watch inside the EXISTING Panorama budget
card, rather than adding new screens or requiring a separate setup.
Authenticated multi-space staging QA remains a release blocker.

## Fourth microdelivery: actually navigate to upcoming commitments

The existing Panorama linked its **“ver todos”** action beside upcoming
bills to the general Transactions page rather than the existing dedicated
Upcoming Events agenda. This is corrected to open the real calendar/agenda
for the SAME selected financial space. The compact preview now shows each
pending obligation's **actual due date** alongside its description and
amount; the view does not imply an overdue/paid status that the backend has
not confirmed.

This is a UI/navigation fix only: it creates no scheduled payment, edits
no recurring record, reclassifies no financial event, sends no push, and
does not issue a second network query to draw the preview. Synthetic
iPhone-sized interaction tests verify the tap; broader authenticated
multi-account staging remains an independent release blocker.

## Fifth microdelivery: safer migration from CSV exports (draft)

The existing Fôlego import wizard already supports **CSV/OFX staging,
source-account selection, per-row preview, duplicate review and explicit
confirmation**. Rather than create a second importer or claim direct
access to competitors' private APIs, this enhancement improves the
existing generic CSV column suggestions using **fictional** Brazilian and
English samples only:

- Recognizes common headers such as `Data da Transação`, `Histórico`,
  `Valor (R$)`, separate `Débito/Crédito` and `Saldo após transação`.
  A running balance remains optional metadata, never a new transaction.
- Selects unambiguous exact headings before less-specific alternatives.
  Duplicate, conflicting amount/date/debit candidates stay **unmapped**
  and require the person importing to choose the correct column.
- Does not confuse an installment amount, interest, fee or bank balance
  with the signed transaction value. Where both signed value and
  debit/credit columns exist, the unambiguous signed value takes
  precedence and is never summed twice.
- Blocks ambiguous automatic interpretation of a lone
  `1.234`/`1,234`: the importer explicitly requests a decimal
  locale instead of risking a thousand-fold amount error. The review
  screen explains how to resolve uncertain mappings.
- Preserves original staging, row classification, deliberate duplicate
  review and manual confirmation, with NO silent imports.

**Compatibility is generic, not certified against any specific
Organizze or Mobills export layout.** We have not accessed a Premium
account, copied an external service's schema, used private integration
endpoints or imported customer financial records. Authentic migration
support requires a separately consented, anonymized actual export
sample and source-specific tests. No customer file, login, access token
or financial figure belongs in the repository or CI logs.

## Sixth microdelivery: explicit credit-card CSV sign conventions

Some **generic** card CSV formats record purchases as negative signed
amounts; others use positive signed amounts. It is unsafe to treat all
positive card rows as payments or refunds. The **existing CSV mapping
wizard** now displays a card-only choice for signed-amount files:

- `Compras negativas (-)` preserves existing Fôlego behavior by default.
- `Compras positivas (+)` is an explicit opt-in per import, not an
  automatic guess based on a bank or competitor's alleged format.
- The signed convention adjusts the direction of **card rows only**.
  Split debit/credit columns, bank accounts, benefits and OFX parsing
  must never inherit this choice.
- A card refund and a card payment still require row-level review and
  never become income or a settled bill automatically just because the
  sign changes. The convention is included in the import's recorded
  mapping configuration.
- The wizard asks people to verify a known purchase during the
  **existing review step** before confirming anything. All initial
  implementation and UI tests use imaginary card transactions.

This is NOT certified against any actual Organizze, Mobills or bank
export. Vendor-specific migration requires a redacted sample and
express approval. No real invoices, external banking actions,
customer data or auto-posting are involved.

## What we deliberately do NOT ship as part of the first screen

- Silent bank sync / Open Finance or claims of equivalent institutional partnerships. Banking connectors have per-connected-account cost, provider and Central Bank compliance constraints; evaluate unit economics before offering at low price.
- Autonomous banking actions/transfers, automatic edits to financial data without consent, cross-household sharing by default or any use of another member's financial space.
- Hallucinated "AI recommendations", autogenerated financial balances from incomplete datasets, or opaque forecast ratings. Unknown source data stays unknown.
- New tab explosion or 30 competing settings pages: reuse existing Home, Transactions, Plan, Wallet, Goals and Premium navigation. Fôlego stays iPhone-first and accessible.
- Enabling a production paywall or changing the approved marketing price without an explicit decision. The R$9.90 draft correction PR and an optional R$12.90 proposal are **separate** from this product work.

## Acceptance criteria to unlock the next batch

1. Run all-user privacy and signed-session regression testing on fictional households; verify A cannot see B's metrics.
2. Compare three synthetic statements (account debit, credit card purchase/payment, own-to-own transfer) against the monthly economic total. A card invoice payment and a transfer must not double-count consumption.
3. Manual and CSV/OFX sources produce the same canonical calculations, and pending/ignored records do not masquerade as paid.
4. Run visual QA on iPhone compact/dark and web before any later deployment; use isolated staging before authenticated multiuser testing.
5. Prototype a paid differentiator only after usability tests show that the free Panorama reduces data-entry work and improves user understanding.

## Commercial perspective

The R$12.90 idea remains a **proposal**, not a configuration decision. Real app-store fees, taxes, support, refunds, cloud costs and *especially bank-connection charges* must be assessed before claiming profitability. An affordable plan with a bank-connection entitlement is not feasible to promise until provider quotes and sandbox results exist.
