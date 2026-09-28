# RevenueCat launch gate — Fôlego
The `revenuecat-webhook` Edge Function is deployed to Supabase **Dev** with JWT verification disabled **only** because it independently authenticates the RevenueCat Authorization bearer header. It fails closed while `REVENUECAT_WEBHOOK_SECRET` is missing. Do not put this secret in Git, app builds, or logs.

## Approved launch offer
- Brazil monthly Premium target: **R$ 14,90/month**. Configure the actual store products and RevenueCat offering to this price before enabling checkout. The Flutter display label alone does not set or guarantee the store charge.
- Confirm that the store paywall shows the exact localized price, renewal interval, trial eligibility and cancellation terms; never assume the displayed in-app marketing price overrides the store.
- The web/PWA preview currently has no native checkout. Do not advertise active web purchases until a separate verified web billing integration exists.

## Before enabling billing
1. Generate a long random webhook secret and set it in Supabase Dev Edge Function secrets as `REVENUECAT_WEBHOOK_SECRET`.
2. In RevenueCat dashboard, configure a webhook with URL `https://ycumrvkwqizlnehelhek.supabase.co/functions/v1/revenuecat-webhook` and header `Authorization: Bearer <same secret>`. Limit to the appropriate RevenueCat project/environment.
3. Confirm the app's RevenueCat App User ID is the authenticated Supabase user UUID before any purchase. Anonymous or aliased identifiers are deliberately ignored by this webhook.
4. Run sandbox lifecycle tests: initial purchase, renewal, cancellation (should retain access until expiry), expiration, refund, duplicate deliveries, out-of-order events, invalid authorization, and cross-account identity. Check `store_subscriptions` and the simulator's server-side quota. Use test accounts only.
5. Configure store products, entitlement `premium`, trial availability, localized pricing and policies in RevenueCat and the stores; confirm purchase/restore behavior on actual iOS and Android builds.
6. Only after these checks, deploy reviewed migrations and webhook to production. Never copy Dev secrets or enable live billing as part of a QA run.

## Commercial launch targets

- Approved Brazilian monthly price: **R$ 14,90**, subject to exact store price confirmation.
- Income objective: **at least R$ 500/month after payment fees and operating expenses, before personal taxes**. This is a planning target, not guaranteed earnings.
- Example sensitivity: with **15% variable fees** and **R$ 150 monthly fixed costs**, **52 active paying subscribers** produce R$ 658.58 net before taxes (52 × 14.90 × 0.85 − 150). Actual store fees, taxes, refunds and infrastructure costs must replace these assumptions before publication.
- Instrument conversion from free to Premium and monthly cancellations; use observed data rather than promising a conversion rate.

## Release acceptance — evidence required

| Gate | Evidence | State |
| --- | --- | --- |
| Financial ownership separation | Automated wallet test + Dev account-level reconciliation | Dev reconciliation and automated test completed; current build pending CI |
| Responsive UI | Flutter analyze, web build, Playwright and authenticated physical iPhone screenshots | Automated run pending; physical authenticated iPhone review outstanding |
| Price parity | Store monthly products, RevenueCat offering and localized native paywall all show R$ 14,90 | Not configured or verified |
| Billing security | Webhook secret installed in Dev; reject invalid bearer; server-only entitlement and quotas verified | Not verified end to end |
| Subscription lifecycle | Sandbox purchase, restore, renewal, cancellation, expiry, refund, duplicate/out-of-order delivery | Not verified |
| Store compliance | Privacy policy, account deletion, subscription disclosures and store metadata reviewed | Requires review |
| Production release | Explicit approval after evidence above; separate production migration and webhook review | Not authorized |

Do not enable real billing, mark launch-ready, or merge the feature branch merely because CI passes. The GitHub Pages PWA does not have native in-app purchases.

## Known limitations
- Cancellation intentionally leaves an existing entitlement active until expiration.
- Only verified store events are stored in `store_subscriptions`. Client-side premium status alone cannot bypass server quota.
- Webhook event identity and entitlement mapping must be tested with real RevenueCat sandbox payloads before release.
- The `get_projection` RPC remains separately callable; this quota protects the simulator path, not every possible projection invocation.
- This feature branch and PR remain unmerged; no production release is implied.
