# Releasing to the App Store

Same setup as fitcheck: fastlane on your Mac, signed with the App Store Connect API key in
`~/.appstoreconnect/private_keys/` (Apple's cloud-managed certificates, nothing to manage by hand).

```sh
fastlane release                       # build, TestFlight, listing + fresh screenshots
fastlane release version:1.0 submit:true   # ...and submit for App Store review
```

It takes about 10 minutes, so run it in the background. The build number is the highest one on
App Store Connect plus one, so there's nothing to bump.

Other lanes:

- `fastlane setup`: one time. Registers the bundle ID and checks the app record exists.
- `fastlane metadata`: push only the listing text from `fastlane/metadata`.
- `fastlane screenshots`: take 6.9" iPhone screenshots on the simulator and push only those.

Files:

- `fastlane/metadata`: name, subtitle, description, keywords, category, copyright. Edit to change the listing.
- `fastlane/rating_config.json`: age rating answers (all "none", so 4+).
- `scripts/app_store_screenshots.sh`: the screenshot script, using the app's `-demo` launch modes.
- `App/Assets.xcassets/AppIcon.appiconset`: the icon, drawn by `scripts/make_icon.py`.

## From GitHub instead

The **Release** workflow runs the same lane on a GitHub Mac runner. Push a tag (`git tag v1.0 &&
git push origin v1.0`) to release and submit, or run it from the Actions tab to stop at TestFlight.
It needs repo secrets `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID` (the same values as in
`fastlane/.env`) and `ASC_KEY_CONTENT` (the text of the `.p8` key).

## One-time setup

1. `cp fastlane/.env.example fastlane/.env` and fill in the team ID, key ID and issuer ID
   fitcheck uses (they're in fitcheck's `swift-mobile-app/CLAUDE.md`).
2. `fastlane setup`, then create the app in App Store Connect (Apps > + > New App) with the name
   "Color Match: Paint Mixing", bundle ID `com.arochat9.ColorMatch` and SKU `colormatch-ios`.
   Apple's API can't create app records.
3. Turn on GitHub Pages: repo Settings > Pages > Deploy from a branch > `main` / `/docs`. That
   publishes the support and privacy pages the listing links to (`docs/`). Then in App Store
   Connect set App Privacy to "Data Not Collected".
4. Add your contact details for App Review under App Store Connect > the app > App Review Information.
