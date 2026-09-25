# Fôlego v1 — consolidated QA candidate

Created on 2026-09-25 to validate the premium v1 candidate against the current responsive PWA branch.

This branch has a merge commit with both `feat/transactions-recurring` and `release/folego-v1` as parents. It is intentionally separate from both branches and is **not production**.

## Validation gate
- Flutter analysis and stable regressions.
- Chromium and WebKit cross-device UI checks, including mobile viewport.
- Free/Premium entitlement, recurring billing and projection tests.
- Android/iOS release compilation on the release branch, not implied by this QA branch.
- Real RevenueCat/Play Store payments and account verification must be validated with store credentials and sandbox transactions before publishing.

## Integration checks
The merged result currently prefers the premium-release implementation for six files concurrently modified in both branches; this is an intentional test candidate, **not proof that the mobile layouts are correct**. Validate each affected surface. Preserve the current live PWA until the QA gate is green.
