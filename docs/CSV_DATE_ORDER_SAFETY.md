# Fôlego 360 — safely importing CSV dates

Status: new unmerged draft, all test names and values are fictional. No
production import, deployment, user-data access or external provider session.

**Problem.** A transaction marked `09/10/2026` could mean 9 October in
DD/MM/YYYY or 10 September in MM/DD/YYYY. A silent guess can misplace a
card purchase, bill or refund into a different financial period and make
category budgets and economic month comparison inaccurate.

## New behavior

- Numeric **ISO dates** (YYYY-MM-DD) stay safely supported by automatic
  detection. The explicit ISO choice never silently accepts day-first data.
- A date where exactly one position can be a valid month is inferable:
  `14/09/2026` is DD/MM; `09/14/2026` is MM/DD.
  `10/10/2026` has identical interpretations.
- When both numeric fields could be the month, and differ,
  **automatic detection fails closed**. No importer row is staged just
  because another row elsewhere reveals its layout.
- The existing CSV mapping wizard scans **the entire selected date
  column** and prominently requests explicit DD/MM/YYYY or MM/DD/YYYY
  selection before calling the existing backend staging API.
  Deliberately reviewing this format resolves the warning. Invalid
  dates remain invalid.
- This applies to card, bank-account and benefits imports alike. It
  does not affect OFX transaction dates or the separately consented
  signed-card positive/negative purchase convention.
- The importer's existing source-account selection, category review,
  duplicate checks, staging and final confirmation remain mandatory;
  this change adds no SQL writes or proprietary provider integration.

## Verification and limitations

Dedicated synthetic unit tests check exact two-way interpretation, year
boundaries, ISO, invalid dates, complete-column preflight and mixed
fictional statements. A real Flutter iPhone-sized widget test verifies
that an ambiguous statement triggers a visible warning and refuses to
send the staging request until the user selects DD/MM/YYYY.

These are synthetic tests. Real provider CSV variants, scoped A/B
staging RLS, physical iPhone screen readers, end-to-end bill
competence and live app release remain separate acceptance gates.
No bank exports, credentials or actual finances belong in GitHub CI.
