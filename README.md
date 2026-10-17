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
While you mix, the app warns you when:

- the goal **can't be mixed** with your palette at all, or
- your pile is **past the point of no return**: adding paint, even doubling the pile, can't get it to 90%. Real paint can't be taken back out, so this is when you'd start fresh.

4. Every round you finish at 90% or better adds one point to your lifetime score (the star, saved on the phone).

The swatch button (top right) opens the **color library**: every named color, grouped by hue and searchable.
Tap one to practice mixing it. Practice rounds don't earn stars.

Your palette is always seven tubes: a fixed core of titanium white, ivory black, cadmium yellow,
cadmium red, phthalo blue and quinacridone magenta, plus one tube picked for each goal (ultramarine,
cadmium orange, alizarin crimson, yellow ochre, burnt sienna, viridian, ...), marked "Added for this color".
That's how painters work: a small everyday palette and a specialty tube when a subject needs it.
It can reach about 93% of the painter colors.

The palette menu (top right) switches between two kinds of goals:

- **Named colors**: any of the 134 painter colors (Cerulean Blue, Burnt Sienna, Payne's Grey, ...).
- **Any hex code**: fully random. Some can't be matched, which teaches you the palette's limits.

The home page offers two games, **Mix to Match** (above) and **Color Theory** (below), each with a
"How to play" walkthrough. The house button in either game returns home.

## Color theory game

A separate game for color harmony, taught on the painter's (red-yellow-blue) wheel, where red sits opposite green:

- **Best fit**: a set of colors is a harmony with one color missing. Pick which of five options belongs.
  One option has the right hue but a clashing tone (too bright for a soft set, say), so tone counts too.
- **Find the hue**: a set with one color missing, and a color picker limited to one hue family ("find the
  green that fits"). You're scored on hue and tone, with tips like "12° too far toward blue-green".

After each answer the app names the rule (complementary, analogous, split complementary, triadic or square),
explains it, and shows the set on the wheel. The harmony math is in `Sources/ColorMixCore/Harmony.swift`.

## How mixing works

Each paint is a reflectance curve from 400 to 700 nm. Mixes are computed with Kubelka–Munk
theory on those curves, so they behave like pigment: blue and yellow make green, yellow and black
make olive, and white lowers saturation as it lightens. RGB averaging gets all of these wrong.
The paint curves are hand-tuned approximations, not measured data for a specific brand.

Each goal is labelled with its nearest color name, such as "Close to Cerulean (lighter, duller)".
Names come from `App/Resources/paintcolors.csv`: every common artist pigment under its usual tube name
(one entry per Colour Index pigment, so no brand aliases), plus classic premixed colors such as Payne's Grey
and Sap Green. The swatch values are estimates of how each tube looks, not measured data.

## Project layout

- `Sources/ColorMixCore`: the mixing engine (color math, paints, mixer, recipe solver, scoring, color names).
- `Tests/ColorMixCoreTests`: tests for the engine. Run with `swift test`.
- `App`: the SwiftUI app.
- `ColorMatch.xcodeproj`: open this in Xcode 16 or later and run on a simulator or your phone
  (pick your team under Signing & Capabilities to run on a device).

CI (`.github/workflows/ci.yml`) runs the tests on macOS, builds the app, and uploads simulator screenshots.

Releases to the App Store are automated with fastlane and GitHub Actions; see [RELEASING.md](RELEASING.md).
