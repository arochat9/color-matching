# Color Match

An iPhone app for practicing paint color mixing. You get a goal color, add parts of real paints
from a painter's palette, and submit. The app tells you how close you got and shows the fewest
paints, and the ratio between them, that would have made the goal.

## How to play

1. Look at the goal color (and its name).
2. Tap **+** on paints to add parts. The "Your mix" swatch updates as you go.
3. Tap **Submit** to see:
   - your match percentage (from the CIEDE2000 color difference; 90% is ΔE 3, "very close"),
   - hints on value, saturation and hue,
   - the **simplest recipe**: fewest paints and their whole-number ratio, like `3 Titanium White : 1 Cadmium Red`.
4. Every round you finish at 90% or better adds one point to your lifetime score (the star, saved on the phone).

The palette menu (top right) switches between:

- **Limited palette**: titanium white, ivory black, cadmium yellow, cadmium red, ultramarine blue, yellow ochre, burnt umber.
  This is the usual starting kit for painters.
- **Primaries**: red, yellow, blue, white, black.
- **Zorn palette**: white, black, yellow ochre, cadmium red.

and between three kinds of goals:

- **Mixable colors**: always reachable with your palette, shown with the closest color name.
- **Named colors**: real named colors (cerulean, lemon yellow, ...) that your palette can get close to.
- **Any hex code**: fully random. Some can't be matched, which teaches you the palette's limits.

## How mixing works

Each paint is a reflectance curve from 400 to 700 nm. Mixes are computed with Kubelka–Munk
theory on those curves, so they behave like pigment: blue and yellow make green, yellow and black
make olive, and white lowers saturation as it lightens. RGB averaging gets all of these wrong.
The paint curves are hand-tuned approximations, not measured data for a specific brand.

Color names come from [meodai/color-names](https://github.com/meodai/color-names) (MIT, ~32k names),
in `App/Resources/colornames.csv`.

## Project layout

- `Sources/ColorMixCore`: the mixing engine (color math, paints, mixer, recipe solver, scoring, color names).
- `Tests/ColorMixCoreTests`: tests for the engine. Run with `swift test`.
- `App`: the SwiftUI app.
- `ColorMatch.xcodeproj`: open this in Xcode 16 or later and run on a simulator or your phone
  (pick your team under Signing & Capabilities to run on a device).

CI (`.github/workflows/ci.yml`) runs the tests on macOS, builds the app, and uploads simulator screenshots.
