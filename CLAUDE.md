# Instructions for coding agents

This repository is a **release kit**. When the user asks you to make an Android app release-ready (or to "follow the playbook"), read `PLAYBOOK.md` and execute it for the app repository they point you at. Do not improvise a different order.

Rules:
- The only per-app input is `release-kit.toml` in the app repo. Ask the user for missing facts once, write them there, and never invent privacy facts, features or screenshots.
- Run `python scripts/kit.py check <app_repo>` before saying anything is ready, and report FAIL/WARN lines verbatim.
- Never claim a build, install or Play upload worked unless you ran it and saw it succeed. If you cannot build (no Android SDK), say so and list what the user must test.
- Never commit keystores, passwords or service-account keys. The kit's `.gitignore` additions cover `*.jks` and `keystore.properties`.
- The application ID is permanent after the first Play upload: confirm it with the user before renaming.
- Commit and PR conventions: follow the app repository's own `CLAUDE.md`/`AGENTS.md` if it has one.
