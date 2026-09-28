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

## Security review — 2026-09-28 (read-only, Fôlego Dev)

Evidence comes from a fresh Supabase Security Advisor run and read-only PostgreSQL metadata/function-definition inspection. It does **not** certify an external attack test or production environment.

### Verified: 5 intentional server-only tables

The Advisor's five \`rls_enabled_no_policy\` informational findings cover:
\`ai_question_usage\`, \`financial_intelligence_usage\`, \`quanto_automation_config\`,
\`store_subscriptions\` and \`subscription_webhook_events\`.

For **each** of these five tables, verification found:
- RLS enabled, zero client-facing policies;
- \`anon\` and \`authenticated\` have no direct SELECT, INSERT, UPDATE or DELETE privilege;
- \`service_role\` retains SELECT privilege.

**Outcome:** These five findings are consistent with intentional server-only storage. Do not add permissive client policies merely to silence the Advisor. Retest grants and ownership after future migrations.

### Reviewed statically: 17 authenticated SECURITY DEFINER RPCs

All 17 findings have \`anon EXECUTE = false\`. All 17 contain a visible identity/authorization gate: 11 call \`private.can_write_space(p_space_id)\`, four call \`private.is_space_member(p_space_id)\`, and two use the authenticated user's own ID (\`consume_free_simulation\` and \`get_my_store_subscription\`).

**Important limitation:** The guards' presence is a static code check, not proof of tenant isolation. Functions run as \`postgres\`. Before release, test unauthorized cross-space READ and WRITE using *two fictional users and independent synthetic spaces*. Ensure denied calls leave events, balances, quotas, subscription entitlements and import rows unchanged. Do not change all functions to \`SECURITY INVOKER\` or revoke required client RPC grants in bulk: that would break the application.

### Confirmed commercial-control gap: projection simulation quota

As currently implemented, \`public.get_projection\` is directly executable by authenticated clients. It validates financial-space membership, **but does not read or decrement simulation quota**. The Flutter \`PurchaseScenarioService.simulate\` obtains the baseline and adjusted projections **before** calling \`consume_free_simulation\`. A signed-in user can therefore request their own adjusted projection RPC directly without consuming free simulations. This is a Premium entitlement/quota bypass, **not evidence of cross-account data access**.

**Release blocker before charging for Premium:**
1. Enforce a server-authoritative, atomic quota/entitlement check *within* every backend route able to return a paid simulated projection (including non-empty adjustments and any other paid scenario inputs); ordinary permitted baseline reads must continue to work.
2. Update Flutter to avoid counting one simulation twice, and do not debit a user's quota for invalid configuration or a failed server computation.
3. Test free quota exhaustion, Premium access, replay/concurrent requests, an adjusted direct RPC request, cross-space denial, and usage rollback after server error, using **fictional Dev users only**.
4. Do not expose a new unrestricted core projection RPC through PostgREST or GraphQL.

### Pending Auth configuration

The Security Advisor additionally reports **leaked password protection disabled**. Enable and verify this control in Supabase Authentication settings where supported by the project plan: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

### Release gate

- [x] Read-only privilege check for the five server-only tables
- [x] Static inspection of the 17 authenticated privileged functions and their public grants
- [ ] Two-user Dev authorization tests for the privileged RPC surface
- [ ] Fix and prove atomic server-side paid-scenario quota enforcement
- [ ] Enable and verify leaked-password protection
- [ ] Re-run security advisors and review any new warnings before production
