<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Terms of Use &mdash; {{name}}</title>
  <meta name="description" content="Terms of Use for {{title}}." />
  <link rel="canonical" href="https://{{domain}}/terms" />
  <link rel="icon" href="/icon.png" />
  <meta name="robots" content="index,follow" />
  <link rel="stylesheet" href="/site.css" />
</head>
<body>
  <div class="wrap narrow">
    <header class="site"><a href="/"><img src="/icon.png" alt="{{name}} icon" /><span class="brand">{{name}}</span></a></header>

    <h1>Terms of Use</h1>
    <p class="meta">Last updated: {{date}} &middot; {{title}} by {{developer_name}}</p>

    <h2>Acceptance</h2>
    <p>By downloading or using {{name}} you agree to these terms. If you do not agree, please do not use the app.</p>

    <h2>What the app is</h2>
    <p>{{name}} is provided for personal, non-commercial use.</p>
{{#if education_disclaimer}}
    <h2>For education only</h2>
    <div class="notice">{{disclaimer_text}}</div>
{{/if}}
    <h2>No warranty and limitation of liability</h2>
    <p>The app is provided "as is" without warranties of any kind. To the fullest extent permitted by law, {{developer_name}} is not liable for any loss arising from your use of the app.</p>

    <h2>Acceptable use</h2>
    <p>Do not copy, resell, reverse engineer or misuse the app, or use it to harm others.</p>

    <h2>Changes</h2>
    <p>We may update the app and these terms. Continued use after an update means you accept the new terms.</p>

    <h2>Contact</h2>
    <p>{{contact_text}} <a href="{{developer_url}}" target="_blank" rel="noopener">{{developer_name}} on Google Play</a>. See also our <a href="/privacy">Privacy Policy</a>.</p>

    <footer class="site">
      <p><a href="/">Home</a><a href="/privacy">Privacy Policy</a><a href="/terms">Terms of Use</a><a href="{{products_url}}">More products</a></p>
    </footer>
  </div>
</body>
</html>
