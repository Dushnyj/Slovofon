# Assets

This directory contains Slovofon app artwork and checked-in SVG UI icons.

- `assets/app/` contains draft app icon artwork. Platform launcher icons are not replaced until the owner approves the final icon.
- `assets/icons/` contains Lucide-derived 24x24 stroke SVG icons using `currentColor`. Each file includes a source comment with the Lucide version and original icon name.
- `assets/l10n/` is reserved for future generated/localization assets.

## Icon Semantics

The Stage 2 icon map follows common app UI conventions:

- Navigation uses `house`, `search`, `library-big`, `download`, and `settings`.
- Book metadata uses person/voice/time/calendar/tag/source/access metaphors, for example `user-pen` for author, `mic` for narrator, `clock-3` for duration, `tags` for genre, and `globe` for source.
- Player controls use recognizable transport symbols: `play`, `pause`, `skip-back`, `skip-forward`, rewind/forward variants, `audio-lines` for active audio, `gauge` for speed, `timer` for sleep timer, and `volume-x` for mute.
- Download states are intentionally distinct: `download`, `loader-circle`, `clock`, `circle-check`, `trash-2`, `rotate-ccw`, `triangle-alert`, `circle-pause`, and `circle-play`.
- System actions use standard commands: `trash-2` for delete, `x` for close, `ellipsis` for more, `list-filter` for filters, `arrow-up-down` for sorting, `chevron-right` for drill-in navigation, and `bell` for notifications.
