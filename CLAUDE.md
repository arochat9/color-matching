# Color Match

- Engine tests: `swift test`. App: `ColorMatch.xcodeproj`, scheme `ColorMatch`.
- Shipping to TestFlight / the App Store: run `fastlane release` (add `submit:true` to submit for
  review) from the repo root, in the background (~10 min). Don't hand-run the steps. Details and
  one-time setup are in `RELEASING.md`. Never commit the `.p8` key or `fastlane/.env`.
