# RevenueCat Test Store — Fôlego Android (pré-Play Console)

This setup is exclusively for local debug testing. Never upload this APK or its
Test Store public SDK key to the Google Play Console.

## RevenueCat dashboard (existing account)
1. Open the intended Fôlego project at https://app.revenuecat.com/.
2. Under **Apps and providers**, confirm/create a **Test Store** for this project.
3. Under **Product catalog → Products**, create or reuse one Test Store
   monthly subscription. Suggested test ID: `folego_premium_monthly_test`.
   Use monthly duration and a representative displayed price, e.g. R$9.90.
4. Under **Product catalog → Entitlements**, confirm the ID is **exactly**
   `premium`. Attach the Test Store product to it.
5. Under **Product catalog → Offerings**, create/confirm the **default** offering
   with the Test Store product as its **monthly** package. Configure and attach
   an active RevenueCat Paywall to this offering (the app invokes
   `presentPaywallIfNeeded('premium')`).
6. In **Project Settings → API keys**, locate the **public Test Store SDK key**
   (prefix `test_`). Never use a `sk_` secret key inside the Flutter app.

## GitHub Actions (no key in commits or chat)
Open https://github.com/caueccipriano/folego-app/settings/secrets/actions
and add a **repository secret** named exactly:
`REVENUECAT_TEST_STORE_PUBLIC_KEY`

Paste only the RevenueCat **public Test Store** key as the secret value.

Then open
https://github.com/caueccipriano/folego-app/actions/workflows/revenuecat-teststore.yml
and select **Run workflow**, branch
`release/revenuecat-teststore-20260925`.

After success, download the **folego-revenuecat-test-store-debug-apk** artifact
from that run. Artifacts expire after 7 days. Install the APK on a personal
Android test device (you can do that after 16:00).

## Test matrix (use a throwaway Fôlego account, no real financial data)
- Log in and open **Perfil → Fôlego Premium**.
- Confirm the Test Store disclaimer is shown, not a promise of a 7-day trial.
- Open the configured RevenueCat paywall and simulate success.
- Confirm the entitlement `premium` unlocks advanced features.
- Use **Restore purchases** and check the entitlement persists.
- Reinstall/sign back in with the same account; confirm access restoration.
- Simulate cancel/failure; check access is not granted.
- Wait for accelerated Test Store renewal/expiry and check access updates.
- Test Supabase-granted courtesy/lifetime separately.

The Test Store does **not** replace the Google Play sandbox. The real 7-day
trial, regional R$9.90 price, Play Billing, and subscription eligibility must
be verified later with Google Play Console subscription/base plan/offer and
licensed testers.

## Safety boundaries
- This workflow builds **debug APK only** when manually dispatched.
- Production/release builds reject keys starting with `test_`.
- No Test Store key is printed or committed by the workflow.
- The RevenueCat `sk_` secret must never go into Flutter, GitHub
  client builds, or chat.
- The existing production PWA and Google Play release workflow are unchanged.
