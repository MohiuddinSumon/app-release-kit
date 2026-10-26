// Renders Play Store graphics from a job file written by `kit.py graphics`.
//   - feature_graphic_1024x500.png
//   - screenshots/phone_01.png ...  (1080x1920, caption + device frame around each raw screenshot)
//   - screenshots/tablet7_01.png (1200x1920) and tablet10_01.png (1600x2560) when graphics.tablet = true
// Needs Node and Playwright (`npm i -g playwright && npx playwright install chromium`).
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const job = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const c = job.colors;
const dataUrl = (file) => 'data:image/png;base64,' + fs.readFileSync(file).toString('base64');
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

const base = `*{box-sizing:border-box;margin:0}body{font-family:"Segoe UI",Roboto,"Noto Sans","Noto Sans Bengali",Arial,sans-serif;
background:linear-gradient(160deg,${c.bg1},${c.bg2});color:${c.text};overflow:hidden}`;

function featureHtml() {
  return `<style>${base}
  .wrap{width:1024px;height:500px;display:flex;align-items:center;padding:0 70px;gap:56px}
  img{width:250px;height:250px;border-radius:56px;box-shadow:0 12px 40px rgba(0,0,0,.45)}
  h1{font-size:76px;line-height:1.05;font-weight:800}
  p{margin-top:20px;font-size:34px;line-height:1.3;color:${c.accent};font-weight:600;max-width:560px}
  </style><div class="wrap"><img src="${dataUrl(job.icon)}"/><div><h1>${esc(job.name)}</h1><p>${esc(job.tagline)}</p></div></div>`;
}

function shotHtml(w, h, caption, shot) {
  const frameW = Math.round(w * 0.74);
  return `<style>${base}
  .wrap{width:${w}px;height:${h}px;display:flex;flex-direction:column;align-items:center;padding-top:${Math.round(h * 0.05)}px}
  h2{font-size:${Math.round(w * 0.058)}px;line-height:1.2;text-align:center;font-weight:800;max-width:${Math.round(w * 0.86)}px;min-height:${Math.round(h * 0.1)}px}
  .frame{margin-top:${Math.round(h * 0.03)}px;width:${frameW}px;border-radius:${Math.round(w * 0.06)}px;border:${Math.round(w * 0.012)}px solid #0b0b0b;
    overflow:hidden;box-shadow:0 20px 70px rgba(0,0,0,.55),0 0 0 2px ${c.accent}55}
  .frame img{display:block;width:100%}
  </style><div class="wrap"><h2>${esc(caption)}</h2><div class="frame"><img src="${dataUrl(shot)}"/></div></div>`;
}

(async () => {
  const browser = await chromium.launch();
  const render = async (html, w, h, out) => {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    await page.setContent(html, { waitUntil: 'load' });
    fs.mkdirSync(path.dirname(out), { recursive: true });
    await page.screenshot({ path: out });
    await page.close();
    console.log('wrote', path.relative(job.out, out));
  };

  await render(featureHtml(), 1024, 500, path.join(job.out, 'feature_graphic_1024x500.png'));
  const sizes = [['phone', 1080, 1920]];
  if (job.tablet) sizes.push(['tablet7', 1200, 1920], ['tablet10', 1600, 2560]);
  for (const [kind, w, h] of sizes) {
    for (let i = 0; i < job.screenshots.length; i++) {
      const s = job.screenshots[i];
      if (!fs.existsSync(s.file)) { console.error('missing raw screenshot:', s.file); process.exitCode = 1; continue; }
      await render(shotHtml(w, h, s.caption, s.file), w, h, path.join(job.out, 'screenshots', `${kind}_${String(i + 1).padStart(2, '0')}.png`));
    }
  }
  await browser.close();
})();
