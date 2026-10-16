# Releasing to the App Store

Releases are automatic: push a tag and GitHub Actions builds the app, uploads it to TestFlight,
updates the store listing and screenshots, and submits it for review.

```sh
git tag v1.0 && git push origin v1.0
```

Or run the **Release** workflow by hand (Actions tab) to stop at TestFlight, with "Submit for
App Store review" unticked.

What it uses:

- `fastlane/Fastfile`: the `release` lane (build, TestFlight, listing, review).
- `fastlane/metadata`: name, subtitle, description, keywords, category. Edit these to change the listing.
- `fastlane/rating_config.json`: age rating answers (all "none", so 4+).
- `scripts/app_store_screenshots.sh`: takes 6.9" iPhone screenshots on the simulator each release.
- `App/Assets.xcassets/AppIcon.appiconset`: the icon, drawn by `scripts/make_icon.py`.

Build numbers count up from the latest TestFlight build. Signing is automatic through the API key,
so there are no certificates or profiles to manage.

## One-time setup

1. **Repository secrets** (Settings > Secrets and variables > Actions):
   - `APPLE_TEAM_ID`: your 10-character team ID (developer.apple.com > Membership).
   - `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`: an App Store Connect API key with the
     **Admin** role (App Store Connect > Users and Access > Integrations). `ASC_KEY_CONTENT` is the
     `.p8` file's text, or that text base64-encoded. Admin is needed for cloud signing.
2. **Create the app record.** Apple's API can't create apps, so do this once, either in
   App Store Connect (Apps > + > New App, bundle ID `com.arochat9.ColorMatch`, name
   "Color Match: Paint Mixing", SKU `colormatch-ios`) or on a Mac with
   `bundle install && FASTLANE_USER=you@example.com bundle exec fastlane create_app`.
3. **In App Store Connect, once:** App Privacy > "Data Not Collected", and set the
   Support URL and Privacy Policy URL (the policy text is in `docs/privacy.md`; it needs a public URL).
