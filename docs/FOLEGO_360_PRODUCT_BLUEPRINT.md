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

## Second read-only slice: last three months

This separate stacked draft adds a compact **three-month economic trend** to Panorama 360, sourced by the existing `get_monthly_money_summary` RPC for the selected space. It makes no new transfers, account syncs or customer edits.

- The two previous months load concurrently with the existing current month's canonical result; each month's API error remains **unknown**, never reported as zero.
- Each card visualizes the same official `realIncome` and `competenceExpenses` definitions. Card bill payments, reserve movements and internal account transfers are cash movements, **not another expense**.
- Data is displayed oldest-to-current and accepts valid cross-year boundaries. An unexpected month in a response is rejected rather than appearing in the wrong comparison period.
- The spending change against last month appears only when **both** current and immediately prior months were returned. An incomplete current month is explicitly flagged and must not be interpreted as a forecast or a guaranteed saving.
- Three months are enough for a useful first comparison without requesting full transaction history; later rich trends can be paginated and optional. Existing financial-space RLS still applies.
- The original Home screen and Panorama have no new payment gate here. Paid insights will be designed after validation that free users understand the baseline.

Acceptance: standalone synthetic Dart model tests (including legitimate zeros vs network failures and card bill non-double-count), a scrollable Flutter widget test with an absent historical period, static analysis, existing economic/budget/goal regression suite and independent multiuser staging before any deployment.

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
