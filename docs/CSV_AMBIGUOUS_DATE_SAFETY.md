# CSV import dates — never guess between DD/MM and MM/DD

Status: **draft review only**, not merged, deployed or validated using
real customer exports. Builds on the previous generic CSV and card-sign
drafts.

## Why it matters

A fictional row dated `05/06/2026` could mean **5 June** in Brazilian
DD/MM notation or **6 May** in US MM/DD notation. Assigning the wrong
month would distort Fôlego's cash-flow, card-period competence,
category budgets and monthly comparisons. The CSV importer therefore
**must not silently choose a format** for ambiguous dates.

## Defined behavior

- With `CsvDateFormat.auto`, an ISO `YYYY-MM-DD` date is accepted.
  A date like `26/09/2026` is unambiguously DD/MM and `09/26/2026`
  is unambiguously MM/DD. Equal month/day pairs (`05/05`) yield the
  same date in either convention, so remain valid.
- An unequal pair in which **both numbers are 1–12** is ambiguous.
  Before staging **any** row, the parser rejects the file with an
  actionable message asking the user to select **DD/MM/AAAA** or
  **MM/DD/AAAA** in the existing mapping wizard. The app does not
  guess from the device locale or from one row of the file.
- The user may choose the date format **once per import**, and it
  applies to every imported row, never one silently inferred format
  per transaction. Impossible dates still fail instead of rolling
  into another month.
- This check executes in the local parser **before** the existing
  staging callback. It neither writes financial records nor
  bypasses category/card/deduplication/manual confirmation checks.
  The earlier explicit card purchase-sign and decimal-locale
  requirements remain unchanged.
- The mapping screen explains date ambiguity beside the existing
  decimal-locale guidance.

## Limits and validation

Only fictional day/month samples, existing account/card/benefit import
fixtures and Flutter widget tests are used in CI. This does not
certify any particular Organizze, Mobills or bank export layout.
The existing dated JSON and OFX parser branches are outside this
CSV-only behavior change. Any real export sample must be redacted
and explicitly consented before a provider-specific compatibility
claim. Multiuser signed-session staging, physical phones and the
separate server push revocation launch gate remain outstanding.

Do not add real user balances, provider credentials, customer
transaction contents or live import batches to this repository.
