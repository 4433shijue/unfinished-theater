// Isolated browser acceptance with a synthetic model and disposable storage.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const { chromium } = require(process.env.THEATER_PLAYWRIGHT_MODULE || 'playwright');
const output = 'build/story-composer-qa';
const seed = JSON.parse(fs.readFileSync(`${output}/seed.json`, 'utf8'));
const mock = JSON.parse(fs.readFileSync(`${output}/mock.json`, 'utf8'));
seed.tutorial_seen = true;
seed['release_notice_seen_v2.16.0'] = true;

async function run(browser, width) {
  const context = await browser.newContext({ viewport: { width, height: 1000 }, hasTouch: width < 600, reducedMotion: 'reduce' });
  const page = await context.newPage();
  const errors = [], requests = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('https://example.test/**', async route => {
    if (route.request().method() === 'OPTIONS') {
      return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' } });
    }
    const payload = route.request().postDataJSON();
    const text = payload.messages.map(m => m.content).join('\n');
    requests.push(text);
    let content = '{}';
    if (text.includes('把玩家已经写出的意图')) {
      content = JSON.stringify({ suggestions: ['外面还在下雨，再坐一会儿好吗？', '我给他的杯子添了水，轻声请他留下。'] });
    } else if (text.includes('只生成下一步选项')) {
      content = mock.options.replace('递上路引，办理进城手续。', '向守卫询问今天的通行手续。');
    } else if (text.includes('结算文字游戏本轮已经发生')) {
      content = JSON.stringify(mock.judgment);
    } else if (text.includes('请生成 NPC 对本次消息')) {
      content = JSON.stringify({ messages: ['我会在这里再等一会儿。'], impressionPatch: { summary: '认真回应', affinityDelta: 0 } });
    } else if (payload.stream) {
      content = `他点点头，留在灯下。\n${mock.protocol}\n${mock.options}`;
    }
    const body = payload.stream
      ? `data: ${JSON.stringify({ choices: [{ delta: { content } }] })}\n\ndata: [DONE]\n\n`
      : JSON.stringify({ choices: [{ message: { content } }] });
    await route.fulfill({ status: 200, contentType: payload.stream ? 'text/event-stream' : 'application/json', headers: { 'access-control-allow-origin': '*' }, body });
  });
  await page.addInitScript(data => {
    if (localStorage.getItem('composer_qa_seeded')) return;
    for (const [key, value] of Object.entries(data)) localStorage.setItem(`flutter.${key}`, JSON.stringify(value));
    localStorage.setItem('composer_qa_seeded', '1');
  }, seed);
  const button = name => page.getByRole('button', { name, exact: true });
  const enterText = async (field, text) => {
    await field.click();
    await page.waitForTimeout(250);
    await page.keyboard.press('Control+A');
    await page.keyboard.insertText(text);
    await page.waitForTimeout(250);
  };
  const expectInput = async (field, value) => {
    await page.waitForFunction(expected => Array.from(document.querySelectorAll('textarea,input')).some(el => el.value === expected), value);
    assert.equal(await field.inputValue(), value);
  };
  const capture = async name => {
    await page.waitForTimeout(400);
    await page.screenshot({ path: `${output}/${width}-${name}.png` });
    fs.writeFileSync(`${output}/${width}-${name}.aria.txt`, await page.locator('body').ariaSnapshot());
  };
  try {
    await page.goto(process.env.THEATER_QA_URL || 'http://127.0.0.1:8936');
    await page.locator('flt-glass-pane').waitFor({ state: 'attached', timeout: 120000 });
    await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
    await button('打开未完剧场').click();
    const composerInput = () => page.locator('textarea:not([disabled]), input:not([disabled])').last();
    await composerInput().waitFor();
    await capture('initial');

    const input = composerInput();
    await enterText(input, '想挽留他，但不想显得太卑微');
    await capture('typed');
    await expectInput(input, '想挽留他，但不想显得太卑微');
    await button('写作小工具').click();
    await page.getByRole('menuitem', { name: '帮我说出来', exact: true }).click();
    await button('外面还在下雨，再坐一会儿好吗？').click();
    await expectInput(input, '外面还在下雨，再坐一会儿好吗？');
    await capture('expression');
    await button('恢复原稿').click();
    await expectInput(input, '想挽留他，但不想显得太卑微');

    await button('写作小工具').click();
    await page.getByRole('menuitem', { name: '私人便签', exact: true }).click();
    const note = page.getByRole('alertdialog').getByRole('textbox');
    await enterText(note, '下次问问戒指。私人便签密码987654');
    await capture('note');
    await button('关闭').click();
    await button('接戏卡').click();
    await button('导演偏好').click();
    await page.getByRole('checkbox', { name: '停留在这一刻', exact: true }).click();
    await page.getByRole('checkbox', { name: '保存当前补充', exact: true }).click();
    await enterText(page.getByRole('textbox', { name: '名称' }), '慢慢接戏');
    await button('保存').last().click();
    await capture('director');
    await button('保存').click();
    await button('关闭接戏卡').click();
    await button('回到顶部').click();

    await button('换一组选项').click();
    await page.getByRole('group', { name: 'A 向守卫询问今天的通行手续。', exact: true })
      .or(button('A 向守卫询问今天的通行手续。')).waitFor({ state: 'attached' });
    if (width < 600) {
      await page.mouse.move(230, 620);
      await page.mouse.wheel(0, 320);
    }
    await capture('choices');
    assert.ok(requests.every(text => !text.includes('密码987654')));
    assert.ok(requests.some(text => text.includes('世界内极限荒诞')));

    await button('回到顶部').click();
    const bubble = page.getByRole('group', { name: /渡口来信 灯亮了/ }).last();
    const rect = await bubble.boundingBox();
    await page.mouse.move(rect.x + 35, rect.y + 35);
    await page.mouse.down();
    await page.waitForTimeout(800);
    await page.mouse.up();
    await bubble.getByRole('button', { name: '接这句', exact: true }).click();
    await page.getByRole('alertdialog').getByText('灯亮了。', { exact: true }).click();
    await button('取消引用').waitFor();
    await capture('quote');
    await enterText(input, '我接着这句话回应。');
    await page.getByRole('button', { name: /^(发送|发送消息)$/ }).click();
    await button('取消引用').waitFor({ state: 'hidden' });
    const savedHistory = await page.evaluate(() => new Promise((resolve, reject) => {
      const open = indexedDB.open('wwjc-durable-storage', 2);
      open.onerror = () => reject(open.error);
      open.onsuccess = () => {
        const db = open.result;
        const read = db.transaction('preferences', 'readonly').objectStore('preferences').get('wwjc.flutter.history_world');
        read.onerror = () => { db.close(); reject(read.error); };
        read.onsuccess = () => {
          db.close();
          const value = JSON.parse(read.result);
          resolve(typeof value === 'string' ? JSON.parse(value) : value);
        };
      };
    }));
    assert.equal(savedHistory.messages.at(-1).quote.text, '灯亮了。');
    const source = savedHistory.messages.find(m => m.id === savedHistory.messages.at(-1).quote.messageId).content;
    let fingerprint = 0x811c9dc5;
    for (let i = 0; i < source.length; i++) fingerprint = Math.imul(fingerprint ^ source.charCodeAt(i), 0x01000193) >>> 0;
    assert.equal(savedHistory.messages.at(-1).quote.sourceDigest, `${source.length}:${fingerprint.toString(16)}`);
    assert.equal(savedHistory.messages.at(-1).content, '我接着这句话回应。');

    await enterText(input, '暂存一句还没发送的话');
    await page.waitForTimeout(600);
    await page.reload();
    await page.locator('flt-glass-pane').waitFor({ state: 'attached', timeout: 120000 });
    if (await page.locator('flt-semantics-placeholder').count()) await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
    await button('打开未完剧场').click();
    await composerInput().waitFor();
    await composerInput().click();
    await expectInput(composerInput(), '暂存一句还没发送的话');
    await capture('restored');
    await button('NPC').click();
    await capture('npc-list');
    await button('编辑').first().click();
    await button('专属称呼').click();
    await enterText(page.getByRole('textbox', { name: '我称呼 TA', exact: true }), '小月亮');
    await enterText(page.getByRole('textbox', { name: 'TA 称呼我', exact: true }), '小灯');
    await enterText(page.getByRole('textbox', { name: '使用条件（可选）', exact: true }), '独处时才使用');
    await capture('addressing');
    await button('保存').last().click();
    await button('取消').click();
    const npcCard = page.getByRole('group', { name: /^阿 阿澈 有未读消息/ });
    await npcCard.click({ force: true, position: { x: 90, y: 35 } });
    await capture('npc-thread');
    const npcBubble = page.getByRole('group', { name: /^阿澈 / }).first();
    const npcRect = await npcBubble.boundingBox();
    await page.mouse.move(npcRect.x + 30, npcRect.y + 25);
    await page.mouse.down();
    await page.waitForTimeout(800);
    await page.mouse.up();
    await button('接这句').click();
    await page.getByRole('alertdialog').getByText('我听见了。', { exact: true }).click();
    await enterText(composerInput(), '这句话我记住了。');
    await capture('npc-quote');
    await page.getByRole('button', { name: /^(发送|发送消息)$/ }).click();
    await button('取消引用').waitFor({ state: 'hidden' });
    await button('提交并生成回复').click();
    await button('提交并生成回复').waitFor();
    await page.waitForTimeout(500);
    assert.ok(requests.some(text => text.includes('小月亮') && text.includes('小灯') && text.includes('这句话我记住了')));
    assert.ok(requests.every(text => !text.includes('密码987654')));
    await capture('npc-replied');
    assert.deepEqual(errors, []);
    return { width, passed: true, requests: requests.length, pageErrors: errors };
  } catch (error) {
    await capture('failure');
    return { width, passed: false, error: error.stack, requests: requests.length, pageErrors: errors };
  } finally { await context.close(); }
}

(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: process.env.THEATER_CHROMIUM_EXECUTABLE || undefined });
  const results = [];
  try { for (const width of (process.env.THEATER_QA_WIDTH ? [Number(process.env.THEATER_QA_WIDTH)] : [1280, 390])) results.push(await run(browser, width)); }
  finally { await browser.close(); }
  fs.writeFileSync(`${output}/browser-report.json`, JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
  if (results.some(r => !r.passed)) process.exitCode = 1;
})();
