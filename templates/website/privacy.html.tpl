<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Privacy Policy &mdash; {{name}}</title>
  <meta name="description" content="Privacy Policy for {{title}}." />
  <link rel="canonical" href="https://{{domain}}/privacy" />
  <link rel="icon" href="/icon.png" />
  <meta name="robots" content="index,follow" />
  <link rel="stylesheet" href="/site.css" />
</head>
<body>
  <div class="wrap narrow">
    <header class="site"><a href="/"><img src="/icon.png" alt="{{name}} icon" /><span class="brand">{{name}}</span></a></header>

    <h1>Privacy Policy</h1>
    <p class="meta">Last updated: {{date}} &middot; App: {{title}} (<code>{{package}}</code>) &middot; Developer: {{developer_name}}</p>

    <div class="card">
      <strong>In short:</strong> {{name}} has no accounts, no ads and no tracking or analytics inside the app. The information it uses stays on your phone.
      We do not collect, sell or share your personal data.
    </div>

    <h2>Information that stays on your device</h2>
    <p>{{name}} keeps its settings and your own data in the app's private storage on your device. It is not sent to us or to any server.
      If you use Android's device backup, Android may include app data in your own Google backup; that is controlled by you and Google, not by us.</p>
{{#if uses_location}}
    <h2>Location</h2>
    <p>The app asks for location permission only when you ask it to use your position. The coordinates are used on your device and are never sent to us.
      To show a place name, your phone's built-in geocoder may contact the location service provided by your device; we do not receive that request.</p>
{{/if}}{{#if uses_internet}}
    <h2>Internet use</h2>
    <p>The app uses the internet to {{internet_purpose}}. When you do this, your device contacts those servers directly, so they can see your IP address and what you requested,
      as with any website. We do not send them anything else.</p>
{{/if}}{{#if uses_notifications}}
    <h2>Notifications and alarms</h2>
    <p>Notifications{{#if uses_exact_alarms}}, exact alarms{{/if}}{{#if uses_full_screen_alert}} and full-screen alerts{{/if}} are used only for the reminders you turn on in the app, and can be switched off in Settings.</p>
{{/if}}
    <h2>Third parties and Google Play statistics</h2>
    <p>The app contains no advertising, analytics, crash-reporting or social-media SDKs. Google Play distributes the app and has its own privacy policy.</p>
    <p>To understand how the app is doing, we use the statistics that Google Play Console provides to every developer: aggregated figures such as installs and uninstalls,
      countries, Android versions, device models, ratings and reviews, and crash or "not responding" reports sent by devices whose owners chose to share diagnostics with Google.
      This comes from Google Play, not from code in the app, and we do not receive your name, contact details, location or personal data.
      You can control diagnostics sharing in your phone's Google settings.</p>

    <h2>Children</h2>
    <p>The app is suitable for all ages and collects no personal information from anyone, including children.</p>

    <h2>Your choices and deleting your data</h2>
    <p>Everything is stored on your device. Clear the app's storage in Android Settings &rarr; Apps &rarr; {{name}} &rarr; Storage, or uninstall the app, to delete it. There is no account or server copy to delete.</p>
{{#if education_disclaimer}}
    <h2>Guidance content</h2>
    <p>{{disclaimer_text}}</p>
{{/if}}
    <h2>Changes to this policy</h2>
    <p>If we change this policy we will update the date above and, where the change matters, mention it in the app's release notes.</p>

    <h2>Contact</h2>
    <p>{{contact_text}} <a href="{{developer_url}}" target="_blank" rel="noopener">{{developer_name}} on Google Play</a>.</p>

    <footer class="site">
      <p><a href="/">Home</a><a href="/privacy">Privacy Policy</a><a href="/terms">Terms of Use</a><a href="{{products_url}}">More products</a></p>
    </footer>
  </div>
</body>
</html>
