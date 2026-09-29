# Fôlego 360 — integrated QA matrix (review-only draft)

This document separates **written code**, **automated synthetic tests** and
**real-user launch acceptance**. Passing any unit or browser-viewport CI is
not an authorization to use customer records or publish the app.

## Consolidated review scope

The latest stacked draft integration starts with:
- PR #24 original read-only Panorama 360 (current disposable/server-sourced
  balance, economic movements, budget, goals, upcoming commitments);
- PR #27 completed-month comparisons that cannot double-count card invoice
  settlement or count goal contributions as a bank deposit;
- PR #28 parent-only category budget watch, with precise values AND progress
  indicators hidden under the global privacy mask;
- PR #29 upcoming event due dates and correct agenda navigation;
- PR #31 generic fictitious CSV mapping and safe money locale handling;
- PR #34 mandatory signed credit-card CSV purchase polarity consent;
- PR #44 no guessed DD/MM vs MM/DD monthly competence;
- PR #45 approved R$9.90/month **marketing label only**, with no billing.
- This PR: run previously independent money, import, price and Push browser
  synthetic contracts **on the SAME integrated commit**.

The work remains in draft GitHub branches. Neither isolated Supabase
migrations nor a real public deployment have been made through this
integration.

## Synthetic versus real acceptance

| Domain | Automated evidence expected in combined CI | Independent real acceptance still required |
| --- | --- | --- |
| Financial totals | Canonical month and Panorama regression cases | Fictional Auth A/B sessions, independent spaces, deliberately shared household roles; real PostgREST RLS |
| Statement migration | Fictional CSV amount/date/card sign parsing, explicit UI decisions, staged duplication tests | Redacted consented samples for each *actual* claimed bank/app format, independent staging import writes |
| Premium | Display regression for approved R$9.90, web checkout locked | Apple/Google store pricing, RevenueCat offerings, purchase, refund, renewal and restore with synthetic sandbox accounts |
| Device Push | JS browser two-tap/owner-recovery and Flutter UI contracts | Genuine installed physical iPhone Home Screen PWA, APNs/Android delivery, expired/revoked sessions while app closed |
| Responsiveness | GitHub cross-device synthetic Playwright workflow | Actual older small iPhone/Android and accessible large-font/dark-mode review |
| Account deletion | Prior isolated role/server regressions in draft branches | End-to-end owned/shared fictional space deletion and recovery decisions, approved support runbook |

## Blockers outside this PR

1. The Vercel connector still returns **no authorized teams**, so an
   independent HTTPS `cipri-studio` Fôlego QA preview is unavailable.
2. The connected Supabase project is Dev with user data and no isolated
   branch. Do not use it for fictional authenticated A/B destructive tests.
   A dedicated isolated staging project could be billable and requires
   explicit cost approval.
3. The real cross-account/session/physical-device matrix in GitHub
   issue #14 remains open; server session Push revocation issue #17 remains
   open.
4. The idea of R$12.90 was a proposal, not a configured product price.
   Do not enable payment products without an explicit, verified approval.

## Safe next operation

After the user authorizes the independent Vercel workspace and the cost
of a separate Supabase QA project (if any), set up synthetic-only HTTPS
staging per `docs/ISOLATED_TWO_USER_STAGING_QA.md`. Run its manual
`folego-qa-staging` gate with separate fake identities; keep all native
billing and real Push senders disabled until their own accepted test plans.

**Do not label this QA matrix a production launch certificate.**
