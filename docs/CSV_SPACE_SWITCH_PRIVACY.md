# Import wizard: financial-space changes during asynchronous operations

**Draft microdelivery.** Reuses the existing statement import UI. No
production deployment, new database migrations, third-party account
access or financial writes were performed while preparing this fix.

## Bug and precise protection

Flutter may retain a keyed StatementImportScreen State while its
authorized `spaceId` or underlying repository changes. Previously,
an A-space bootstrap or file-picker future could complete **after** the
route was reconfigured to display B. That could leave account or
filename choices from A visible in B's UI, or let B click a stale
import source. A late old staging response could also reopen A's
pending review under B.

This change tracks an **in-memory per-route epoch**. On any route
financial-space or repository change it:

1. Invalidates outstanding async callbacks from the old epoch.
2. Immediately clears the old file bytes/reference, column mapping,
   card sign confirmation, selected account/card/issuer, staged batch,
   pending/imported row view, search/filter state, account/card
   catalogs, category lists and previous result message.
3. Shows a fresh loading state and reloads only the currently selected
   financial space's catalogs.
4. Rejects future staging unless its source account/card ID is found
   among the currently loaded account/card choices; freezes the selected
   space before the staging call and rejects stale async responses.
5. Before issuing a deferred **confirm** after updating a batch,
   rechecks the epoch and stops if the route has changed. Cancel, picker,
   category callback and bootstrap results never mutate or navigate
   the new space using an old response.

Important nuance: a **server request already dispatched under the old
space before the user switched** cannot be magically rolled back. Its
space ID was captured from the old valid session at dispatch; only
backend RLS/ownership and idempotent, signed-session confirmation can
secure the server. The UI ignores such stale replies. Real A/B
authenticated staging tests are still required.

## Synthetic verification

Widget tests reuse the SAME keyed screen while switching fictitious
spaces A and B. One test resolves stale A's bootstrap after the switch;
a second resolves a pending A file picker after B has loaded. The
screen must display only B's available accounts and its separately
selected fake file, never A's filename/account or review rows.
Existing CSV date, card polarity, duplicates and statement-import
regressions are rerun in dedicated CI.

The independent HTTPS fake-user staging plan in draft PR #22 remains
a launch gate; no connected real-user Supabase Dev project can be used
for destructive cross-household tests. Real physical iPhone privacy
mode/switching and session revocation are separate release gates.
