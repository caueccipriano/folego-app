# Authenticated visual QA — setup and acceptance

This project has public cross-device Playwright tests and optional authenticated tests. Do not mistake a green public QA workflow for authenticated coverage.

## One-time isolated test setup
1. Create a **fictional** user in the Fôlego development Supabase project, using an email inbox you control and a new unique password. Never use a personal Fôlego account, real financial data or a production project. If signup requires email confirmation, confirm the test email using the normal development workflow.
2. Log in once to the development PWA and complete any mandatory onboarding with fictitious data. Seed a small set of synthetic transactions, a goal, a wallet account and a plan if required to expose the relevant screens. Do not insert SQL bypasses to RLS or use service-role credentials in browser tests.
3. In the GitHub repository Settings > Secrets and variables > Actions, create **repository secrets** `FOLEGO_E2E_EMAIL` and `FOLEGO_E2E_PASSWORD`. Do not paste credentials into issues, PRs, logs or this document.
4. Confirm that the QA Flutter build targets the **development** Supabase project and that the account is isolated. The secrets alone do not configure the Flutter app's backend URL.
5. Rerun the Cross-device Playwright QA workflow using Actions > Cross-device Playwright QA > Run workflow on the feature branch. Check the authenticated test results and screenshots for every project. Do not merge while authenticated tests are skipped.

## Visual acceptance
- Navigate through Início, Lançamentos, Plano, Carteira and Perfil on iPhone WebKit, Android Chromium, tablet and desktop, in available light/dark projects.
- Inspect screenshots for truncated currency, clipped filters, misplaced sheets, text hierarchy, contrast and visible error states. Browser emulation is not physical-device validation.
- The authenticated test asserts no document-level horizontal overflow and no uncaught page errors; **manual screenshot inspection is still required** for Flutter widget overflow, chart labeling and accessibility.
- Independently test onboarding, goals and premium flows with synthetic data; the current five-destination smoke test does not cover these.
- Record any failing device/screen with screenshot and reproducible steps; fix before release.

## Security checkpoint
Review Supabase security advisor warnings for authenticated-callable SECURITY DEFINER functions. Confirm intended exposure, explicit authorization and financial-space ownership checks in each function before changing grants. Some RLS-enabled tables intentionally have no client policies; review their intended server-only access rather than adding permissive policies automatically.

## Current limitation
If `FOLEGO_E2E_EMAIL` or `FOLEGO_E2E_PASSWORD` is missing, the authenticated suite is skipped. Public Playwright results cannot be represented as an authenticated visual audit.
