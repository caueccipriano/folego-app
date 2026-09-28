# Atomic projection quota — staged rollout and acceptance

Scope: Fôlego **Dev** and the simulator. No production deployment, payment
configuration, or personal financial data edits are part of this change.

## Why

The legacy Flutter purchase simulator ran baseline + modified
`public.get_projection` calls and **only then** called
`public.consume_free_simulation`. Any signed-in user with access to their own
financial space could call the modified projection RPC directly without
consuming the free simulation quota.

This is a subscription entitlement / API quota problem, **not** proof of
cross-user data exposure.

## Implementation

- Copy the currently deployed, space-authorization-checked
  `public.get_projection` engine into `private.get_projection_core`, revoke
  `EXECUTE` from `PUBLIC`, `anon`, and `authenticated`, and retain its
  original computation and identity checks.
- Replace the exposed function with a `SECURITY DEFINER`, space-checked,
  volatile wrapper. Ordinary no-adjustment baseline calls stay free.
- Adjustments and disabled variable income keys count as hypothetical
  scenarios. Prevalidate the JSON shape, atomically reserve quota through the
  **existing backend** `consume_free_simulation` RPC, then compute the result.
  The existing helper recognizes only verified store subscriptions or
  server-issued active complimentary/lifetime grants; no client entitlement
  flag can bypass it.
- Database errors roll back quota reservations. A computed result with
  `has_projection_inputs=false` refunds the provisional free reservation
  inside the same transaction. Successful metered scenarios return
  `simulation_quota_enforced=true`.
- Flutter recognizes that response flag and skips the separate legacy quota
  call; **older backend responses omit it**, so a new Flutter client continues
  to use the legacy quota on an unpatched backend. A new backend quota-denial
  error maps to a readable message.

**Remaining independent scope:** plain baseline long-horizon projections are
not a simulation and remain readable through the existing RPC. Separately
review server-side entitlement requirements if long-horizon baseline
projections themselves are a paid feature.

## Deployment order (important)

1. Merge the client/model compatibility patch only after CI passes, then
   deploy the **new client first** to the isolated Dev PWA and verify legacy
   free quota behavior against the still-old Dev RPC.
2. Apply `20260928174200_atomic_projection_quota.sql` on Dev using the
   Supabase migration workflow. Do not apply the SQL alone while old
   Flutter clients still call `consume_free_simulation`, or those clients
   may debit two simulations for one scenario.
3. Complete the authenticated, two-user acceptance tests below using only
   fictitious accounts / financial spaces. Verify no personal Fôlego data
   is touched. Check that failure cases do **not** alter quotas or balances.
4. Re-run Supabase security advisors and review exposed routine privileges.
   Static checks and a green Flutter CI run **do not** replace these tests.
5. Review the rollout with the repository owner before merging into the
   public release branch or enabling any live billing.

Do not deploy directly from this isolated fix branch: public GitHub Pages
should continue serving the separately authorized app version.

## Read-only database acceptance checks (after migration)

```sql
select
  to_regprocedure(
    'private.get_projection_core(uuid,integer,jsonb,text[])'
  ) is not null as private_core_exists,
  has_function_privilege(
    'authenticated','private.get_projection_core(uuid,integer,jsonb,text[])',
    'EXECUTE'
  ) as authenticated_can_execute_private_core,
  has_function_privilege(
    'anon','private.get_projection_core(uuid,integer,jsonb,text[])',
    'EXECUTE'
  ) as anonymous_can_execute_private_core,
  has_function_privilege(
    'anon','public.get_projection(uuid,integer,jsonb,text[])','EXECUTE'
  ) as anonymous_can_execute_public_wrapper,
  has_function_privilege(
    'authenticated','public.get_projection(uuid,integer,jsonb,text[])',
    'EXECUTE'
  ) as authenticated_can_execute_public_wrapper;
```

Expected: `true, false, false, false, true`.

## Authenticated behavioral acceptance — still required

Use two fictional users A and B with independent synthetic financial spaces.
For each test, inspect `financial_intelligence_usage` **using an authorized
server-side test connection only**; do not expose this table to browsers.

1. For free user A, baseline `get_projection` consumes zero attempts. Three
   modified `get_projection` calls return results with
   `simulation_quota_enforced=true`; the fourth direct adjusted RPC call is
   denied, without returning the computed projection.
2. Calls that disable a variable income (without numeric adjustments) also
   consume the same quota rather than opening a bypass.
3. A malformed adjustment array and a scenario with missing planning inputs
   do not consume an attempt. An internal computation error rolls back any
   provisional quota reservation.
4. A's call targeting B's space is denied **before** usage changes; no rows
   from B's data are returned. B's quota remains unchanged.
5. Concurrent requests on A's final remaining free attempt allow at most one
   successful response. Retries and denial do not increase usage beyond 3.
6. Grant a fictitious user test-only Premium in the backend: direct modified
   RPC calls remain available without consuming free usage; expired or
   revoked grants enforce the free limit again.
7. New Flutter + old backend: legacy fallback consumes **once**. New Flutter
   + new backend: response handshake skips the legacy call and consumes
   **once**. Test both before deprecating the fallback.
8. Validate normal Home baseline projection, planned items, imports and
   actual financial balances are unchanged.

Expected SQL migration precondition: the source
`public.get_projection(uuid,integer,jsonb,text[])` still has the
space-membership check and `has_projection_inputs` output. If its signature
or source has evolved, the migration fails closed rather than silently
cloning an unreviewed engine.
