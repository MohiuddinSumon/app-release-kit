# app-release-kit

Turn an Android app into a **Play-Store-ready release** with one config file and one agent prompt, instead of redoing the same chores for every app.

It was extracted from shipping *Salah Daily* (`com.rocketlab.salahdaily`) and removes these repeated steps:

| Chore | What the kit does |
|---|---|
| Change the package / namespace | `kit.py rename-package` (application ID, namespace, source folders, imports) |
| Generate the first Gradle wrapper | `kit.py init` runs `gradle wrapper`, so nobody has to open Android Studio |
| Release script (version bump, signing, AAB) | `release.bat` / `release.ps1` generated for the app; keystore is named after the package ID |
| Release notes in every language | one `release-notes.txt` with `<en-US>...</en-US>` / `<bn-BD>...</bn-BD>` blocks, length-checked, paste as is |
| Store listing text | `store_assets/LISTING.txt` (copy/paste) plus fastlane-style `metadata/android/<lang>/` files |
| Feature graphic and screenshots | `kit.py graphics` renders 1024x500 and framed phone (and tablet) images from your raw screenshots |
| Website, privacy policy, terms | rendered from your privacy facts; deploy `website/` to Vercel |
| Play Console forms | `docs/PLAY_CONSOLE_CHECKLIST.md` and `docs/PLAY_STORE_PERMISSIONS.md` with ready wording |
| "Will review reject this?" | `kit.py check` lints listing lengths, permissions, assets, signing and wiring |

## Use it for a new app (3 steps)

1. Tell your agent: **"Follow `app-release-kit/PLAYBOOK.md` for this project."** (The agent needs this repo cloned next to the app; it reads `AGENTS.md` and the playbook.)
2. Answer its one round of questions (app name, features, package, languages, privacy facts). They are saved in the app's `release-kit.toml`.
3. Add real screenshots to `store_assets/raw_screenshots/`, run `release.bat`, and walk through `docs/PLAY_CONSOLE_CHECKLIST.md`.

Or by hand:

```bash
python scripts/kit.py init  ../my-app        # first run creates release-kit.toml; fill it in, run again
python scripts/kit.py check ../my-app        # PASS / WARN / FAIL list
```

## Layout

```
config/developer.toml   shared by all apps (developer name, base domain, contact text, default languages)
templates/              everything that gets rendered into an app: release scripts, website, checklists, CI
scripts/kit.py          init | listing | check | rename-package | graphics
scripts/graphics/       Playwright renderer used by `graphics`
examples/               a real config (Salah Daily)
PLAYBOOK.md             the step-by-step workflow an agent follows
```

## Where things live (so nothing is duplicated per release)

- **Per app, once:** `release-kit.toml`, `store_assets/` (icon, feature graphic, screenshots, listing), `website/`, `docs/`.
- **Per release, only:** `release\v<version>-<code>\` with the `.aab`, `.apk`, `mapping.txt` and `release-notes.txt`. Store assets are never copied into it.
- **Across all apps:** this repo (`config/developer.toml` and the templates).

## Requirements

Python 3.11+, Node + Playwright (only for `graphics`), Gradle (only to create the wrapper). The Windows release script needs a JDK 17+.

## What stays manual (Google does not allow automation)

Creating the app and its first upload, the Data safety form, content rating, target audience, and account-level steps such as developer verification and tester requirements. The checklist generated for each app lists them in order. Later releases can be uploaded automatically; see `templates/ci/release.yml.tpl` (needs a Play service account).
