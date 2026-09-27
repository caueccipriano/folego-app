# RevenueCat launch gate — Fôlego
The `revenuecat-webhook` Edge Function is deployed to Supabase **Dev** with JWT verification disabled **only** because it independently authenticates the RevenueCat Authorization bearer header. It fails closed while `REVENUECAT_WEBHOOK_SECRET` is missing. Do not put this secret in Git, app builds, or logs.

## Before enabling billing
1. Generate a long random webhook secret and set it in Supabase Dev Edge Function secrets as `REVENUECAT_WEBHOOK_SECRET`.
2. In RevenueCat dashboard, configure a webhook with URL `https://ycumrvkwqizlnehelhek.supabase.co/functions/v1/revenuecat-webhook` and header `Authorization: Bearer <same secret>`. Limit to the appropriate RevenueCat project/environment.
3. Confirm the app's RevenueCat App User ID is the authenticated Supabase user UUID before any purchase. Anonymous or aliased identifiers are deliberately ignored by this webhook.
4. Run sandbox lifecycle tests: initial purchase, renewal, cancellation (should retain access until expiry), expiration, refund, duplicate deliveries, out-of-order events, invalid authorization, and cross-account identity. Check `store_subscriptions` and the simulator's server-side quota. Use test accounts only.
5. Configure store products, entitlement `premium`, trial availability, localized pricing and policies in RevenueCat and the stores; confirm purchase/restore behavior on actual iOS and Android builds.
6. Only after these checks, deploy reviewed migrations and webhook to production. Never copy Dev secrets or enable live billing as part of a QA run.

## Known limitations
- Cancellation intentionally leaves an existing entitlement active until expiration.
- Only verified store events are stored in `store_subscriptions`. Client-side premium status alone cannot bypass server quota.
- Webhook event identity and entitlement mapping must be tested with real RevenueCat sandbox payloads before release.
- The `get_projection` RPC remains separately callable; this quota protects the simulator path, not every possible projection invocation.
- This feature branch and PR remain unmerged; no production release is implied.
