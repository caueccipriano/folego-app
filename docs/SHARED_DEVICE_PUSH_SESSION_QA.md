# Fôlego — privacy of Web Push on a shared browser/iPhone PWA

Scope: general customer safety, not one individual's notification settings.
No real endpoint tokens, financial notifications or other customers' data are
included in these tests.

## The gap

The browser Push API subscription belongs to the **browser profile/device**,
while \`web_push_subscriptions\` stores a user_id against the endpoint
(\`endpoint\` has a global UNIQUE constraint). The normal Profile logout
previously unsubscribed before calling Supabase Auth logout; however the
bootstrap error screen and first-run onboarding called \`auth.signOut\`
directly, without removing an existing browser subscription. A later sign-in
by B on A's physical device could therefore leave A's push subscription
active. A push delivery to that shared device might reveal A's financial
notification even if B never acquired permission to query A's tables.

This is a **risk from source inspection**, not evidence that any existing
user received another person's financial push.

## Proposed defense (draft PR)

1. \`SessionNotificationCleanup.signOut\` orders browser/Web Push cleanup
   **before** Auth signOut while the old signed-in identity can still remove
   their own endpoint row through existing RLS.
2. Profile, bootstrap error and onboarding logout use the same helper.
3. \`AuthGate\` also requests best-effort local browser unsubscribe on app
   launch **without a session**, unexpected \`signedOut\` and direct A-to-B
   identity switches. This covers forced logout and stale PWA storage
   paths that cannot initiate the normal helper.

**Security limitation:** unexpected logout occurs after the old JWT is gone,
so it can unsubscribe the browser locally but cannot authenticate to delete
the previous user's server-side push record. A closed/inactive app also
cannot execute a local cleanup when an Auth session is revoked elsewhere.
Before general release, push delivery should be tied to each registered
device's **currently valid auth session**, with server-side invalidation on
revocation, logout and account deletion; do not rely solely on these client
fixes to claim cross-device privacy. The cleanup adapter currently catches
browser failures to avoid trapping someone in their account.

## Required staging acceptance with fictional accounts

- A grants notifications in a shared browser. A uses Profile logout;
  browser Push subscription is removed and A's endpoint DB record is
  removed **before** the JWT is revoked.
- Repeat with the *bootstrap error* logout and *first-run onboarding*
  logout. Confirm both call the same cleanup and perform no anonymous
  cross-user write.
- A's account is force-signed-out/expired while the PWA is open; verify
  browser unsubscribes even if the Home-shell registry has been disposed.
- Reopen an old signed-out PWA: browser unsubscribes before a new person B
  registers notifications. B's new registration must be B-owned; no
  notifications from A are shown.
- Regression test A/B switch without explicit signout and verify token
  refresh for the same person does NOT clear their subscription.
- Simulate loss of network and a rejected browser unsubscribe: ordinary
  logout still works, but mark push privacy as **unverified** unless server
  session invalidation is effective.
- Test delivery to a device whose owner has revoked the Auth session
  **while the browser is closed**. This remains a release blocker until the
  push-dispatch backend verifies device session validity.
- Ensure a normal logout from one device does not inadvertently disable
  notifications on a person's other registered devices.

No connected Supabase data, VAPID private keys or live user endpoints are
accessed by the proposed branch. Flutter unit tests validate sequencing and
route wiring only; run authenticated PWA integration on separate physical
devices before claiming the full risk resolved.
