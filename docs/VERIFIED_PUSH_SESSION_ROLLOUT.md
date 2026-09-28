# Fôlego: server-verified Web Push for **all users**

Branch: \`fix/server-bound-push-sessions-20260929\`. No code in this
branch was deployed to the linked Supabase Dev or production databases.
**The linked Dev project currently has four active Web Push endpoint rows.**
Applying this migration would mark ALL old, unbound endpoints disabled until
their owner re-registers using their own currently authenticated browser.
Plan user-facing re-enablement instructions and notifications maintenance
before any migration.

## Confirmed original problem

Both \`folego-push-dispatch\` and \`folego-daily-summary\` previously
retrieved \`web_push_subscriptions\` directly for a \`user_id\`, with no
proof that the browser's **specific Auth session** still belonged to that
user or even existed. Browser Push subscriptions belong to physical browser
profiles, so changing the signed-in person is a privacy-sensitive event.

The client-only mitigation from draft PR #16 can unsubscribe on logout or
when an open PWA detects a changed identity. It **cannot** execute when a
session is revoked while the PWA/browser is closed.

## Proposed server behavior

1. New \`web_push_subscriptions.session_id\` and \`session_bound_at\`
   fields. A \`BEFORE INSERT/UPDATE\` trigger derives \`session_id\` from
   the server-validated, signed \`auth.jwt()->>'session_id'\` claim for
   authenticated clients; checks \`auth.sessions(id,user_id,not_after)\`
   under a private \`SECURITY DEFINER\` function. A user-supplied
   \`session_id\` cannot override it. A different user cannot claim an
   active endpoint via ordinary RLS upsert. A service-role worker may still
   update last-delivery metadata and disable invalid endpoints.
2. Legacy, unbound endpoint rows are explicitly disabled; **do not**
   silently infer a live session from \`user_id\` alone.
3. New \`public.get_active_web_push_subscriptions(p_user_id)\` is only
   executable as \`service_role\`; a server query joins the endpoint to
   a *present*, matching, non-\`not_after\`-expired \`auth.sessions\` row.
   An expired, removed or mismatched row is **never returned**.
4. BOTH Edge senders use this RPC and **never fall back** to the original
   raw subscription table. Any lookup error, missing migration or
   malformed result fails closed before a financial push can be sent.
   Each device is checked again right before calling the external Push
   provider. This limits—but does not make impossible—a race with
   revocation during a network send.
5. Synthetic PostgreSQL tests reproduce the original problem before the
   migration and check legacy suppression; A and B's isolated sessions;
   fake session claims and wrong-user ID rejection; live A1/A2 and B;
   expiration of A1 without breaking A2; closing/removing A2's session;
   and B remaining unaffected. Deno tests simulate missing RPC,
   malformed data, DB failures and mid-send session removal.

## Known session-lifetime limitation (public launch gate)

[Supabase's Auth sessions guide](https://supabase.com/docs/guides/auth/sessions)
documents that JWTs contain a signed \`session_id\` and can be correlated
to \`auth.sessions\`. Some timed-out sessions may **remain in the table
for up to 24 hours after expiration**. The migration checks
\`auth.sessions.not_after\` where available, but this column does NOT
necessarily express an inactivity timeout or all refresh-token
revocations. Therefore **the presence of an auth.sessions row alone is
not sufficient evidence of immediate revocation for every Auth mode**.

This pull request is a security improvement, not a complete guarantee of
immediate suppression after every possible remote revocation. Verify
real Auth session deletion timing, password reset/global logout,
single-device logout, inactivity timeouts and refresh-token revocation
with *independent, fictitious staging accounts*. If session row retention
creates a gap, add an independently server-managed, per-device push
revocation/lease registry with explicit lifecycle invalidation; do not
mark [issue #17](https://github.com/caueccipriano/folego-app/issues/17)
resolved until the full test matrix passes.

## Safe implementation/deployment order

- [x] Source inspected; current schema supports Auth JWT \`session_id\`,
      \`auth.sessions(id,user_id,not_after)\`, and existing user-owned
      push rows. No customer's endpoint/keys were retrieved.
- [ ] Review real database schema, current session behavior and
      availability of the server maintenance window.
- [ ] Ensure customer-facing PWA can re-register **only with existing,
      previously granted browser notification permission** after the
      migration; do not trigger a permission prompt without user action.
      Older PWA tabs may need to be reloaded. Keep ordinary logout
      cleanup from PR #16; prevent A/B auto-registration races.
- [ ] Pause both cron dispatchers during the maintenance window.
- [ ] Deploy **both fail-closed Edge functions first**. Until the new
      RPC exists they will refuse to send, prioritizing customer privacy
      over notification delivery.
- [ ] Apply versioned SQL migration in a *separate, fictional staging
      project*, then refresh authorized synthetic device endpoints.
      Existing legacy rows are disabled; never transfer subscriptions
      between identities by reusing endpoint keys.
- [ ] Test both dispatchers with service role and explicit synthetic
      candidate content; test a former owner's now-revoked session
      while the PWA is **closed**. Test session expiration while rows
      are still present, plus absence from auth.sessions.
- [ ] Confirm real notification UX and expected temporary suppression;
      make an opt-in refresh/migration communication plan for the four
      existing active Dev endpoints before any rollout.
- [ ] Deploy to Dev only with authorized change approval and synthetic
      endpoint tests that do not deliver customer financial content.
      Re-run security advisors and verify RLS, RPC grants and cron logs.
- [ ] Production only after App Store/Google Play/PWA acceptance and
      privacy tests. Preserve rollback procedures that do not reactivate
      **unverified legacy subscriptions**.

**Important:** there is deliberately no endpoint key, VAPID secret, real
JWT, email or bank data in this migration, fixture, CI or documentation.
