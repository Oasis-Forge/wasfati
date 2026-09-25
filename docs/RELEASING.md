# Releasing

Every PR merged to `main` is a release. The app version is the source of truth: `x.y.z` follows [Semantic Versioning](https://semver.org) (major for breaking changes, minor for new features, patch for fixes and everything else). Mobile stores also need a build number `N` (`x.y.z+N`) that grows by one with every release. `bash scripts/version.sh name` and `build` read them.

1. **Before merging**, bump the version on the branch with `/release [major|minor|patch]`, or by hand: edit the version and add a `## [x.y.z] - YYYY-MM-DD` entry to `CHANGELOG.md`. CI fails if the version isn't above the latest `vX.Y.Z` tag or has no changelog entry. Dependabot PRs are exempt and ship with the next release.
2. **On merge**, `release.yml` builds the release artifacts, tags the merge commit `vX.Y.Z`, and attaches them to a **draft** GitHub Release with the changelog entry as notes. A merge whose version is already tagged releases nothing.

Tags pushed by CI don't start other workflows, so any other platform's release workflow is run by hand from the Actions tab, or with `gh workflow run <workflow>.yml --ref vX.Y.Z`. Each checks that the tag matches the version.

Targets: Android on Google Play in v1; iOS later (its sections stay for then). No desktop.

## GitHub secrets and variables

Add them in GitHub → Settings → Secrets and variables → Actions, or with `gh secret set NAME` (it prompts for the value).

| Name | Kind | Used by | Value |
|---|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | secret | `claude.yml` | Output of `claude setup-token` |
| `ANDROID_KEYSTORE_BASE64` | secret | `release.yml` | Base64 of `upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | secret | `release.yml` | Keystore password |
| `ANDROID_KEY_ALIAS` | secret | `release.yml` | Key alias, e.g. `upload` |
| `ANDROID_KEY_PASSWORD` | secret | `release.yml` | Key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | secret | `release.yml` | Google Cloud service-account JSON key with Play Console release access |
| `IOS_DIST_CERT_P12_BASE64` | secret | iOS release | Base64 of the Apple Distribution certificate (`.p12`) |
| `IOS_DIST_CERT_PASSWORD` | secret | iOS release | Password of the `.p12` |
| `APPSTORE_ISSUER_ID` | secret | iOS release | App Store Connect API issuer ID |
| `APPSTORE_KEY_ID` | secret | iOS release | App Store Connect API key ID |
| `APPSTORE_PRIVATE_KEY` | secret | iOS release | Full contents of the `.p8` API key |
| `APPLE_TEAM_ID` | variable | iOS release | 10-character Apple team ID |

## Protect `main`

Settings → Rules → Rulesets → New branch ruleset, target `main`:
- Require a pull request before merging.
- Require status checks to pass: the CI job names. Run CI on one PR first so the names show up in the picker.
- Block force pushes and deletion.
- Bypass list: empty, so even the admin merges through a PR, or Repository admin if you want an emergency override.

Check it with `gh api repos/Oasis-Forge/wasfati/rulesets`. The classic branch-protection endpoint answers 404 for a branch protected only by a ruleset, which looks like no protection at all.

## Public repository

- **Secrets stay safe:** GitHub masks secret values in logs, and the workflows never print them. CI uses `pull_request`, not `pull_request_target`, so PRs from forks run without secrets. `claude.yml` runs only for `thepromptkitchen-alt`.
- **Releases are drafts**, so nobody can download an artifact until you publish it.
- **Fork PRs:** Settings → Actions → General → "Approval for running fork pull request workflows" → "Require approval for all external contributors".
- **Commit emails are public.** Use the noreply address from GitHub → Settings → Emails: `git config user.email "<id>+thepromptkitchen-alt@users.noreply.github.com"`.
- **License:** with no `LICENSE` file the code is "all rights reserved". Flathub and similar stores need a license that allows redistribution.
- A public repo gets free GitHub-hosted runners, macOS included, so CI can compile iOS on every PR.

## Privacy policy

Both mobile stores require a public privacy policy URL.
1. Settings → Pages → Deploy from a branch → `main` / `/docs`.
2. The policy is then live at `https://oasis-forge.github.io/wasfati/privacy-policy`: one bilingual page, `docs/privacy-policy.html`, English then Arabic, plain HTML so no theme turns its title into a link. Email is the only support channel named on it, oasisforge.support@gmail.com. No personal address and no issue tracker is ever published.
3. **Ads:** the ad network reads `app-ads.txt` from the **root** of the domain in the store listing's Website field, not from the repo's path. Serve it from the organization's own Pages repo (`Oasis-Forge/oasis-forge.github.io`): one line per ad account, shared by every app. AdMob can only verify it once the app is public.

Every file in `docs/` gets published.

## Ads (AdMob)

Created 20 September 2026. The IDs aren't secrets: they ship inside the app, so they live in the repo (ADS-8). Only release builds use them; every other build uses Google's test units.
- App ID: `ca-app-pub-8287765177319119~8706163515`
- Banner unit, used by every slot (ADS-9): `ca-app-pub-8287765177319119/9667891390`

Where they live, and what keeps test and real IDs apart (ADS-8):
- The Dart side picks them in `lib/services/ads.dart` (`AdIds`) by `kReleaseMode`, a compile-time constant, so a release build carries only the real IDs and a debug or profile build only Google's test ones.
- The manifest's `com.google.android.gms.ads.APPLICATION_ID` comes from `manifestPlaceholders["admobAppId"]` in `android/app/build.gradle.kts`: Google's test app ID in `defaultConfig`, the real one in the `release` build type only.
- `test/services/ad_ids_test.dart` fails if the copies in the code, Gradle, the manifest, `ios/Runner/Info.plist` and this file drift apart, and the release workflow checks the built APK: the manifest carries the real app ID, the Dart code the real banner unit, and neither carries Google's test publisher ID.
- iOS has no ad unit of our own until Phase 6: `Info.plist` carries Google's test app ID so the SDK starts, and an iOS release asks for no ads at all.

**Consent (ADS-5), once before the first release with ads:** in AdMob → Privacy & messaging, create and publish a European regulations (GDPR) message for this app, in Arabic and English, with the privacy policy URL. The app shows Google's own form through the User Messaging Platform only where the law asks (the EEA, the UK, Switzerland). Without a published message there is no form to show, the SDK can't record an answer, and users there get no ads.

## One-time setup: Android

1. Create the upload keystore and back it up with its passwords. Losing it means asking Google for an upload-key reset.
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Base64 it into the clipboard for `ANDROID_KEYSTORE_BASE64` (PowerShell):
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
   ```
3. Optional, for signed local builds: keep the keystore and a `key.properties` in the Android project, both gitignored.
4. In Play Console, create the app with package `com.oasisforge.wasfati` and keep Play App Signing enabled.
5. **Upload the first AAB by hand** in Play Console → Testing → Internal testing. The API can't create an app's first release.
6. In Google Cloud, create a service account and a JSON key. In Play Console → Users and permissions, invite it with release permissions for this app. Save the JSON as `PLAY_SERVICE_ACCOUNT_JSON`.
7. New personal developer accounts need a closed test with at least 12 testers for 14 days before production access. Confirm the current rule and start early.
8. **Contact details.** Play shows two public emails: the store listing's support email (App support) and the developer account's email (About the developer, on every app). Both are **oasisforge.support@gmail.com**, the one support address for every Oasis Forge app; keep the Play Console login private. A personal account also shows its legal name and country there; only an organization account (it needs a D-U-N-S number) shows the brand instead.
9. **Payments profile → Public merchant profile:** the merchant name is the publisher, never a personal name, with the same support email (oasisforge.support@gmail.com).
10. **In-app products** (PAY-8, Decisions 10 and 17). The IDs are permanent after the first upload, like the app ID:
    - `pro`: a one-time product, AED 14.99.
    - `premium`: a subscription with two auto-renewing base plans, `monthly` at AED 9.99 and `yearly` at AED 79.99, and **no offers**: no free trial (PAY-9, Decision 11) and no introductory price. The app lists only base plans and ignores any offer.
    - Play converts the base prices for other countries; the app only ever shows Play's own price (PAY-2).
    - Until these exist and are Active, the purchase screen says nothing is for sale (PAY-6). Premium's server-side quota needs a service account first (Decision 22, Phase 5).

    A one-time product needs a purchase option (type Buy). Add the testers' Google accounts under Settings → Licence testing (account level, not per app), so their test purchases cost nothing. Products only show in a build installed from a Play testing track, once the product is Active.
11. **EU trader status** (Digital Services Act): an app with ads or purchases makes you a trader, and Play then shows your address, phone and email to EU users. Declare it before applying for production; a virtual office address keeps a home address private. Apple asks the same for the EU App Store.
12. **Release notes** for every release come from `/release`, in `store/play/release-notes/X.Y.Z.txt`. All store listing material lives in `store/` (gitignored).

Without the signing secrets, CI signs each APK with a throwaway debug key, which can't update an installed copy: back up in the app, uninstall, install, restore.

## One-time setup: iOS

1. Enroll in the Apple Developer Program.
2. Register the App ID `com.oasisforge.wasfati` and create the app record in App Store Connect.
3. Create an Apple Distribution certificate. Without a Mac, use OpenSSL (it ships with Git for Windows):
   ```bash
   openssl genrsa -out dist.key 2048
   openssl req -new -key dist.key -out dist.csr -subj "/emailAddress=you@example.com/CN=Wasfati/C=US"
   ```
   Upload `dist.csr` at developer.apple.com → Certificates → Apple Distribution, download `distribution.cer`, and convert it:
   ```bash
   openssl x509 -inform DER -in distribution.cer -out dist.pem
   openssl pkcs12 -export -legacy -inkey dist.key -in dist.pem -out dist.p12
   ```
4. Create an **App Store** provisioning profile for the App ID. Every extension (widget, share sheet) is a separate target: it needs its own App ID, its own profile, and an App Group on both App IDs if it reads the app's data.
5. In App Store Connect → Users and Access → Integrations, create an API key with the App Manager role.
6. Set `APPLE_TEAM_ID`, then run the iOS release workflow by hand with upload on before tagging a real release.

## One-time setup: Claude GitHub Action

Run `/install-github-app` from a `claude` terminal, or install the Claude GitHub app on the repo and add `CLAUDE_CODE_OAUTH_TOKEN`. Then comment `@claude <request>` on an issue or PR. Only `thepromptkitchen-alt` can trigger it, and each run is capped at 15 turns.

## App icon and splash screen

Draw them from one committed source, generate the platform files with the stack's tools, and commit the results. The commands are in `docs/STACK_NOTES.md`.

## Brand assets

LOOK-9: the launcher icon, the splash screen and the store icon are one design, from one committed source image, and none of them change with the look (LOOK-1) or the light/dark setting. The mark is a khatam star above the app's Arabic name «وصفاتي» (LANG-2).

- **Source:** `assets/brand/icon-1024.png` — a committed image, generated with an image model and kept verbatim (not drawn, not edited by hand): the saffron ground, an eight-point khatam star outline and «وصفاتي» in cream, 1024×1024.
- **Derive the other layers** from it after any change to the source (reads `icon-1024.png`, writes `assets/brand/icon-foreground-1024.png` and `splash-1024.png` — the mark alone, ground keyed out to transparent, scaled to ~60%/~50% of the canvas — and `icon-128.png`, a small-size proof copy to judge the icon by eye at launcher size; nothing here is committed by the command itself, the PNGs are just left in the working tree):
  ```
  flutter test tool/brand/derive_brand_assets.dart
  ```
  `tool/brand/derive_brand_assets.dart` samples the ground colour from `icon-1024.png`'s own corners (never hard-coded, so it still works if the source image changes) and prints it — that value also goes into `pubspec.yaml`'s `flutter_launcher_icons`/`flutter_native_splash` config below, since those are static YAML and can't sample it themselves. Currently `#B04E26`.
- **Regenerate the platform files** from those PNGs (configured under `flutter_launcher_icons:` and `flutter_native_splash:` in `pubspec.yaml`, background/colour set to the sampled hex above):
  ```
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  ```
- Commit the regenerated PNGs under `assets/brand/` and every platform file the two generators touch (Android `mipmap-*`, `drawable*`, `values*`; iOS `Assets.xcassets`, `Info.plist`, `LaunchScreen.storyboard`). `assets/brand/` is a build-time source only — it is never added to the app's runtime `assets:` list, so the app doesn't grow by the PNGs' size.
- **`assets/brand/logo-wasfati.png`** is a separate, committed-as-is brand image: the Latin "Wasfati" wordmark and khatam star, also made with an image generator. It's the English-language brand image for the store listing — the icon itself never uses it, since the icon is the Arabic mark.
- The Arabic Android launcher label lives in `android/app/src/main/res/values-ar/strings.xml` (`app_name` = وصفاتي); the English default is in `values/strings.xml`. The iOS Arabic display name needs Xcode and is Phase 6 work.
