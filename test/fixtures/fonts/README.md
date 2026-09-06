# Test-only font fixture

`Roboto-Medium.ttf` is an unmodified copy of `roboto-medium.ttf` from the
already installed Flutter 3.44.0 SDK's `bin/cache/artifacts/material_fonts/`
directory. Its Apache-2.0 license is copied verbatim to `LICENSE.txt`.
The font's embedded copyright notice is: Copyright 2011 Google Inc. All Rights Reserved.

- Flutter revision: `559ffa3f75`.
- Material font archive revision: `3012db47f3130e62f7cc0beabff968a33cbec8d8`.
- Font size: 172064 bytes.
- SHA-256: `f205cc511821ea56078a105557fcea6253129404d411c997e1866fbd006abb68`.

The seek-icon raster test loads this file under the test-local `Segoe UI`
family alias so the same real numeral metrics are used on every runner.
Otherwise Flutter's Ahem test glyphs overlap arrow-only inspection regions.
The tests still assert arrow direction, unmirrored digits and scale invariance.

The fixture is not declared in `pubspec.yaml` and is not shipped with the app.
It is intentionally checked in: test execution must not depend on installed
Windows fonts, a populated Flutter font cache, or network downloads.
