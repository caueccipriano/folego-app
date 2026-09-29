# Fôlego 360 — consolidated release review

**State: DRAFT / NOT DEPLOYED / NOT APPROVED FOR CUSTOMERS**

This consolidated branch is for one end-to-end **code review** of the previously separate, stacked Fôlego 360 feature and multi-account safety changes. It does not itself configure store purchases, migrate the real Supabase Dev database, publish a Vercel preview or approve a product launch.

## Included code

The branch inherits these review-only changes in order:

| Review | Functionality | Evidence to inspect |
| --- | --- | --- |
| #16 → #18 → #20 → #21 | Browser Push logout cleanup, server-bound signed Auth session checks, owner-only legacy device recovery and direct iOS user-gesture prompts | GitHub Flutter/Deno/SQL/WebKit synthetic CI; native installed iOS and actual revocation still need staging |
| #22 | **Manual-only** authenticated fictional A/B staging gate and hard stop against the linked real-user Supabase Dev project | 15 synthetic guard tests green; authenticated manual job **NOT RUN** |
| #24 | Panorama 360 reads scoped server snapshot, economic monthly result, budget, goals and upcoming obligations | Flutter widget/unit and PWA preview CI |
| #27 | Last two **completed** economic months, distinguishing unavailable data from recorded zeroes | Regression Flutter/static analysis |
| #28 | Parent-level budget watch respecting each configured threshold and privacy mask | Widget/financial-semantics CI |
| #29 | Upcoming due dates and correct link to the selected space's upcoming agenda | Synthetic mobile widget, static and PWA CI |
| #31 | Safer generic CSV export field detection, ambiguous numeric-format blocking and manual duplicate review | 38 synthetic importer regression tests on isolated branch |
| #34 | Explicit signed-card purchase polarity opt-in, account/benefit separation and signed source remapping reset | 60 synthetic parser/mobile/regression tests on isolated branch |
| #23 **ported here** | Previously independently tested **R$ 9.90/month** proposed Premium display text, sensitivity planning and removed account-specific public documentation | New integrated Premium-price CI; actual app store products **NOT VERIFIED** |

None of these features is a licensed provider integration with Organizze/Mobills. The experience and code are original to Fôlego; actual third-party import layout compatibility has NOT been proven with a properly consented redacted provider export.

The last unambiguously approved **price to encode in launch marketing copy** is **R$ 9.90/month**. A later **R$ 12.90/month** amount was *proposed*, without an explicit approval to change existing configured charges. Store checkout must show the actual localized price from the relevant store and RevenueCat; a static text change does not configure billing. Do not claim a seven-day trial until store eligibility and entitlement behavior are verified.

## Completed versus blocked release gates

| Gate | Latest known verification and disposition |
| --- | --- |
| Cross-device simulated browser QA | Previously green on #34's exact earlier head; **rerun and validate the combined branch's exact SHA**. WebKit iPhone viewport is NOT a physical iPhone. |
| Canonical finance/PWA/code regressions | Previously green on #34's exact earlier head; run all triggered integrated CI after price port. |
| Generic CSV/carded signed purchase convention | Previously green on #34's exact earlier head; verify the same on integrated head and actual UI at least with fictitious card statements. |
| R$9.90 proposed price label and docs | Previously green independently on #23; newly ported into this integrated branch; run dedicated parity CI here. This is NOT store product activation. |
| Independently authorized HTTPS Vercel QA preview | **BLOCKED:** connected Vercel plugin last returned no authorized teams; `cipri-studio` was not granted. Never use a live-domain replacement for QA. |
| Separate Supabase project with NO real customer records | **BLOCKED:** linked Supabase Dev has no independent branches exposed. Creating a separate project may incur recurring costs; obtain owner approval before provisioning. NEVER aim the two-user A/B workflow at linked Dev. |
| Real Auth sign-in A/B and owner/viewer household isolation | **NOT EXECUTED**; #22 only hardens and unit-tests the staging guard. Seed two entirely fictitious accounts and verify signed-session reads/writes and privacy on separate staging. |
| Closed-PWA forced sign-out, Auth refresh/session timeout and Web Push delivery suppression | **OPEN issue #17**; existing synthetic checks cannot certify every real Supabase session-expiry/revocation configuration or APNs delivery race. |
| Installed physical iPhone PWA notification prompts, receipt and logout re-login | **NOT EXECUTED**; genuine home-screen-installed iOS tests still mandatory. Real signed physical Android acceptance similarly pending. |
| Actual sandbox iOS/Google native subscription, restoration, renewal, trial eligibility, expiry/refund | **NOT EXECUTED**; verify independent test storefront/RevenueCat environment, web billing remains locked and no actual purchase/refund occurs without consent. |
| Consent, retention and account removal including shared spaces | Needs final fictional multi-role account deletion/restore/retention and app privacy-policy review. |
| Live deployment, store publication and sending real notifications | **NOT AUTHORIZED**. Requires distinct approval after all independent runtime release gates pass. |

## Next exact actions in permitted order

1. Let this consolidated **draft** branch complete all targeted GitHub workflows on its own SHA. A green compiled PWA artifact is a downloadable build artifact, not a web preview or a native store release.
2. With the owner's explicit approval to create infrastructure or incur costs, reconnect/authorize Vercel `cipri-studio`, provision a new independent Supabase **synthetic-only** project and publish a separate `folego-qa-*.vercel.app` preview. Do not use the existing linked Dev project.
3. In a manually approved **staging-only** workflow, verify two signed fictitious accounts, independent and shared household roles, transfers, credit card sign/refund cases, duplicate imports, anonymous vs paid entitlements and server-bound Push revocation. Document precise success and failure behavior and refrain from logging tokens, imported transactions or personally identifying account data.
4. In the actual installed PWA on a physical iPhone, verify permission is started on direct touch, subscription is started on a second direct touch, A-to-B switching produces no cross-account delivery, an older user must explicitly recover a device and a revoked session causes NO new financial Push delivery. Test physical Android and flaky network/large fonts.
5. Review actual localized price and all store/RevenueCat products, store sandbox testing and refund/restore/trial rules; review all-user legal privacy copy, accessible screenshots, app ownership and store-review requirements. Obtain release authorization before migrations/merges/deployments.

## Commercial reality

At hypothetical **15% variable transaction fees** and **R$150/month operating cost**, 78 active subscribers paying R$9.90 would generate an illustrative **R$506.37/month** before taxes/refunds. This is not a projected outcome, and does not include possible extra Open Finance costs or true app-store fee rates. Avoid selling unlimited live bank connections under the R$9.90 plan until provider quotes and per-account costs are understood.

**Definition of 'development review ready'**: all combined-head synthetic and build checks green, no known code-only regressions and a documented list of runtime blockers. **Definition of 'publish ready'** is MUCH stricter: signed Auth multi-account staging, native devices, data privacy/deletion, product price/purchase and server session revocation passed and approved, with an explicit deployment authorization. Do not conflate them.
