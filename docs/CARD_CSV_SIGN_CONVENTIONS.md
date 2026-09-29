# Fôlego 360 — credit-card CSV sign interpretation

Status: isolated draft PR only, NOT deployed. This is for **generic opt-in
CSV file imports**, not private Organizze or Mobills integrations.

Some card statement CSV exports represent a card purchase as **negative**
(`-35,90`), with a credit/refund as positive. Others show card charges as
**positive** (`+35,90`), with a refund as negative. Assuming a single
format for all card providers can classify purchases as refunds and
corrupt reporting.

## Implementation and safety

- The existing import wizard displays a mandatory explicit
  **"sinal das compras no cartão"** selector for **signed-value credit
  card CSVs**, after the destination card and source columns are chosen.
  Neither choice is preselected; without a selection, **no staging
  request is permitted**.
- The backend receives a **normalized debit for a card purchase**,
  independently of the CSV source sign. The absolute amount is preserved
  and the chosen `card_sign_convention` is included in the import
  configuration for audit. Refunds remain pending human review.
- If the CSV uses separate columns named `Débito` and `Crédito`,
  their explicit headings already encode direction: they are never
  reversed by the signed-card option. Import of bank accounts and benefit
  accounts is likewise never affected.
- A matching card bill payment is a `cardPaymentCandidate`, not a
  second expense; it still requires explicit invoice association.
- If two columns could both be the signed amount, the previous
  migration safety check requires manual field selection. Ambiguous
  decimals (`1.234` vs `1,234`) still require explicit decimal
  locale choice. Import remains staged, deduplicated and separately
  confirmed by the existing all-user pipeline.
- Both the import wizard **and the underlying CSV parser** now require
  an explicit source-sign choice for signed-value credit-card CSVs.
  A brand-new mapping defaults to `unselected` and cannot create even a
  staged card candidate when called directly without that choice. This
  closes the gap for non-widget call paths while preserving the behavior
  of account and benefit exports and split debit/credit card columns.

## Synthetic verification

Nine parser tests exercise purchases, reversed refund signs, bill-payment
review, account/benefit isolation, split debit/credit behavior and
ambiguity failures. The phone-sized widget tests verify that clicking
"stage" with no card-sign choice sends **zero** staging requests, and
that explicitly selecting positive purchases sends only canonical
card purchase/refund rows with persisted metadata.

The test fixture CSVs and account names are wholly fictitious.
Real provider export layouts, authenticated financial-space staging,
historical statement reconciliation, closed-PWA session revocation and
native store billing are independent release gates. No live financial
data or real account credentials may be added to CI/logs.

This feature does **not** infer whether a provider's proprietary
card statement is compatible. Test an explicitly consented, redacted
export before claiming format support.
