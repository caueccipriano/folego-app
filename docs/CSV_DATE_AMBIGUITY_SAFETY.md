# Fôlego 360 — conservative CSV date interpretation

Status: **draft code + synthetic tests only**. No actual bank/account statement,
customer data, authenticated Dev access or deployment.

A file containing `03/04/2026` alone does **not** tell us whether the date
is 3 April (DD/MM) or March 4 (MM/DD). Importing the same charge into the
wrong calendar month corrupts competence-based budgets, card invoices and
historical comparisons even when the amount itself is correct.

## What changes

- Check **the entire selected date column** before producing any financial
  import candidates. Accept auto detection only with decisive evidence from
  that same column (e.g. `27/09/2026` + `03/04/2026` is DD/MM;
  `09/27/2026` + `03/04/2026` is MM/DD).
- If all relevant dates are ambiguous, or the file mixes mutually
  incompatible conventions/ISO with slash dates, fail closed with a
  **clear Portuguese prompt** asking the user to choose or review the
  source's date convention. The existing manual date selector handles both
  DD/MM and MM/DD. An explicit choice overrides automatic detection, but
  invalid/impossible rows still fail.
- ISO-only dates remain fully automatic. Equal day/month dates such as
  `03/03/2026` are safe without selecting a convention.
- Changing which CSV column represents the date reevaluates **that newly
  selected column**, so evidence from another date column cannot silently
  decide the sign-off. All selected financial-space, account, card-sign,
  original source-data, review, deduplication and final confirmation
  boundaries remain unchanged.
- Both a parser test suite and a real **phone-sized Flutter widget**
  exercise the user journey: no staging request until unambiguous evidence
  or an explicit date-format selection. Additional existing CSV/OFX import
  contracts and cross-device PWA workflows still run.

## Limits

This is **vendor-neutral**; no actual Organizze or Mobills export layout has
been inspected. Do not make compatibility claims without an explicitly
consented, fully redacted sample. The tests are synthetic; a real signed
A/B test on an independent Supabase staging project, device/Push revocation
tests and actual store purchase integration are separate launch blockers.

No database schema change, scheduled operation or commercial billing setting
is included in this draft.
