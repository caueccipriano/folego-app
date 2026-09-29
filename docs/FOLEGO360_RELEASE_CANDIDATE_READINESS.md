# Fôlego 360 — review candidate, not a production release

Last reviewed: 2026-09-29. This is the single status page for the integrated
read-only financial UI, opt-in import protections and proposed Premium
**R$9.90/month marketing copy**. Do not announce this branch as a released app.
No billing, production migrations, actual customer finance queries, branch
merges or deployment were performed in constructing this review candidate.

## Integrated review code

- Original five-source Panorama 360 financial overview (safe-to-spend vs
  protected cash, economic month summary, parent-only budgets, registered
  goals and next pending obligations), then comparisons of TWO completed
  months, category budget watch and correct upcoming-agenda navigation.
- Generic CSV header recognition, manual handling of ambiguous money/date
  columns and decimals, original staging/deduplication/confirmation unchanged.
- **Explicit and unselected** signed card purchase polarity is required
  before staging positive/negative card CSVs; changing the signed source
  column resets the choice. Separate debit/credit columns, ordinary account
  and benefit imports remain unaffected.
- R$9.90 approved working marketing display copied from the isolated draft
  price PR; no RevenueCat/off-platform native product change. R$12.90 was a
  *proposal*, not an authorized production price.
- Added previously separate price-parity CI to this branch. The prior
  signed-card branch head passed 7/7 workflows including preview artifact,
  device-sized Playwright and Flutter integration; **the integrated branch
  must pass its OWN full CI** before any code-review green claim.

## Still BLOCKS any public rollout — do not silently skip

- [ ] **Independent HTTPS staging:** Vercel connector still lists no
  accessible teams, and the previously connected Supabase Dev contains
  existing finance accounts without an independent accessible test branch.
  Do NOT use Dev with fictional destructive test runs. Set up an explicitly
  approved dedicated staging backend and locked-down HTTPS Vercel preview
  with fake Auth A/B and synthetic financial-space fixtures; price any
  potentially billable resources before creation.
- [ ] **Authenticated multiuser acceptance:** run the gated PR #22 test
  workflow for distinct fake owners/viewers, cross-tenant RLS, imported
  transactions, push owner recovery, shared-device A/B transitions, logout,
  revocation and closed-PWA behavior. Existing local SQL/widget/engine
  tests are NOT proof of actual staging Auth and device isolation.
- [ ] **Physical iPhone and Android acceptance:** installed Home Screen PWA,
  genuine Web Push APNs permission/subscribe, real logout/revocation, slow
  network and reinstallation; Linux Playwright WebKit is not a real iPhone.
- [ ] **Server-side financial Push revocation:** issue #17 remains open.
  Production Auth session presence alone may not cover all refresh-token
  revocation/time-out models. Fail closed on unsupported session events.
- [ ] **Existing Push opt-in migration:** issue #19 requires real-person
  recovery UX review before any live migration could disable historical
  subscriptions. Never silently enroll a new account into a prior device's
  subscription.
- [ ] **Full chain review:** upstream security drafts #13, #15, #16,
  #18, #20–22; the feature drafts #24, #27–29, #31 and #34 and separate
  original price PR #23 need conflict review, migration sequencing,
  ownership model acceptance and protected branch approvals. This review
  branch is stacked; it does not merge any PR or deploy by itself.
- [ ] **Real sandbox purchase billing:** R$9.90 is a marketing target
  only. RevenueCat offering and store-native localized price, 7-day trial
  eligibility if adopted, Apple/Play purchases, restore, refund, expiration
  and secure backend webhook events must be explicitly configured/reviewed.
  Never promise that setting a Flutter label changes a store charge.
- [ ] **Marketing and product verification:** competitor-inspired features
  are an independent Fôlego implementation, not Organizze/Mobills Premium
  access or a clone. Real CSV provider layouts and Open Finance integration
  remain unverified until separately consented provider testing.

## Final controlled go/no-go sequence

1. Confirm the complete integration SHA is green for CI and exact target.
2. Authorize an independent staging backend and HTTPS preview with approved
   estimated costs, no production cookies, bank links or customer data.
3. Apply reviewed staging-only migrations and run all genuine signed-session
   fake-account/device and payment-sandbox acceptance checks.
4. Resolve #17/#19 safety cases and cross-user QA before any real Push
   dispatch or rollout.
5. Inspect preview on real iPhone/Android, then request a specific user
   sign-off for merge, migrations, any production deploy and payment
   activation. Execute those operations only after that approval.

**Current state: review candidate code assembled; not launch-ready.**
