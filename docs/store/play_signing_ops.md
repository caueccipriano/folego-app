# Fôlego — secure Android upload signing (prepared; not yet distributed)

## State
- The upload-key signing patch and GitHub Actions dry-run are ready for testing.
- Do not run the commercial signed job until the final Premium candidate contains
  all latest production fixes and is reviewed.
- The real signed job refuses to run while this GitHub repository is public.
- Before making this repository private, migrate **both** the live PWA and legal
  documents to hosting that remains publicly reachable after the change.
- A throwaway CI signing key validates compilation but can never be used for a
  real Play upload or a later update.

## Permanent Play upload key
Create **one long-lived upload keystore locally**, following the official Flutter
documentation. Keep encrypted offline backups: Android updates need continuity
of signing identity or a controlled upload-key reset. Never paste it in chat
or commit it to GitHub.

Reference: https://docs.flutter.dev/deployment/android#sign-the-app

Once the final integrated branch and account are ready, register these
GitHub **repository secrets** from a secure session:

| Secret | Purpose |
|---|---|
| `PLAY_UPLOAD_KEYSTORE_BASE64` | Base64 contents of the permanent upload keystore |
| `PLAY_UPLOAD_STORE_PASSWORD` | Keystore password |
| `PLAY_UPLOAD_KEY_ALIAS` | Permanent upload-key alias |
| `PLAY_UPLOAD_KEY_PASSWORD` | Upload-key password |
| `REVENUECAT_GOOGLE_PUBLIC_KEY` | App-specific RevenueCat **public** Google Play key (`goog_`) |

Do not use the RevenueCat Test Store `test_` key or RevenueCat secret `sk_`
keys for a commercial build.

## Pipeline
The dry-run action compiles an Android release bundle using a disposable key
and fake public RevenueCat configuration. It does not upload an artifact.
This tests the signing **process**, not actual Play Billing.

The manual commercial build:
1. Refuses to run if repository visibility is public.
2. Checks that all five secrets exist and the public SDK key has a `goog_` prefix.
3. Creates the native Flutter shell and ephemeral signing inputs on the runner.
4. Signs the AAB with the permanent upload key.
5. Checks the resulting AAB's JAR signature.
6. Retains the signed AAB for only one day and wipes temporary signing files.

Only dispatch the signed workflow from the **final reconciled native Premium
branch**, not from this isolated preparation branch if other fixes were added.

## Still required outside code
- Independent PWA + legal hosting is live before changing repo visibility.
- Correct Play Console app registration and verified developer account.
- Store product/offer actually published: product and base plan monthly at
  R$ 9,90, introductory trial of seven days where eligible.
- RevenueCat entitlement `premium` and correct Google Play offering mapped.
- Real Play sandbox transaction, cancellation and restore tests.
- Google Play data safety and financial-features declarations reviewed on the
  *final* binary; support address confirmed and responding.
- Hands-on Android device acceptance, including changing accounts and offline
  behavior.

Official Flutter signing reference:
https://docs.flutter.dev/deployment/android

RevenueCat official Test Store boundary:
https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store
