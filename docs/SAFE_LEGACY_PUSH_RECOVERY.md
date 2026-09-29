# Fôlego — preserve prior opt-in without handing another person's device to a new account

This is a **customer-wide** migration experience: the browser grants
notification permission to a physical device, but **a Supabase Auth account
owns a financial Push subscription**. Those are not the same thing. A
browser that previously belonged to A must never silently enroll B.

## Safe end-user experience

The historical four active subscriptions on the connected Dev project are
not touched by this branch. The preceding **draft PR #18** intentionally
disables unbound legacy subscriptions during its future session-bound
migration. Disabling is a privacy safeguard, not evidence of a user
explicitly opting out. This follow-up proposes a safe manual recovery path:

1. The browser bridge exposes a **read-only** probe that calls
   \`getSubscription()\` only when browser permission is already granted.
   It never prompts, calls \`subscribe()\` or creates a worker.
2. New \`public.get_my_push_device_recovery_status(endpoint)\` checks
   the **currently authenticated signed JWT session** against
   \`auth.sessions\`. It returns only a coarse status for the EXACT
   endpoint and the exact \`auth.uid()\`: \`owned_rebind\`,
   \`owned_active\`, \`new_device\` or \`not_eligible\`.
   All other people's endpoint URLs and keys stay private.
3. The notification settings screen checks eligibility read-only.
   **Nothing is reactivated automatically**, even if browser permission
   remains granted from another person's use of the device.
4. If a legacy row is owned by A, A sees **Reativar meus alertas**. A
   deliberate tap updates only A's matching record; PR #18's
   server-side trigger binds it to A's current verified Auth session.
   The UI verifies that the server now reports \`owned_active\`
   before claiming success.
5. If B opens the same browser, B never sees A's rebind action. B sees
   **Ativar neste dispositivo** and must explicitly tap. Only then does
   the client unsubscribe the stale browser endpoint (if present),
   subscribe a fresh one and register B's own newly signed session.
   It cannot steal A's endpoint through RLS or UNIQUE conflict.
6. Local browser mutations (cleanup, restore, explicit enrollment)
   use the same \`PushBrowserOperationQueue\`, ensuring an already
   scheduled logout cleanup finishes before later registration.
   Requests recheck current user ID before server writes.

No new permissions or financial-data access is granted solely because a
browser has saved a permission.

## Critical deployment sequence

**Do not merge/deploy PR #18 alone.** PR #18 provides session-bound
registration and service-only verification. This follow-up adds the
owner-status RPC, client and review UX. Combine the reviewed migrations
in their defined order when promoting to a dedicated staging project.

1. Deploy a client build with a **graceful missing-RPC state** before
   server migration. If safe ownership cannot be verified yet, the app
   must not present a restore action or claim a failed browser setup
   succeeded.
2. Pause both cron senders. Deploy BOTH fail-closed Edge functions from
   PR #18; these will return errors / suppress delivery until their RPC
   exists. Confirm operational monitoring.
3. Apply the PR #18 migration, followed by
   \`20260929103000_owner_scoped_push_recovery_status.sql\` from this PR.
   The older, unverified subscriptions are disabled; nothing is
   transferred or deleted.
4. Test same-account A manual restoration, same-browser new-account B
   explicit opt-in and unrelated second-device continuity on a
   **disposable, fictional staging project**. Repeat with old PWA tabs,
   network failures, changed passwords, and a revoked session while
   the browser is closed.
5. Send a clear one-time explanation to all affected customers that a
   tap may be needed to restore reminders. In connected Dev, four
   endpoint records were active at the original audit; do not send
   any real customer push during tests.
6. Run Auth/RLS advisors, native/PWA integration and all release CI,
   then obtain separate approval before touching the linked project
   containing actual user data.

## Unresolved privacy guarantees

Browser code cannot run while the PWA is closed. The PR #18 delivery
gate checks a matching \`auth.sessions\` row and the optional
\`not_after\` expiration, but some Supabase timeout/revocation modes
can retain rows temporarily. Verify actual closed-browser revocation
behavior across Auth modes as tracked in [issue #17](https://github.com/caueccipriano/folego-app/issues/17).
No green synthetic test alone closes that release blocker.

A same-owner browser endpoint can be reauthorized explicitly with a
different authenticated session; it must not be silently treated as
still active under the former session. A missing migration, network
failure or mismatched JWT fails closed.

Tests are entirely fictional (PostgreSQL 17, Node browser mock, Flutter).
No existing endpoint, customer account, stored permission or financial
record is changed by preparing this PR.
