# Bundled typography

Manrope: interface, card titles and all monetary values. Unbounded Bold: brand display and primary page headings.

Sources: Google Fonts official repository, `ofl/manrope/Manrope[wght].ttf` and `ofl/unbounded/Unbounded[wght].ttf` (downloaded 2026-10-15). Static instances were generated with fontTools varLib.instancer at the weights named in each file. Both upstream SIL Open Font License files are included unchanged.

These files are declared as native Flutter font families in pubspec.yaml. AppTypography uses these registered families directly, so widget construction never requests fonts from an external CDN or swaps asynchronously loaded font metrics.
