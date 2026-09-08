# Language picker flags

Source: [flag-icons v7.5.0](https://github.com/lipis/flag-icons/tree/v7.5.0/flags/4x3)
by Panayiotis Lipiridis, MIT license (see `LICENSE.txt`).

Pinned upstream commit: `7aa5b2bdddd570ece62c812c0cb588ccdc099e2e`.
The five SVG files are unmodified copies of `flags/4x3/{ru,gb,kz,by,ua}.svg`.
They are bundled locally; the application does not fetch flags over the network.

Picker mapping: `ru → ru`, `en → gb`, `kk → kz`, `be → by`, `uk → ua`.
These flags are visual hints next to language autonyms, not country/region settings.
The system language option uses the app's existing neutral language/globe SVG.

All flags render at 32 × 24 logical pixels (4:3), without tinting, with a common
rounded clip and theme-aware outline supplied by the Flutter widget. The language
label remains the accessible name; flags do not add duplicate spoken labels.
