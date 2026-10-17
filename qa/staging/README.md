# Fôlego — isolated staging QA (preparation only)

This folder does **not** deploy anything. The public Fôlego currently uses a linked Supabase environment containing real user data. The staging guard deliberately rejects **both** currently connected user-data project refs, the public GitHub Pages URL, arbitrary preview hostnames, any insecure URLs, and credentials embedded in URLs.

## Current state
- Pure Node test `node --test qa/staging/staging-guard.test.mjs` is run in GitHub Actions without network requests, cloud credentials or synthetic user creation.
- The two-user staging harness is a **separate draft**: GitHub PR #22, dependent on #18 (per-session authorization), #20 (prior-opt-in recovery) and #21 (direct iPhone push gestures). It has **not** been applied to the live server.
- No Supabase staging branch or separate fake-only project currently exists; staging setup could have costs. Ask for an explicit cost/permissions decision before creation.
- An active but unbound Push subscription must not silently be given to another account in the same browser. Never treat a green Node guard test as proof of secure revocation or real device delivery.

## When a standalone fake-only project is approved
1. Review any price or spend limit **before** creating it. Ensure it is not the existing Fôlego or Editalume project. Never copy live users, finance data, signing/VAPID secrets or subscriptions.
2. Use a dedicated HTTPS preview with an isolated Supabase URL and only a publishable key in the build. The default GitHub Pages target must remain unchanged.
3. Seed two independent synthetic Auth users with `+folegoqa@test.invalid` aliases, distinct passwords and fictional financial spaces. Never test by modifying real customer rows.
4. Run guard tests first; then follow draft PR #22's manual-only, approval-gated two-account integration workflow with genuine signed staging JWTs, including A/B isolation. Do not run a fake endpoint through a live Push sender.
5. Prove closed-PWA session revocation, old opt-in recovery and iPhone user-gesture restrictions before any customer migration. Keep unresolved risk in issues #17 and #19.
6. Require a human decision and migration/rollback plan for all currently registered devices before integrating drafts #18/#20/#21. Never disable old registrations merely to make a synthetic test pass.

## Limitations
- The static guard is defense-in-depth and cannot *verify* an actual project is fake-only. This is only established by provisioning permissions and an isolated-data acceptance test.
- GitHub Actions's routine CI runs **offline synthetic guard tests only**. It does not create environments, send Push, touch billing or make calls to the staging URL.
- A browser emulator does not substitute for installed iPhone/APNs or signed multi-device Auth revocation acceptance.
