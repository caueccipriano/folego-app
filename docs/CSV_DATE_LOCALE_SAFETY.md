# Fôlego 360 — date locale safety for generic CSV imports

**Draft only. No live imports, third-party Premium accounts, Dev database
migrations or production changes are authorized by this work.**

The previous generic CSV parser assumed `DD/MM/YYYY` for a date such as
`03/04/2026`. For an export using `MM/DD/YYYY`, that changes the
transaction date, which can move card purchases into the wrong period and
incorrectly influence cash-flow reports, budget comparisons and invoices.

## Rules

- If the CSV field begins with a year (`2026-04-03`) in automatic mode,
  its date is unambiguous.
- If a `day/month`-looking value has one component above 12
  (`16/04/2026` or `04/16/2026`), automatic recognition can choose
  the only calendar-valid convention. If both components are the same
  (`04/04/2026`), either convention produces the same date.
- If both components could be months **and differ**
  (`03/04/2026`), automatic interpretation is **rejected** for the
  entire file. The user must choose `DD/MM/AAAA` or `MM/DD/AAAA`.
  The mapping wizard warns proactively when it finds ambiguous samples
  in the selected date column. No provider or country is assumed.
- The chosen date format applies to every row. A mixed-format export
  with an impossible date under the chosen format is rejected rather
  than silently selecting different conventions per row.
- Parsed local dates continue using the existing financial-space
  timezone and date-only normalization; this update introduces no
  financial event modification or second expense.
- The existing ambiguous monetary separator, source-column ambiguity,
  credit-card signed-amount opt-in, staging/duplicate review and
  explicit confirmation remain intact.

## Coverage and what remains

Synthetic parser and compact-phone widget tests assert that ambiguous
dates cannot create a staged batch while automatic recognition is
selected and that deliberately choosing the correct date format
allows reviewable fictional candidates. Prior statement, credit-card,
CSV and release-safety tests run in the same dedicated CI.

**Authentic vendor CSV support is still unverified.** A separately
authorized, redacted sample from each provider and independent
authenticated A/B staging are needed before commercial compatibility
claims. Actual attached customer financial files must not be copied
to public GitHub, logs or unrelated third-party AI services.
