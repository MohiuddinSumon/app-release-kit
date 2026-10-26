# {{name}}: Play Console permission declarations

Generated from `release-kit.toml`. Paste the wording below where Play Console asks; adjust if behaviour changes.
{{#if uses_full_screen_alert}}
## Full-screen intent (`USE_FULL_SCREEN_INTENT`)
When asked "What is the core functionality of your app?" choose **Other** unless the app really is an alarm clock or a calling app (a wrong category can get the app rejected).

On Android 14+ the permission is not pre-granted for other apps. The app must check `NotificationManager.canUseFullScreenIntent()` and send the user to **Settings > Apps > {{name}} > Full-screen notifications** (see the dialog code in the Salah Daily app for a working example). Without it Android shows the alert in a floating window for about 60 seconds.

**Suggested declaration text (edit to match your app):**
> {{name}} shows a time-critical, alarm-style alert full-screen over the lock screen when [describe the event]. It is shown only when the user has enabled it in Settings. A standard high-priority notification is always posted as a fallback.
{{/if}}{{#if uses_exact_alarms}}
## Exact alarms (`SCHEDULE_EXACT_ALARM`)
`USE_EXACT_ALARM` is **not** declared (reserved for alarm-clock and calendar apps). The app requests "Alarms & reminders" access once and falls back to an inexact alarm if declined.

**Suggested declaration text:**
> The user-enabled reminder in {{name}} must fire at the exact time even when the device is idle, so we use exact alarms for that scheduled reminder only.
{{/if}}
## Permissions at a glance
| Permission | Purpose |
|---|---|
{{#if uses_location}}| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | Needed only when the user asks for their position; processed on the device |
{{/if}}{{#if uses_internet}}| `INTERNET` | {{internet_purpose}} |
{{/if}}{{#if uses_notifications}}| `POST_NOTIFICATIONS` | Reminders the user enabled (ask after an in-app explainer, not at launch) |
{{/if}}| `AD_ID` | **Not used.** Stripped in the manifest with `tools:node="remove"`; answer "No" to the Advertising ID question |

Re-check this table against `app/src/main/AndroidManifest.xml` before every release (`python scripts/kit.py check .` flags mismatches).
