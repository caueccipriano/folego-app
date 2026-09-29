# Fôlego 360 — integrated QA matrix (review-only draft)

This document separates **written code**, **automated synthetic tests** and
**real-user launch acceptance**. Passing any unit or browser-viewport CI is
not an authorization to use customer records or publish the app.

## September 29 verified PWA checkpoint

- The original Fôlego 360 chain remains **draft / review only**. The follow-on
  [PWA polish branch #49](https://github.com/caueccipriano/folego-app/pull/49)
  was **separately** published for exploratory use at
  https://caueccipriano.github.io/folego-app/ by GitHub Pages. This is NOT
  authorization for the stacked chain's general-customer rollout.
- Supabase **Dev** financial-ai function v4 is active with the CORS preflight
  patch (an OPTIONS request was verified as HTTP 204); real authenticated
  end-to-end AI responses have not been independently demonstrated.
  Server quota is currently a single-account private beta.
- #49 contains merged [PR #50](https://github.com/caueccipriano/folego-app/pull/50):
  pending AI requests are invalidated on a selected financial-space,
  repository or Auth-identity change; old-user responses are never shown in
  the newly selected space and invalid input has explicit error styling.
  Its exact PR #50 financial-intelligence, preview, integration, repository
  hygiene and cross-device CI checks passed on the tested commit.
- [Full combined Fôlego 360 acceptance](https://github.com/caueccipriano/folego-app/actions/runs/36620174972):
  **154** synthetic Flutter tests passed; full static analysis, browser Push
  regressions and the release-verdict job passed on the integrated source.
- Independent fictional HTTPS Supabase staging/Auth A/B, real installed
  iPhone/Android + closed-session Push revocation, backend all-user Premium
  quotas, store sandbox payments and external approval are still required.
  A green deployment log proves browser-shell publishing, not a secure
  public financial service launch.

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
- This integration patch: add PR #39's separately green **closed-month matched parent-category differences** to the R$9.90 consolidated QA candidate, with an extra privacy guard hiding **category names and direction** while values are masked. The new tests are part of the SAME integrated Flutter CI gate.
- Existing combined QA: run previously independent money, import, price and Push browser synthetic contracts **on the SAME integrated commit**.

The integrated release chain remains in draft GitHub branches. No isolated
Supabase production migration, general-user rollout, native store distribution
or release acceptance has been performed. The separately published #49
GitHub Pages beta described above is not a production release certificate.

## Synthetic versus real acceptance

| Domain | Automated evidence expected in combined CI | Independent real acceptance still required |
| --- | --- | --- |
| Financial totals | Canonical month and Panorama regression cases | Fictional Auth A/B sessions, independent spaces, deliberately shared household roles; real PostgREST RLS |
| Statement migration | Fictional CSV amount/date/card sign parsing (including direct-parser opt-in), explicit UI decisions, staged duplication and async A→B financial-space route isolation tests | Redacted consented samples for each *actual* claimed bank/app format, independent staging import writes and authenticated A/B cross-account proof |
| Premium | Display regression for approved R$9.90, web checkout locked | Apple/Google store pricing, RevenueCat offerings, purchase, refund, renewal and restore with synthetic sandbox accounts |
| Device Push | JS browser two-tap/owner-recovery and Flutter UI contracts | Genuine installed physical iPhone Home Screen PWA, APNs/Android delivery, expired/revoked sessions while app closed |
| Responsiveness | GitHub cross-device synthetic Playwright workflow | Actual older small iPhone/Android and accessible large-font/dark-mode review |
| Account deletion | Prior isolated role/server regressions in draft branches | End-to-end owned/shared fictional space deletion and recovery decisions, approved support runbook |

## Reconciled synthetic safety branches (still not physical staging)

The other independently green release paths were separately based on
conflicting import/date implementations. The current consolidation
**preserves PR #44's full-file locale evidence and user-facing warnings**
while porting the isolated protection implemented in drafts
[#38](https://github.com/caueccipriano/folego-app/pull/38)
and [#40](https://github.com/caueccipriano/folego-app/pull/40):

- Direct signed-card CSV parser calls must carry an explicitly selected
  purchase-sign convention; no longer default silently to negative purchases.
  The original UI selection and separate debit/credit account imports remain.
- A reused Flutter importer route **immediately clears** financial-space A
  file/account/row state when showing B; stale asynchronous A bootstrap,
  picker, stage, confirmation and cancellation responses are discarded by
  a guarded route epoch. **Already dispatched server writes are NOT canceled**
  by a local widget check, so signed-session and RLS staging are mandatory.
- The two-closed-month category analysis is integrated with the exact
  approved R$9.90 marketing display and now hides categories/direction
  **and** amounts while the privacy mask is enabled.

Both the new fictional A/B widget tests and direct parser default-deny
case have been added to the combined Flutter CI. Their latest exact-head
result must be verified before review. Real authenticated multiuser,
actual cross-device browser and closed-PWA Push revocation remain separate
release gates. Standalone category draft #47 is an alternative and must
NOT be merged on top of this integrated implementation.

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
