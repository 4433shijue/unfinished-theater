const fs=require('node:fs');
const assert=require('node:assert/strict');
const {chromium}=require(process.env.THEATER_PLAYWRIGHT_MODULE||'playwright');
const output='build/story-evolution-qa';
const seed=JSON.parse(fs.readFileSync(`${output}/seed.json`,'utf8'));
const mock=JSON.parse(fs.readFileSync(`${output}/mock.json`,'utf8'));
seed.tutorial_seen=true;seed['release_notice_seen_v2.15.0']=true;
async function run(browser,width){
 const context=await browser.newContext({viewport:{width,height:950},hasTouch:width<600,reducedMotion:'reduce'});
 const page=await context.newPage();const errors=[],requests=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.route('https://example.test/**',async route=>{
  if(route.request().method()==='OPTIONS')return route.fulfill({status:204,headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*'}});
  const payload=route.request().postDataJSON();const text=payload.messages.map(m=>m.content).join('\n');requests.push(text);
  let content='{}';
  if(text.includes('模拟器灵感')||text.includes('结构化开局')){const generated=structuredClone(mock.generated);if(text.includes('本次只调整指定部分 npc:n2'))generated.openingDraft.npcs[1].goal='寻找渡口旧信';content=JSON.stringify(generated);}
  else if(text.includes('结算文字游戏本轮已经发生'))content=JSON.stringify(mock.judgment);
  else if(payload.stream||text.includes('格式')||text.includes('修复'))content=`${mock.narrative}\n[GAME_STATE]${JSON.stringify(mock.judgment.gameState)}[/GAME_STATE]\n[THEATER_PATCH]${JSON.stringify(mock.judgment.gameplayPatch)}[/THEATER_PATCH]`;
  const body=payload.stream?`data: ${JSON.stringify({choices:[{delta:{content}}]})}\n\ndata: [DONE]\n\n`:JSON.stringify({choices:[{message:{content}}]});
  await route.fulfill({status:200,contentType:payload.stream?'text/event-stream':'application/json',headers:{'access-control-allow-origin':'*'},body});
 });
 await page.addInitScript(data=>{if(localStorage.getItem('qa_seeded'))return;for(const [k,v]of Object.entries(data))localStorage.setItem(`flutter.${k}`,JSON.stringify(v));localStorage.setItem('qa_seeded','1');},seed);
 const button=name=>page.getByRole('button',{name,exact:true});
 const fillVisible=async(name,value)=>{
  const field=page.getByRole('textbox',{name,exact:false});
  for(let step=0;step<10;step++){
   const box=await field.boundingBox();
   console.log(width,name,step,box);
   if(box&&box.y>=150&&box.y+box.height<=820)break;
   await page.mouse.move(width/2,600);await page.mouse.wheel(0,box?box.y+box.height/2-470:350);await page.waitForTimeout(400);
  }
  await field.click();await page.waitForTimeout(150);await field.fill(value);await page.waitForTimeout(200);
  assert.equal(await field.inputValue(),value);
  await field.press('Tab');await page.waitForTimeout(150);
 };

 const capture=async name=>{await page.waitForTimeout(400);await page.screenshot({path:`${output}/${width}-${name}.png`});fs.writeFileSync(`${output}/${width}-${name}.aria.txt`,await page.locator('body').ariaSnapshot());};
 const enter=async()=>{await page.locator('flt-glass-pane').waitFor({state:'attached',timeout:120000});await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());await button('打开未完剧场').click();};
 try{
  await page.goto(process.env.THEATER_QA_URL||'http://127.0.0.1:8925');await enter();await page.waitForTimeout(1500);await capture('initial');
  const input=page.getByRole('textbox',{name:width<600?'输入消息...':'输入你的消息，开始和角色对话...',exact:true});
  await input.fill('包扎伤口，再问问渡口的线索。');await button(width<600?'发送消息':'发送').click();await button('提交并生成回复').click();
  await button('继续阅读').waitFor({timeout:60000});await capture('settlement');
  let aria=await page.locator('body').ariaSnapshot();assert.match(aria,/好感/);assert.doesNotMatch(aria,/只有本人知道的暗号|密探3|人物3/);
  await button('继续阅读').click();await page.reload();await enter();await page.waitForTimeout(1200);
  assert.equal(await button('关闭结算').count(),0,'seen settlement must not reopen');
  await capture('reload');await button('角色').click();await capture('characters');
  await button('新建角色').click();await capture('creator');
  await button('帮你写').click();await capture('generator');
  await fillVisible('文游灵感','旧城调查，有各自秘密的旅人。');
  await button('高级设置 长期生效的叙事偏好与指令约束').click();await capture('advanced');
  await button('正文篇幅 长篇 · 2200—3200 字').click();await page.getByRole('menuitem',{name:'短篇 · 600—1000 字',exact:true}).click();
  await button('初始人物数量 AI 决定 · 3—6 人').click();await page.getByRole('menuitem',{name:'3 人',exact:true}).click();
  await fillVisible('额外指令（原样保存）','  不要替我说话。\n请保留我的选择。  ');
  await capture('advanced-filled');await page.mouse.wheel(0,-500);await page.waitForTimeout(300);await button('高级设置 长期生效的叙事偏好与指令约束').click();
  await button('生成提示词').click();await page.getByRole('button',{name:/^人物1 旅人1/}).waitFor({timeout:30000});
  assert.doesNotMatch(await page.locator('body').ariaSnapshot(),/只有本人知道的暗号/);
  await page.getByRole('button',{name:/^人物1 旅人1/}).click();
  await button('作者查看 · 含剧透').click();await capture('author-preview');
  assert.match(await page.locator('body').ariaSnapshot(),/只有本人知道的暗号1/);
  await button('作者查看 · 含剧透').click();await page.getByRole('checkbox',{name:'锁定人物',exact:true}).click();
  assert.equal(await button('重新生成此人').isEnabled(),false);
  await page.getByRole('button',{name:/^人物2 旅人2/}).click();await page.getByRole('button',{name:'重新生成此人',exact:true,disabled:false}).click();
  await page.waitForTimeout(700);await capture('opening-preview');
  if(process.argv.includes('--inspect')){console.log(await page.locator('body').ariaSnapshot());return;}
  await button('创建角色').click();await page.getByRole('alertdialog').waitFor({state:'hidden',timeout:30000});
  const saved=await page.evaluate(async()=>{const raw=await new Promise((resolve,reject)=>{const request=indexedDB.open('wwjc-durable-storage',2);request.onerror=()=>reject(request.error);request.onsuccess=()=>{const db=request.result;const r=db.transaction('preferences','readonly').objectStore('preferences').get('wwjc.flutter.characters');r.onsuccess=()=>{resolve(r.result);db.close();};r.onerror=()=>reject(r.error);};});let value=JSON.parse(raw);return typeof value==='string'?JSON.parse(value):value;});
  const created=saved.find(c=>c.name==='渡口灯影');assert.ok(created);assert.equal(created.advancedSettings.length,'short');
  assert.equal(created.advancedSettings.instructions,'  不要替我说话。\n请保留我的选择。  ');
  assert.equal(created.openingDraft.npcs.length,3);assert.notEqual(created.openingDraft.npcs[0].secretRevealed,true);
  assert.equal(created.openingDraft.npcs[1].goal,'寻找渡口旧信');
  await button('NPC').click();await capture('public-npcs');
  assert.doesNotMatch(await page.locator('body').ariaSnapshot(),/只有本人知道的暗号|密探3|人物3/);

  assert.equal(errors.length,0,errors.join('\n'));return{width,status:'passed',simulatedRequests:requests.length,pageErrors:errors};
 }catch(e){await capture('failure');fs.writeFileSync(`${output}/${width}-requests.json`,JSON.stringify(requests,null,2));throw e;}
 finally{await context.close();}
}
(async()=>{const browser=await chromium.launch({channel:'msedge',headless:true});try{const results=[];for(const width of(process.argv.includes('--inspect')?[1280]:[1280,390]))results.push(await run(browser,width));fs.writeFileSync(`${output}/browser-report.json`,JSON.stringify({realModelCalls:0,results},null,2));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
