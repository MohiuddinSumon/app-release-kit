<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{{title}}</title>
  <meta name="description" content="{{tagline}}" />
  <link rel="canonical" href="https://{{domain}}" />
  <link rel="icon" href="/icon.png" />
  <meta name="robots" content="index,follow" />
  <meta property="og:title" content="{{title}}" />
  <meta property="og:description" content="{{tagline}}" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="https://{{domain}}" />
  <meta property="og:image" content="https://{{domain}}/icon.png" />
  <link rel="stylesheet" href="/site.css" />
</head>
<body>
  <div class="wrap">
    <header class="site">
      <a href="/"><img src="/icon.png" alt="{{name}} icon" /><span class="brand">{{name}}</span></a>
    </header>

    <section class="hero">
      <img src="/icon.png" alt="{{name}} app icon" />
      <h1>{{tagline}}</h1>
      <p class="tagline">{{name}} &mdash; {{subtitle}}.</p>
      <a class="cta" href="https://play.google.com/store/apps/details?id={{package}}" target="_blank" rel="noopener">Get it on Google Play</a>
      <a class="cta alt" href="#features">See features</a>
    </section>

    <section class="features" id="features">
{{#each features}}      <div class="feature"><div class="ic">{{icon}}</div><h3>{{title}}</h3>
        <p>{{text}}</p></div>
{{/each}}    </section>
{{#if education_disclaimer}}
    <div class="notice"><strong>For education only.</strong> {{disclaimer_text}}</div>
{{/if}}
    <footer class="site">
      <p>&copy; {{year}} {{name}} by <a href="{{developer_url}}" target="_blank" rel="noopener">{{developer_name}}</a>. All rights reserved.</p>
      <p>
        <a href="/privacy">Privacy Policy</a>
        <a href="/terms">Terms of Use</a>
        <a href="{{products_url}}">More products</a>
      </p>
    </footer>
  </div>
</body>
</html>
