# Fôlego cross-device QA

This directory contains the browser-level QA layer for the Flutter PWA.

## What it checks

- iPhone-like WebKit at 393x852 and 390x844
- Android-like Chromium at 412x915 and 360x800
- Tablet at 768x1024
- Desktop at 1440x900
- PWA manifest, service worker and viewport metadata
- Horizontal overflow after boot and resize
- Runtime page errors
- Automatic screenshots per project
- Optional authenticated navigation smoke test

## Run locally

Build the Flutter app with a root base href first:

```bash
cd folego_flutter
flutter build web --release --base-href "/"
cd ../qa
npm install
npx playwright install chromium webkit
npm test
```

## Authenticated smoke test

Never commit credentials. Use environment variables locally or GitHub Actions
secrets:

- `FOLEGO_E2E_EMAIL`
- `FOLEGO_E2E_PASSWORD`

Without them, authenticated tests are skipped while all public QA remains
mandatory.

## Screenshots

Every test run writes screenshots, traces and videos to `qa/test-results`.
GitHub Actions uploads them as artifacts so mobile/desktop regressions can be
reviewed without an external browser service.

CI note: every push to the QA branch runs this matrix before promotion.
