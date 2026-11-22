// Synthetic browser journeys against the production Flutter web build.
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { chromium } = require(
  process.env.THEATER_PLAYWRIGHT_MODULE || "playwright",
);
const out = "build/story-expression-qa";
fs.mkdirSync(out, { recursive: true });
const baseSeed = JSON.parse(
  fs.readFileSync("build/story-expression-qa/seed.json", "utf8"),
);
const skinControls = JSON.parse(fs.readFileSync(`${out}/skin-controls.json`, "utf8"));
const mock = JSON.parse(
  fs.readFileSync("build/story-expression-qa/mock.json", "utf8"),
);

async function launch() {
  return chromium.launch({
    headless: true,
    executablePath: process.env.THEATER_CHROMIUM_PATH,
  });
}
async function open(
  browser,
  {
    width = 1440,
    height = 1000,
    theme = "sakura",
    caseName,
    old = false,
    prepareSeed,
    accessibility = true,
  } = {},
) {
  const seed = {
    ...baseSeed,
    tutorial_seen: true,
    "release_notice_seen_v2.16.0": true,
    "release_notice_seen_v3.0.0": true,
  };
  const settings = JSON.parse(seed.app_settings);
  settings.themeId = theme;
  seed.app_settings = JSON.stringify(settings);
  for (const key of Object.keys(seed))
    if (key.startsWith("journal_")) delete seed[key];
  if (prepareSeed) prepareSeed(seed);
  const context = await browser.newContext({
    viewport: { width, height },
    reducedMotion: "reduce",
    hasTouch: width < 600,
  });
  const page = await context.newPage();
  const errors = [],
    requests = [];
  const consoleLog = path.join(out, `${theme}-${width}-console.log`);
  fs.writeFileSync(consoleLog, "");
  page.on("console", (m) => fs.appendFileSync(consoleLog, m.text() + "\n"));
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => {
    if (
      /overflowed by|Another exception was thrown|Duplicate GlobalKey/.test(
        m.text(),
      )
    )
      errors.push(m.text());
  });
  await page.route("https://example.test/**", async (route) => {
    if (route.request().method() === "OPTIONS")
      return route.fulfill({
        status: 204,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-headers": "*",
        },
      });
    const payload = route.request().postDataJSON();
    const text = payload.messages.map((m) => m.content).join("\n");
    requests.push(text);
    let content = "{}";
    if (text.includes("把玩家已经写出的意图"))
      content = JSON.stringify({
        suggestions: [
          "外面还在下雨，再坐一会儿好吗？",
          "我给他的杯子添了水，轻声请他留下。",
        ],
      });
    else if (text.includes("只生成下一步选项"))
      content = mock.options.replace(
        "递上路引，办理进城手续。",
        "向守卫询问今天的通行手续。",
      );
    else if (text.includes("只预演下面这一个选项"))
      content =
        "这条路线会让守卫暂时放下戒备，但是否获得通行仍取决于下一步交涉。";
    else if (text.includes("结算文字游戏本轮已经发生"))
      content = JSON.stringify(mock.judgment);
    else if (text.includes("请生成 NPC 对本次消息"))
      content = JSON.stringify({
        messages: ["我不会擅自拆信。", "等你回我。"],
        impressionPatch: { summary: "认真回应", affinityDelta: 0 },
      });
    else if (payload.stream)
      content = `“**寄信人姓沈**。”他压低声音：“要上楼谈吗？”\n\n他等着你的答复。\n${mock.protocol}\n${mock.options}`;
    const body = payload.stream
      ? `data: ${JSON.stringify({ choices: [{ delta: { content } }] })}\n\ndata: [DONE]\n\n`
      : JSON.stringify({ choices: [{ message: { content } }] });
    await route.fulfill({
      status: 200,
      contentType: payload.stream ? "text/event-stream" : "application/json",
      headers: { "access-control-allow-origin": "*" },
      body,
    });
  });
  await page.addInitScript((data) => {
    if (window.top !== window) return; // Sandboxed extras never receive fixture storage.
    if (localStorage.getItem("expression_qa_seeded")) return;
    for (const [key, value] of Object.entries(data))
      localStorage.setItem(`flutter.${key}`, JSON.stringify(value));
    localStorage.setItem("expression_qa_seeded", "1");
  }, seed);
  const button = (name) => page.getByRole("button", { name, exact: true });
  const capture = async (name) => {
    await page.waitForTimeout(350);
    await page.screenshot({
      path: path.join(out, `${old ? "v216" : (caseName || theme)}-${width}-${name}.png`),
    });
    fs.writeFileSync(
      path.join(out, `${old ? "v216" : (caseName || theme)}-${width}-${name}.aria.txt`),
      await page.locator("body").ariaSnapshot(),
    );
    fs.writeFileSync(
      path.join(out, `${old ? "v216" : (caseName || theme)}-${width}-${name}.inputs.json`),
      JSON.stringify(
        await page
          .locator("textarea,input")
          .evaluateAll((nodes) =>
            nodes.map((n) => ({
              html: n.outerHTML.slice(0, 300),
              value: n.value,
              active: n === document.activeElement,
            })),
          ),
        null,
        2,
      ),
    );
  };
  await page.goto(
    old
      ? "http://127.0.0.1:8935"
      : process.env.THEATER_QA_URL || "http://127.0.0.1:8938",
  );
  await page
    .locator("flt-glass-pane")
    .waitFor({ state: "attached", timeout: 120000 });
  if (accessibility) {
    if (await page.locator("flt-semantics-placeholder").count())
      await page
        .locator("flt-semantics-placeholder")
        .evaluate((el) => el.click());
    await button("打开未完剧场").waitFor({ timeout: 120000 });
    await button("打开未完剧场").click();
    await button("打开未完剧场").waitFor({ state: "hidden", timeout: 30000 });
  } else {
    // Exercise native embedded HTML with the ordinary pointer surface. Flutter's
    // opt-in test semantics overlay otherwise intercepts iframe pointer events.
    await page.waitForTimeout(10000);
    await page.mouse.click(width / 2, height - 106);
  }
  await page.waitForTimeout(1800); // The curtain exits after its semantics are detached.
  if (accessibility) {
    if (old)
      await page
        .getByText("渡口来信", { exact: true })
        .first()
        .waitFor({ timeout: 120000 });
    else await page.locator("textarea:not([disabled]),input:not([disabled])").last().waitFor({ timeout: 120000 });
  }
  return { page, context, button, capture, errors, requests };
}

async function smoke(browser, config) {
  const session = await open(browser, config);
  const {page, context, button, capture, errors, requests} = session;
  const waitText = async pattern => {
    for(let i=0;i<30;i++){if(pattern.test(await page.locator('body').ariaSnapshot()))return;await page.waitForTimeout(300);}
    assert.match(await page.locator('body').ariaSnapshot(),pattern);
  };
  const input = () => page.locator('textarea:not([disabled]),input:not([disabled])').last();
  const enter = async text => {
    await input().click(); await page.waitForTimeout(450);
    await page.keyboard.type('hello',{delay:80});
    await page.waitForTimeout(350);
    await page.keyboard.press('Control+A'); await page.keyboard.insertText(text);
    await page.waitForTimeout(350);
    const send=page.getByRole('button',{name:/^(发送|发送消息)$/});
    if (await send.isDisabled()) { await input().fill(text); await page.waitForTimeout(350); }
    assert.ok(await send.isEnabled(),'typed draft must enable Send');
  };
  const longPress = async locator => {
    const r = await locator.boundingBox(); assert.ok(r);
    await page.mouse.move(r.x+Math.min(35,r.width/2),r.y+25);
    await page.mouse.down(); await page.waitForTimeout(800); await page.mouse.up();
  };
  try {

    const controls=skinControls[config.theme];
    if (await button(controls.hide).count()) await button(controls.hide).click();
    else if (config.height && config.height<500) {
      await page.getByRole('button',{name:'',exact:true}).first().click();
      await page.getByText(controls.hide,{exact:true}).click();
    }
    if (await button(controls.top).count()) await button(controls.top).click();
    await page.waitForTimeout(400);
    await capture('reading');
    fs.writeFileSync(`${out}/${config.theme}-${config.width}-dom.html`,await page.locator('flt-semantics-host').innerHTML());
    let tree = await page.locator('body').ariaSnapshot();
    if (config.long) {
      assert.match(tree,/旧回合1/); await capture('long-history-top');
      await button('回到底部').click(); await waitText(/先别走/);
      await capture('long-history-latest');
    } else if (config.group) { assert.match(tree,/阿澈/); assert.match(tree,/小舟/); assert.match(tree,/等一等/); }
    else { assert.match(tree,/紫色火漆/); assert.match(tree,/先别走/); assert.match(tree,/阿澈接过/); }
    assert.doesNotMatch(tree,/\*\*先别走\*\*/);
    assert.doesNotMatch(tree,/“先别走|我见过。”/);
    assert.equal(requests.length,0,'display never generates a model request');
    if (config.interact) {
      const bubble = page.getByLabel(/渡口来信\s+灯下的一封信/).last();
      await longPress(bubble);
      await button('接这句').click();
      await page.getByRole('alertdialog').getByText(/先别走，让我想一想/).click();
      await button('取消引用').waitFor(); await capture('quoted');
      await enter('我只问寄信人的姓名，先不答应上楼。');
      await page.getByRole('button',{name:/^(发送|发送消息)$/}).click();
      await button('取消引用').waitFor({state:'hidden'});
      await button('提交并生成回复').click();
      await page.waitForTimeout(1200);
      await button('回到底部').click();
      await waitText(/寄信人姓沈/);
      await capture('generated');
      const main = requests.find(t=>t.includes('我只问寄信人的姓名'));
      assert.ok(main?.includes('【玩家决定权'));
      assert.ok(main?.includes('【本轮实际提交｜玩家行动范围】'));
      assert.ok(main?.includes('Markdown'));
      await button('NPC').click(); await capture('npc-list');
      await page.getByRole('group',{name:/^阿 阿澈/}).click({force:true,position:{x:90,y:35}});
      await capture('npc-thread');
      assert.match(await page.locator('body').ariaSnapshot(), /这枚印章/);
      assert.doesNotMatch(await page.locator('body').ariaSnapshot(), /“这枚印章|我见过。”/);
      await enter('先别拆信，告诉我你认不认识他。');
      await page.getByRole('button',{name:/^(发送|发送消息)$/}).click();
      await button('提交并生成回复').click();
      await waitText(/我不会擅自拆信/);
      await capture('npc-generated');
      assert.ok(requests.some(t=>t.includes('请生成 NPC 对本次消息') && t.includes('【玩家决定权') && t.includes('纯线上聊天') && !t.includes('【剧情正文的 Markdown 表现】')));
      const countBeforeReturn=requests.length;
      await page.getByRole('button',{name:'',exact:true}).first().click();
      await button('对话').click();await waitText(/寄信人姓沈/);
      assert.equal(requests.length,countBeforeReturn);await capture('return-to-story');
    }
    assert.deepEqual(errors,[]);
    return {scenario:config.caseName||`${config.theme}-${config.width}`,theme:config.theme,width:config.width,interact:!!config.interact,passed:true,requests:requests.length,errors};
  } catch(error) {
    await capture('failure');
    return {scenario:config.caseName||`${config.theme}-${config.width}`,theme:config.theme,width:config.width,passed:false,error:error.stack,errors};
  } finally {await context.close();}
}
module.exports={open,launch,skinControls};
if(require.main===module)(async()=>{
  const browser=await launch(); const results=[];
  const configs=process.env.THEATER_SMOKE_ONLY ? [{width:1280,theme:'sakura',interact:process.env.THEATER_SMOKE_ONLY==='journey'}] :
    [{width:1280,theme:'sakura',interact:true},{width:390,theme:'sakura',interact:true},
      ...JSON.parse(fs.readFileSync(`${out}/themes.json`,'utf8')).filter(t=>t!=='sakura').map(theme=>({width:390,theme})),
      {width:320,height:800,theme:'sakura',caseName:'sakura-scaled',prepareSeed(seed){const s=JSON.parse(seed.app_settings);s.uiScale=1.25;seed.app_settings=JSON.stringify(s)}},
      {width:844,height:390,theme:'sakura'},
      {width:390,theme:'cthulhu',caseName:'cthulhu-custom-light',prepareSeed(seed){
        const g=JSON.parse(seed.gamification_state);
        g.customBubbleStyles=[{id:'custom_light',name:'测试白纸',description:'模拟样本',css:'.assistant { background: #ffffff; color: #333333; }',createdAt:'2026-11-21T00:00:00.000',updatedAt:'2026-11-21T00:00:00.000'}];
        g.characterBubbleFrameIds={world:'custom_light'};g.equippedFrameId='custom_light';seed.gamification_state=JSON.stringify(g);
      }},
      {width:390,theme:'sakura',caseName:'long-history',long:true,prepareSeed(seed){
        const h=JSON.parse(seed.history_world),template=h.messages[0];
        h.messages=[...Array.from({length:240},(_,i)=>({...template,id:'old-'+i,role:i%2?'assistant':'user',content:'旧回合'+i+'。'+(i%2?'“**我在这里**。”旁白继续。':'我停下来听他回答。'),quote:null})),...h.messages];seed.history_world=JSON.stringify(h);
      }},
      {width:1280,theme:'mint',caseName:'mint-group',group:true,prepareSeed(seed){
        const cs=JSON.parse(seed.characters);cs.find(c=>c.id==='world').largeGroupChatModeEnabled=true;seed.characters=JSON.stringify(cs);
        const h=JSON.parse(seed.history_world);h.messages.at(-1).content='[GROUP_CHAT]'+JSON.stringify({messages:[
          {id:'g1',type:'message',speaker:'阿澈',speakerId:'a',content:'“**等一等**。”他按住桌上的信。'},
          {id:'g2',type:'message',speaker:'小舟',speakerId:'b',content:'“我去门外看看。”'},
        ]})+'[/GROUP_CHAT]'+mock.protocol;seed.history_world=JSON.stringify(h);
      }}];
  try {for(const config of configs.filter(c=>!process.env.THEATER_QA_CASE || c.caseName===process.env.THEATER_QA_CASE || `${c.theme}-${c.width}`===process.env.THEATER_QA_CASE)){try {results.push(await smoke(browser,config));} catch(error){results.push({theme:config.theme,width:config.width,passed:false,error:error.stack});} console.log(JSON.stringify(results.at(-1)));fs.writeFileSync(`${out}/browser-report${process.env.THEATER_QA_CASE ? "-"+process.env.THEATER_QA_CASE : ""}.json`,JSON.stringify(results,null,2));}}
  finally {await browser.close();}
  fs.writeFileSync(`${out}/browser-report${process.env.THEATER_QA_CASE ? "-"+process.env.THEATER_QA_CASE : ""}.json`,JSON.stringify(results,null,2));
  if(results.some(r=>!r.passed)) process.exitCode=1;
})();
