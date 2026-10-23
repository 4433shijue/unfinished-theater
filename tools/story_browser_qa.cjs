// Synthetic v2.14 QA only. Run story_browser_fixture.dart first and serve build/web.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const { chromium } = require(process.env.THEATER_PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.THEATER_QA_URL || 'http://127.0.0.1:8924';
const output = 'build/story-qa';
const seed = JSON.parse(fs.readFileSync(`${output}/seed.json`, 'utf8'));
const mock = JSON.parse(fs.readFileSync(`${output}/mock-responses.json`, 'utf8'));
seed.tutorial_seen = true;
seed['release_notice_seen_v2.14.0'] = true;

async function run(browser, width) {
  const context = await browser.newContext({ viewport: { width, height: 950 }, reducedMotion: 'reduce', hasTouch: width < 600 });
  const page = await context.newPage();
  const errors = [], requests = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.route('https://example.test/**', async route => {
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' } });
    const payload = route.request().postDataJSON();
    const text = payload.messages.map(m => m.content).join('\n');
    requests.push(text);
    let content = '{}';
    if (text.includes('改写用户选中的一段正文')) content = JSON.stringify({ replacement: text.includes('我听见了。') ? '嗯，我听到了。' : '灯火悄悄亮起。', preservesFacts: true });
    else if (text.includes('结算文字游戏本轮已经发生')) content = JSON.stringify(mock.judgment);
    else if (text.includes('根据私聊正文整理')) content = JSON.stringify({ affinityDelta: 0, impression: '认真倾听' });
    else if (text.includes('请生成 NPC 对本次消息')) content = JSON.stringify({ messages: ['我听见了。'], impressionPatch: { summary: '认真倾听', affinityDelta: 0 } });
    else if (payload.stream) content = `灯亮了。\n\n阿澈把未拆的信留在灯下，安静地等你回应。\n${mock.protocol}`;
    const body = payload.stream
      ? `data: ${JSON.stringify({ choices: [{ delta: { content } }] })}\n\ndata: [DONE]\n\n`
      : JSON.stringify({ choices: [{ message: { content } }] });
    await route.fulfill({ status: 200, contentType: payload.stream ? 'text/event-stream' : 'application/json', headers: { 'access-control-allow-origin': '*' }, body });
  });
  await page.addInitScript(data => {
    if (localStorage.getItem('qa_seeded')) return;
    for (const [key, value] of Object.entries(data)) localStorage.setItem(`flutter.${key}`, JSON.stringify(value));
    localStorage.setItem('qa_seeded', '1');
  }, seed);
  const button = name => page.getByRole('button', { name, exact: true });
  const capture = async name => {
    await page.waitForTimeout(400);
    await page.screenshot({ path: `${output}/${width}-${name}.png` });
    fs.writeFileSync(`${output}/${width}-${name}.aria.txt`, await page.locator('body').ariaSnapshot());
  };
  try {
    await page.goto(base);
    await page.locator('flt-glass-pane').waitFor({ state: 'attached', timeout: 120000 });
    await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
    await button('打开未完剧场').click();
    await button('接戏卡').click();
    await button('最近事件 灯亮了。').waitFor();
    await capture('resume');
    await button('导演偏好').click();
    await button('作用范围 本回合').click();
    await page.getByRole('menuitem', { name: '本剧本', exact: true }).click();
    await page.getByRole('textbox', { name: '导演补充', exact: true }).click();
    await page.keyboard.insertText('保持克制，不替我行动。');
    await button('剧情节奏 沿用剧本').click();
    await page.getByRole('menuitem', { name: '慢慢相处', exact: true }).click();
    await capture('director');
    await button('保存').click();
    await button('事实、知情与章节').click();
    await capture('facts');
    await page.getByRole('tab', { name: '知情', exact: true }).click();
    await capture('knowledge');
    await page.getByRole('tab', { name: '章节', exact: true }).click();
    await button('在这里收尾').click();
    await button('重新打开当前场景').waitFor({ timeout: 30000 });
    await capture('chapter');
    await button('关闭').click();
    await button('关闭接戏卡').click();
    const bubble = page.getByRole('group', { name: /world 灯亮了/ }).last();
    await bubble.hover({ force: true });
    // CanvasKit exposes the existing compact icon actions in their visible order.
    await bubble.getByRole('button').nth(1).click({ force: true });
    await button('生成预览').click();
    await button('采用这段').waitFor({ timeout: 30000 });
    await capture('rewrite-preview');
    await button('取消').click();
    await bubble.hover({ force: true });
    await bubble.getByRole('button').nth(1).click({ force: true });
    await button('生成预览').click();
    await button('采用这段').click();
    await page.getByRole('group', { name: /world 灯火悄悄亮起/ }).waitFor();
    await capture('rewritten');
    await button('NPC').click();
    await page.getByRole('group', { name: /^阿 阿澈 有未读消息/ }).click({ force: true, position: { x: 90, y: 35 } });
    const npcBubble = page.getByRole('group', { name: /^阿澈 / }).first();
    const rect = await npcBubble.boundingBox();
    await page.mouse.move(rect.x + 30, rect.y + 25);
    await page.mouse.down();
    await page.waitForTimeout(800);
    await page.mouse.up();
    await button('局部重写 / 版本').click();
    await button('生成预览').click();
    await button('采用这段').waitFor();
    await capture('npc-rewrite-preview');
    await button('采用这段').click();
    await capture('npc-rewritten');
    assert.equal(errors.length, 0, errors.join('\n'));
    assert.ok(requests.some(r => r.includes('慢慢相处')));
    return { width, status: 'passed', simulatedRequests: requests.length, pageErrors: errors };
  } catch (error) {
    fs.writeFileSync(`${output}/${width}-requests.json`, JSON.stringify(requests, null, 2));
    await capture('failure');
    throw error;
  } finally {
    await context.close();
  }
}

async function runLongHistory(browser, width) {
  const data = { ...seed };
  const history = JSON.parse(data.history_world);
  const sample = history.messages.find(m => m.role === 'assistant');
  history.messages = [
    ...Array.from({ length: 240 }, (_, i) => ({ ...sample, id: `long-${i}`, content: `旧消息 ${String(i).padStart(3, '0')}\n${'窗外的雨慢慢停了，桌上的信仍然没有拆开。'.repeat(3 + i % 7)}`, gameStateSnapshot: null })),
    ...history.messages,
  ];
  data.history_world = JSON.stringify(history);
  const context = await browser.newContext({ viewport: { width, height: 950 } });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.addInitScript(value => {
    if (localStorage.getItem('qa_seeded')) return;
    for (const [key, item] of Object.entries(value)) localStorage.setItem(`flutter.${key}`, JSON.stringify(item));
    localStorage.setItem('qa_seeded', '1');
  }, data);
  async function enter() {
    await page.locator('flt-glass-pane').waitFor({ state: 'attached', timeout: 120000 });
    await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
    await page.getByRole('button', { name: '打开未完剧场', exact: true }).click();
  }
  try {
    await page.goto(base);
    await enter();
    await page.getByRole('button', { name: '回到顶部', exact: true }).click();
    await page.waitForTimeout(1200);
    const before = await page.locator('body').ariaSnapshot();
    assert.match(before, /旧消息 000/);
    await page.reload();
    await enter();
    await page.waitForTimeout(1200);
    const after = await page.locator('body').ariaSnapshot();
    assert.match(after, /旧消息 000/);
    await page.screenshot({ path: `${output}/${width}-long-history-restored.png` });
    fs.writeFileSync(`${output}/${width}-long-history-restored.aria.txt`, after);
    assert.equal(errors.length, 0, errors.join('\n'));
    return { width, messages: history.messages.length, status: 'passed', restored: 'long-0', pageErrors: errors };
  } finally {
    await context.close();
  }
}

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    const results = [];
    if (!process.argv.includes('--long-only')) for (const width of [1280, 390]) results.push(await run(browser, width));
    const longHistory = [];
    for (const width of [1280, 390]) longHistory.push(await runLongHistory(browser, width));
    fs.writeFileSync(`${output}/browser-report.json`, JSON.stringify({ realModelCalls: 0, results, longHistory }, null, 2));
    console.log(JSON.stringify(results));
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
