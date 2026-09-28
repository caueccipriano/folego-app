# Fôlego — safe account deletion for every customer

**Scope:** protect accounts in shared financial spaces and allow ordinary
self-service deletion of personal and non-shared household data. Existing
database rows and real customer accounts must not be deleted to validate this
feature.

## Verified risk, before the fix

The live Dev schema currently has
\`public.financial_spaces.owner_id -> auth.users ON DELETE CASCADE\`;
almost every financial table then has \`space_id -> financial_spaces ON DELETE
CASCADE\`. The former \`delete-account\` Edge Function independently deleted
all automation rules authored by the signed-in user before calling Auth Admin
\`deleteUser\`. Deleting a household owner could therefore erase a second,
still-active member's financial space and rules, even if the member had not
consented. A failed subsequent Auth deletion could also leave rules removed.

The *read-only aggregate* Dev check at the time of review returned **zero
owned spaces with other members** and **zero household spaces**. This is a
future-customer release blocker, not evidence of existing customer data loss.

## Defense in depth

1. **Client confirmation:** the account-deletion confirmation explicitly
   warns the owner when a space is shared. A backend 409
   \`shared_space_requires_resolution\` shows a specific explanation
   directing them to resolve ownership with support, instead of a generic
   failure. A 503/unknown error remains a failure; no account is deleted.
2. **Fail-closed Edge preflight:** after \`auth.getUser\` establishes the
   authenticated subject, service-role lookup joins \`space_members\` to the
   *owner's own* \`financial_spaces\` and searches for a **different**
   \`user_id\`. At least one other member returns 409; a failed/malformed
   lookup returns 503. The endpoint never trusts caller-supplied user IDs.
3. **Authoritative database trigger:** a \`BEFORE DELETE ON auth.users\`
   trigger checks the same ownership relation within the Auth deletion
   transaction. This blocks alternate service-role deletion paths and closes
   the gap between preflight and actual deletion. It raises SQLSTATE 23514
   with \`shared_space_owner_deletion_requires_resolution\`.
4. **Atomic rule cleanup:** the trigger moves all deletion of
   \`automation_rules.created_by\` into the **same SQL transaction** as
   \`auth.users\` deletion. An Auth failure automatically rolls back the
   associated automation-rule deletion. The Edge Function must NOT perform
   separate rule cleanup before calling Auth.

This does not automate transfer of account ownership or grant consent to
erase another person's financial data. Until a vetted transfer/remove-member
flow exists, users blocked by shared ownership need an operational support
process. **Replace the placeholder \`[SUPPORT_EMAIL]\` before public launch**
and define who can authorize ownership transfer versus permanent deletion.
Never require a blocked customer to give up account access credentials to
support staff.

## Safe rollout order (no live changes in this PR)

1. Confirm Supabase migration permissions, existing FK names/actions,
   current custom triggers on \`auth.users\` and active subscription/email
   configuration in the target environment.
2. Run CI in disposable Postgres first, then validate SQL under the
   *isolated staging project's* actual auth schema and roles. Do not run
   destructive Auth-delete SQL against a project holding real records.
3. Temporarily disable the account-deletion action or place it into a
   reviewed maintenance window while upgrading the server. **Apply the DB
   trigger first**, then deploy the new Edge Function and Flutter error UI.
   The old Edge Function's separate rule cleanup must never remain deployed
   long-term with the new DB trigger.
4. Smoke-test with **fictional staging users** and explicitly synthetic
   household membership:
   - A sole owner: own account, space and owned rules deleted.
   - B shared owner + C member: B delete rejected with 409; all B/C data
     unchanged.
   - C exits voluntarily: C's own account and authored rules are deleted,
     but B's account/space/remaining rules survive.
   - After C's membership ends, B can delete the now-private space.
   - A different, unrelated D never loses any data.
   - Invalid/expired JWT returns 401; preflight query failure returns 503.
   - Validate unrelated auth creation, login, password reset and logout.
5. Re-run Supabase security advisors and check actual function logs for
   service errors without logging JWT, bank values or user email. Confirm
   Web Push subscription cleanup and ensure a deleted or signed-out user's
   notifications cannot surface to another user of the same device.
6. Only after independent approval, schedule production rollout; keep the
   database migration, Edge Function and client version identifiers together.

## CI proof boundary

\`supabase/tests/shared_space_delete_before_fix.sql\` reproduces the
unprotected previous behavior in a **rollback-only synthetic fixture**.
\`20260928231500_guard_shared_owner_account_deletion.sql\` and
\`shared_space_delete_acceptance.sql\` test actual trigger behavior:
blocked B deletion, preserved C data, failure rollback, sole owner
self-service deletion, member exit and eventual former-owner deletion.

\`shared_space_safety_test.ts\` separately checks Edge fail-closed decisions
for blocked, clear, failed, thrown and malformed lookups. Flutter targeted
test checks the customer-facing 409 explanation and backend/SQL contract.

These are regression tests, **not** proof that the deployed Dev/production
Edge Function was replaced or that actual customers' account deletion
journeys were tested. No migration or function deployment occurs in this PR.
