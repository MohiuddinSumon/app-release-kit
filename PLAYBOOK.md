# PLAYBOOK: make an Android app Play-Store-ready

For a coding agent. Input: an Android project (Kotlin/Compose or Java, Gradle `app` module) and this kit cloned beside it. Output: a signed release bundle, a website with a privacy policy, a complete store listing, and a checklist for the few steps only a human can do.

Conventions: `$APP` = the app repo, `$KIT` = this repo. Work on a feature branch in `$APP` and open a PR when done (follow the app's own CLAUDE.md if it has one).

---

## Phase 0: ask once (never twice)
Ask the user for everything below in ONE message, offer defaults, then write the answers into `$APP/release-kit.toml` (create it with `python $KIT/scripts/kit.py init $APP`).

1. **Name and subtitle.** Launcher name (short) and Play title `"<name>: <subtitle>"` (max 30 characters).
2. **One-sentence tagline** and 4-8 **key features** (icon emoji, title, one line each).
3. **Application ID.** Default `com.rocketlab.<slug-without-dashes>`. Explain that it is permanent after the first upload.
4. **Languages** (default `en-US`, `bn-BD`).
5. **Privacy facts** (honest, they are published): location? internet (for what)? notifications? exact alarms? full-screen alert? Any accounts, ads or personal data? (If yes to accounts/ads/personal data the generated policy is NOT enough: write it by hand and say so.)
6. **Does the app give religious, medical, legal or financial guidance?** If yes set `education_disclaimer = true` with a sentence telling users to verify with an expert.
7. **Screenshots.** Ask the user to put 4-8 real screenshots in `$APP/store_assets/raw_screenshots/` and a 512x512 icon at `$APP/store_assets/icon_512x512.png`. Never fabricate screenshots.
8. **Domain.** Default `<slug-without-dashes>.<base_domain>` from `config/developer.toml`.

## Phase 1: project plumbing
```bash
python $KIT/scripts/kit.py rename-package $APP <application.id> --namespace --dry-run   # review, then run without --dry-run
python $KIT/scripts/kit.py init $APP                                                    # wrapper, release scripts, website, docs
```
- `init` creates the Gradle wrapper (`gradlew`, `gradlew.bat`, jar). Commit them. If `gradle` is missing, tell the user to run `gradle wrapper` once.
- `init` never overwrites existing files unless `--force` (release notes and edited pages are safe).
- The release script names the keystore after the package ID (`<application.id>.jks`) and keeps credentials in the git-ignored `keystore.properties`.

## Phase 2: Play-review hardening (manifest and code)
Make these true, then confirm with `kit.py check`:
- Strip the advertising ID: `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />`.
- Only permissions the app really uses. No `USE_EXACT_ALARM` (reserved for alarm/calendar apps; use `SCHEDULE_EXACT_ALARM` and ask the user once). `USE_FULL_SCREEN_INTENT` only for a real alarm-style alert, with the Android 14+ "allow full-screen notifications" prompt.
- Remove unused SDKs (Firebase, ads, analytics, Retrofit, Room...) if nothing in the code uses them: smaller app and an honest Data safety form.
- Ask for notification permission after an explanation, not at first launch.
- Version: `versionCode` must increase on every upload; `versionName` is shown to users.

## Phase 3: store listing
1. Fill `[listing.<lang>]` in `release-kit.toml`: `short` (max 80), `full` (max 4000), optional `title` (max 30) per language. Write natively in each language; no machine-literal translation. Lead with what the app does for the user, not a feature dump; no keyword stuffing or competitor names.
2. `python $KIT/scripts/kit.py listing $APP` writes `store_assets/LISTING.txt` (copy/paste) and `store_assets/metadata/android/<lang>/*.txt`.
3. Release notes live in ONE file, `release-notes.txt`, one block per language (`<en-US>...</en-US>`, `<bn-BD>...</bn-BD>`), max 500 characters each. Ask the user for the changes each release, or draft from `git log` and let them edit.

## Phase 4: graphics
```bash
python $KIT/scripts/kit.py graphics $APP
```
Fill `[[screenshots]]` (file + short caption) in `release-kit.toml` first. Output: `store_assets/feature_graphic_1024x500.png` and `store_assets/screenshots/phone_NN.png` (set `graphics.tablet = true` for 7"/10" sizes). Look at the rendered PNGs yourself before reporting done. Needs Node + Playwright; if unavailable, tell the user.

## Phase 5: website and privacy policy
`init` already rendered `website/` (home, `/privacy`, `/terms`, sitemap, robots, Vercel config). Review `privacy.html` against the manifest: every permission must be explained, and nothing may be claimed that the code does not do. Deployment (human, ~5 minutes): Vercel project with Root Directory `website`, add the domain, add the DNS record. Then add the app card to the developer's products page (snippet in `website/README.md`).

## Phase 6: verify, then release
```bash
python $KIT/scripts/kit.py check $APP     # must have 0 FAIL; explain each WARN to the user
```
Release is `release.bat` (Windows) or `./release.sh` (Git Bash): bump version, show/edit `release-notes.txt`, sign, build `.aab`, collect into `release\v<version>-<code>\`. If you cannot run Gradle here (no Android SDK) say so; do not claim the build passes.

## Phase 7: Play Console (human, in order)
Give the user `docs/PLAY_CONSOLE_CHECKLIST.md`. It lists, with ready answers: create app, store listing, privacy URL, ads = No, app access, content rating, target audience, Data safety, Advertising ID = No, permission declarations (`docs/PLAY_STORE_PERMISSIONS.md`), upload, release notes, rollout. Remind them: new personal accounts may need a closed test (about 12 testers, 14 days) before production.

## Phase 8 (optional): automate later uploads
After the first manual upload, enable `.github/workflows/release.yml.disabled` (rename to `release.yml`), add the four repository secrets listed inside it, and tag `vX.Y.Z` to build and push to the internal track.

---

## Definition of done
- `kit.py check` has 0 FAIL, and every WARN is explained.
- `release-kit.toml`, `store_assets/`, `website/`, `docs/`, `release-notes.txt`, `release.*`, `gradlew*` are committed; keystore and passwords are not.
- You told the user exactly what you could not verify (build, install, real-device behaviour) and what is left for them (deploy site, Play Console forms, upload).
