# Fôlego — two independent fictional accounts, without risking any customer data

**Status: harness proposed and unit-tested in draft PR; HTTPS provider and an
independent Supabase project are not connected or configured yet.**
This file documents what can actually be validated after the required
infrastructure and sample data exist. Do not treat a synthetic CI test as
physical iPhone/APNs testing.

## Why this is separate

The existing Supabase Dev project holds actual financial user data, and its
connected plugin currently lists **no independent database branches**. The
Vercel integration still shows **zero authorized teams** and returns an
authorization error when querying \`cipri-studio\`. Running deletion, login
rotation, import writes, cross-account Push and subscription lifecycle tests
there would be unsafe.

The standard GitHub Pages preview is also tied to a previously deployed build
with the **linked Dev Supabase project**. It is not a staging environment for
destructive or authenticated synthetic multiuser tests. The standalone PWA
build artifact is only a static file; downloading it does not provide an
isolated backend.

## What to set up (one-time, requires your approval)

1. Reconnect the Vercel plugin and explicitly grant access to the
   \`cipri-studio\` workspace, **or** manually create a separate Vercel
   project called \`folego-qa-...\`. Never assign the existing live Fôlego
   domain to it.
2. Create an independent, dedicated Supabase project that contains **only
   fabricated financial data and fake accounts**. A Supabase branch or project
   can incur cost depending on your subscription. Confirm any costs first.
   Do NOT link a different frontend to the currently connected real-user Dev
   project simply to make tests pass.
3. Review the migrations in the current feature/PR stack, apply them in order
   only to this independent project and keep all notification cron senders
   disabled until an approved dry run. The Push provider keys should be
   synthetic/staging-only; do not copy VAPID private keys or payment secrets
   from any real project.
4. Deploy a separate Vercel preview under
   \`https://folego-qa-....vercel.app/\` by building Flutter with **both**
   staging-specific Dart compile-time values:
   \`--dart-define=SUPABASE_URL=https://[dedicated-ref].supabase.co\` and
   \`--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_[staging-key]\`.
   Publishable keys may appear in browser code; passwords/service-role keys
   must never be compiled into the PWA. Configure Vercel to serve the
   \`folego_flutter/build/web\` output with a real HTTPS hostname.
5. **Seed only fictional data:** make user A and user B with different
   \`+folegoqa\` email aliases and passwords in the staging Auth database.
   Confirm their accounts, then use the app to create a distinct owned
   financial space for each. Add to A's space at least one fake account,
   category, financial event, and import batch+staged row. B must not be a
   member of A's space for these independent-user tests. A's Push
   registration must use the exact fake endpoint
   \`https://push.synthetic.invalid/fixture-A\`, authorized by A's currently
   active signed session. Do NOT attempt delivery to that fixture endpoint.
6. In GitHub, configure a dedicated \`folego-qa-staging\` environment with
   approval/restricted access if supported. Add only the following secret
   values there (never paste them into PRs or chat):
   \`QA_STAGING_SITE_URL\`, \`QA_SUPABASE_URL\`,
   \`QA_EXPECTED_STAGING_PROJECT_REF\`,
   \`QA_SUPABASE_PUBLISHABLE_KEY\`, \`QA_FAKE_A_EMAIL\`,
   \`QA_FAKE_A_PASSWORD\`, \`QA_FAKE_B_EMAIL\`,
   \`QA_FAKE_B_PASSWORD\`, and \`QA_FAKE_A_PUSH_ENDPOINT\`.
   Require personal review before running authenticated tests.
7. Once the workflow has been reviewed and is available for manual
   dispatch, start **Isolated two-account staging safety gate** with the
   exact confirmation \`I_CONFIRM_ISOLATED_FAKE_PROJECT\`.
   PR checks intentionally run only synthetic Node guard tests; they
   cannot accidentally run live A/B requests.

## Hard-stop guard and exact assertions

The guard rejects the linked real-user Supabase project, GitHub Pages,
non-HTTPS sites, non-\`folego-qa-*.vercel.app\` preview hosts, mismatched
project references, reused test identities, non-fake-marker email aliases
and any Push endpoint other than \`https://push.synthetic.invalid/...\`.
A required explicit \`ISOLATED_FAKE_USERS_ONLY\` acknowledgement must be
present. The guard NEVER logs test emails, passwords, JWTs, Push keys or
endpoint values.

The dedicated Playwright run then verifies all of the following using
independent, actual staging Supabase Auth **signed user JWTs**:

- The HTTPS preview's actual compiled \`main.dart.js\` includes the
  designated staging project reference and **does not** contain the
  known real-user Dev project reference.
- A and B can independently sign in and see at least one independently
  owned financial space; neither can see the other's unshared space.
- A reads real synthetic fixture rows in Accounts, Categories,
  Financial Events and Import Rows. B tries to retrieve those **exact
  space IDs** through direct PostgREST, bypassing the Flutter UI, and
  must receive no rows or a legitimate authorization denial.
- With A's fake endpoint seeded, A's owner-scoped Push RPC returns
  \`owned_active\`, B's exact same endpoint lookup returns
  \`new_device\`, and B's signed JWT cannot invoke the service-only
  raw-device-key RPC.

If a fixture is missing, a table RPC is not installed, the app was compiled
for Dev, permissions are wrong or the preview host is unauthorized, the
test **FAILS**. A missing user account or skipped browser suite is never
reported as a successful customer security audit.

## Still required after the first green staging run

- WebKit and actual **installed physical iPhone** permission prompt,
  subscribed-device persistence, push receipt and denied-permission UX.
  Playwright's iPhone viewport cannot replicate native iOS/APNs consent.
- Explicitly shared A household and B Viewer acceptance, including
  own-only edits and safe membership removal, with no real account deletion.
  Draft SQL fixtures cover role separation, but staging still needs real
  signed-session acceptance.
- Closed PWA and global/session-timeout revocation: Supabase may retain
  session rows in some timeout modes. Observe actual staging session
  lifecycle; if the server fails to promptly suppress revoked devices,
  issue #17 remains launch-blocking.
- Stripe/RevenueCat/App Store/Play purchase/restore/refund, safe owner
  account deletion and subscription price alignment require their own
  reviews. Never use real payment details for QA.

**No production-domain changes, Dev SQL migrations, actual finance
modifications or customer push sends are permitted by preparing this PR.**
