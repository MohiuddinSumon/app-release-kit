# {{name}}: Play Console checklist

Work top to bottom. Items marked (manual) cannot be done through any API. Tick them here as you go.

## 0. Before you start
- [ ] `python scripts/kit.py check .` shows no FAIL
- [ ] `release.bat` produced the signed `.aab` (upload key kept safe in two places)
- [ ] Website deployed and `{{privacy_url}}` opens

## 1. Create the app (manual)
- [ ] App name: **{{title}}** (max 30 characters), default language, App, Free
- [ ] Declarations: policy, US export laws

## 2. Store listing (copy from `store_assets/LISTING.txt`)
- [ ] Short description, full description for each language: {{languages}}
- [ ] App icon 512x512 (`store_assets/icon_512x512.png`), feature graphic 1024x500, at least 2 phone screenshots (`store_assets/screenshots/`)
- [ ] Category: {{category}}; contact email (public; use a developer address, not a personal one); website `https://{{domain}}`
- [ ] Add each extra language under Manage translations (otherwise its release notes are ignored)

## 3. App content declarations (manual)
- [ ] **Privacy policy:** `{{privacy_url}}`
- [ ] **Ads:** No ads
- [ ] **App access:** all functionality available without login
- [ ] **Content rating:** answer the questionnaire honestly (no violence, gambling, user-generated content)
- [ ] **Target audience:** choose the real age range; if children are included, extra policies apply
- [ ] **Data safety:** data collected: **None**{{#if uses_location}}; location is processed on the device only and not collected{{/if}}; data shared: **None**; "all data encrypted in transit": Yes{{#if uses_internet}} (HTTPS){{/if}}; deletion request: not applicable (no account)
- [ ] **Advertising ID:** No
- [ ] **Government / financial / health apps, news, COVID:** No (unless true)
{{#if uses_full_screen_alert}}- [ ] **Full-screen intent:** choose "Other"; wording in `docs/PLAY_STORE_PERMISSIONS.md`
{{/if}}{{#if uses_exact_alarms}}- [ ] **Exact alarms:** wording in `docs/PLAY_STORE_PERMISSIONS.md`
{{/if}}
## 4. Release
- [ ] Testing > Internal testing (or Production) > Create release > upload the `.aab` from `release\v<version>-<code>\`
- [ ] Paste the whole `release-notes.txt` into the release notes box
- [ ] Play App Signing: accept the default
- [ ] Review release > Start rollout
- [ ] New personal developer accounts may need a closed test (about 12 testers for 14 days) before production; check the "Dashboard" tasks

## 5. After release
- [ ] Install from the Play link on a real phone and run through the main flows
- [ ] Add the app to {{products_url}} (see `website/README.md`)
- [ ] Watch Android vitals (crashes / ANRs) and reviews for the first week
