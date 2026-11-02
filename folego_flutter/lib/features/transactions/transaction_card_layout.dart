/// Layout policy for a financial row: don't trade readable monetary values
/// for extra horizontal density on narrow phones or enlarged text settings.
bool transactionAmountNeedsOwnLine({
  required double width,
  required double textScale,
}) {
  return width < 350 || textScale >= 1.30;
}
