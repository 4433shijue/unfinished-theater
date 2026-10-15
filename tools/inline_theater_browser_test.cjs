// Run after `dart run tools/inline_theater_fixtures.dart`.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.THEATER_PLAYWRIGHT_MODULE || 'playwright');

(async () => {
  const out = path.resolve('build/inline-theater-qa');
  const fixtures = JSON.parse(fs.readFileSync(path.join(out, 'fixtures.json'), 'utf8'));
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  const results = [];
  try {
    for (const width of [390, 1100]) {
      const page = await browser.newPage({ viewport: { width, height: 844 } });
      const requests = [];
      page.on('request', r => requests.push(r.url()));
      for (const [name, document] of Object.entries(fixtures)) {
        await page.setContent('<main><h1>每回合番外验收</h1><iframe title="番外" sandbox="allow-scripts" style="width:100%;height:640px;border:0"></iframe></main>');
        await page.evaluate(doc => {
          window.events = [];
          window.addEventListener('message', e => { if(e.data?.type === 'ai-roleplay-action') window.events.push(e.data); });
          document.querySelector('iframe').srcdoc = doc;
        }, document);
        const frame = page.frameLocator('iframe');
        await frame.locator('body').waitFor();
        if (name === 'actions' || name === 'localOnly') {
          await frame.getByRole('button', { name: '旧工具行动' }).click();
          await frame.getByRole('button', { name: '揭晓' }).click();
          assert.equal(await frame.locator('#reveal').isVisible(), true);
          const events = await page.evaluate(() => window.events);
          assert.deepEqual(events.map(e => e.value), name === 'actions' ? ['继续等雨'] : []);
          const evil = await page.frames()[1].evaluate(() => window.compromised);
          assert.equal(evil, undefined);
        } else {
          if (name === 'miniGame') {
            await frame.getByRole('button', { name: '先放茶叶' }).click();
            assert.equal(await frame.locator('#answer0').isVisible(), true);
            await frame.getByRole('button', { name: '再加一片柠檬' }).click();
            assert.equal(await frame.locator('#answer0').isVisible(), false);
            await frame.getByRole('button', { name: '最后递过去' }).click();
            assert.equal(await frame.locator('#answer2').isVisible(), true);
          } else {
            const buttons = frame.locator('button[data-extra-action="show"]');
            for (let i = 0; i < await buttons.count(); i++) {
              await buttons.nth(i).click();
              assert.equal(await frame.locator(`#answer${i}`).isVisible(), true);
            }
          }
          const overflow = await page.frames()[1].evaluate(() => document.documentElement.scrollWidth > innerWidth + 1);
          assert.equal(overflow, false, `${name} overflows at ${width}`);
          await frame.getByRole('button', { name: '重新看看' }).click();
          assert.equal(await frame.locator('#answer2').isVisible(), false);
          assert.deepEqual(await page.evaluate(() => window.events), []);
          if (name === 'backstageChat' || name === 'miniGame') {
            await frame.locator('button[data-extra-action="show"]').first().click();
            await page.screenshot({ path: path.join(out, `${name}-${width}.png`) });
          }
        }
        results.push({ name, width, passed: true });
      }
      assert.deepEqual(requests, [], 'Local interactions must not issue network/model requests');
      await page.close();
    }
    fs.writeFileSync(path.join(out, 'results.json'), JSON.stringify({ passed: results.length, results }, null, 2));
    console.log(JSON.stringify({ passed: results.length, screenshots: out }));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
