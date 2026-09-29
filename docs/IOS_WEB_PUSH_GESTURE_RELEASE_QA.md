# Fôlego — iPhone Web Push user-gesture audit (all customers)

## Finding reproduced from source

Apple's [Web Push for Web Apps on iOS and iPadOS](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)
says that Push is supported on **installed Home Screen web apps** and
permissions must be requested following direct user interaction.
[Apple developer documentation](https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers)
requires the Push subscription method to start immediately within a gesture
handler; delaying it behind async service-worker or network preflights can
break the expected iOS behavior.

The original Fôlego flow had these async operations between Flutter's
tap and its call to the JS subscription function: local browser queue await,
getSubscription, current user's owner-status RPC and worker preparation.
This was an iPhone **release risk identified by code inspection**, not
evidence of a physically observed failure.

## Proposed change in this draft branch

- The bridge pre-registers/warms the service worker **without asking for
  notification permission**. A read-only browser probe and signed
  user+device recovery RPC finish before any user taps the subscribe CTA.
- A WebKit/Home Screen check refuses to prompt from a normal iPhone Safari
  tab. The app instructs users to install the PWA to the Home Screen first.
- A strict local queue starts the gesture callback synchronously if idle.
  A pending logout/rebind cannot postpone an iPhone gesture until its
  transient user activation is gone; the user gets a safe retry instead.
- The **first tap** calls \`Notification.requestPermission()\` directly,
  without starting a Push subscription or claiming success. The app refreshes
  permission and owner status afterwards.
- The **second tap** calls \`pushManager.subscribe()\` immediately from
  the gesture, using the pre-warmed worker. It only writes the resulting
  subscription when the signed-in account and JWT still match the
  prevalidated identity and the server's session-binding/RLS permits it.
- On a previously shared browser, B must first explicitly clear a
  different historical browser subscription, then tap again to create B's
  new independent endpoint. A previous owner's subscription is never
  silently inherited. Already owned legacy endpoints use PR #20's
  explicit owner-scoped rebind instead.
- A permission grant alone is never reported as "delivery active"; failed
  backend checks show retry/error states. Notification preferences and
  actual device subscription are kept visibly separate.

## Automated evidence vs actual physical testing

GitHub CI runs (1) Node browser mocks that reject permission/subscribe calls
outside the synchronous gesture, (2) Flutter queue and real notification
settings widget tests, (3) real WebKit **engine** Playwright tests using
iPhone-sized viewports with **fake serviceWorker/PushManager/Notification**.
These protect source-level timing and UI, but **do not exercise native iOS
permission dialogs, the installed iPhone PWA, actual APNs delivery or an
authenticated Supabase HTTPS staging project**.

## Required iPhone and two-account acceptance BEFORE any customer rollout

1. Authorize a separate HTTPS Vercel staging deployment and isolated
   Supabase staging database. The existing Vercel connector returned no
   authorized \`cipri-studio\` team and the connected Supabase Dev has no
   separate database branches. Never point synthetic end-to-end destructive
   tests at the connected project containing real financial data.
2. Install the staging PWA on the iPhone from Safari (Share → Add to Home
   Screen). A normal Safari tab should show instructions rather than a
   broken notification permission prompt.
3. Register **fictional user A** and check the first explicit tap opens
   the iOS permission dialog without prematurely showing device-ready.
   Grant permission and tap again; verify the second tap creates an A-owned
   server-session-bound endpoint and the UI confirms it only after an
   authenticated backend read.
4. Repeat on the same browser profile with **fictional user B**, without
   silently adopting A's previous browser Push permission or endpoint.
   Perform the explicit preparation tap if an A endpoint still exists,
   then the independent B subscription tap. Verify A retains their other
   legitimate device subscription.
5. Close the PWA, revoke A's server session, try delivery of a synthetic
   harmless test push and ensure only eligible sessions receive it.
   PR #18 checks \`auth.sessions\`, but timeout/refresh-token revocation
   behavior still needs a separate server-side session-lifecycle decision
   as recorded in issue #17.
6. Test denied permissions, offline startup, stalled service-worker warmup,
   token refresh during a tap, pending logout then fast B login, and old
   installed PWA caches. The browser should not falsely claim delivery.
7. Check the same user flow on Android, desktop and two WebKit device
   viewports; preserve an explicit consent model for each identity.
8. Only after all tests pass should PR #16 (client cleanup), PR #18
   (server-session dispatch), PR #20 (safe owner recovery), and this PR
   be reviewed as a single ordered rollout with old endpoint migration
   communications. Do not merge draft security PRs piecemeal.

**No live customer Push endpoints, real finances, VAPID private keys,
production cron schedules or linked Dev SQL were modified here.**
