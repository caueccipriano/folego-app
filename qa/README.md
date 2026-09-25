# Fôlego cross-device QA

This directory contains the browser-level QA layer for the Flutter PWA.

## What it checks

- iPhone-like WebKit at 393x852 and 390x844
- Android-like Chromium at 412x915 and 360x800
- Tablet at 768x1024
- Desktop at 1440x900
- Dark mode on iPhone 15 Pro, Android Pixel and desktop
- PWA manifest, service worker and viewport metadata
- Horizontal overflow after boot and resize
- Runtime page errors
- Automatic screenshots per project
- Optional authenticated navigation smoke test

## QA layers

1. **Flutter preflight** — breakpoints, auth widgets and responsive auth smoke at compact/wide sizes.
2. **Flutter web integration** — production deploy runs the public auth flow through `flutter drive` + ChromeDriver.
3. **Playwright** — WebKit/Chromium matrix across iPhone, Android, tablet and desktop before Pages upload.

The production workflow tests the exact `/folego-app/` artifact that will be uploaded. GitHub Pages is only reached after the browser gate passes.

## Run locally

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

## Screenshots and traces

Playwright writes screenshots, traces and failure videos to `qa/test-results`.
GitHub Actions uploads the QA artifacts for 14 days, so regressions can be
reviewed without an external browser service.
