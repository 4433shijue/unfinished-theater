const assert=require('node:assert/strict');
const fs=require('node:fs');
const {chromium}=require(process.env.THEATER_PLAYWRIGHT_MODULE || 'playwright');
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true});
 const results=[];
 try {
 for(const width of [1100,390]){
  const page=await browser.newPage({viewport:{width,height:950}});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(process.argv[2]||'http://127.0.0.1:8913');
  await page.waitForSelector('flt-glass-pane',{state:'attached'});
  await page.screenshot({path:`build/inline-theater-qa/flutter-incomplete-${width}.png`});
  assert.equal(await page.locator('iframe').count(),0,'unfinished document is not rendered');
  await page.mouse.click(50,16);
  let frame=page.frameLocator('iframe');
  await frame.getByText('散场后的匿名群').waitFor();
  const requests=[];page.on('request',r=>{if(/^https?:/.test(r.url()))requests.push(r.url());});
  await frame.getByRole('button',{name:'谁撤回了消息'}).click();
  await frame.locator('#answer1').waitFor({state:'visible'});
  await frame.getByRole('button',{name:'点开最后一条'}).click();
  await frame.locator('#answer2').waitFor({state:'visible'});
  assert.equal(await frame.locator('#answer1').isVisible(),false);
  await page.screenshot({path:`build/inline-theater-qa/flutter-streaming-${width}.png`});
  const box=await page.locator('iframe').boundingBox();
  // Streaming bubbles intentionally exclude semantics; use the visible toolbar geometry.
  await page.mouse.click(box.x+box.width-85,box.y-24);
  await page.frameLocator('iframe').getByText('散场后的匿名群').waitFor();
  assert.equal(await page.frameLocator('iframe').locator('#answer2').isVisible(),false,'toolbar reset');
  await page.mouse.click(box.x+box.width-119,box.y-24);
  await page.waitForFunction(()=>document.querySelectorAll('iframe').length===2);
  frame=page.frameLocator('iframe').last();
  await frame.getByText('散场后的匿名群').waitFor();
  await frame.getByRole('button',{name:'谁撤回了消息'}).click();
  await frame.locator('#answer1').waitFor({state:'visible'});
  await frame.getByRole('button',{name:'重新看看'}).click();
  assert.equal(await frame.locator('#answer1').isVisible(),false);
  await page.screenshot({path:`build/inline-theater-qa/flutter-fullscreen-${width}.png`});
  await page.mouse.click(width-32,32);
  await page.waitForFunction(()=>document.querySelectorAll('iframe').length===1);
  await page.mouse.click(161,16);
  await page.waitForFunction(()=>document.querySelectorAll('iframe').length===0);
  await page.screenshot({path:`build/inline-theater-qa/flutter-history-${width}.png`});
  await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
  await page.getByRole('button',{name:'展开',exact:true}).click();
  await page.frameLocator('iframe').getByText('散场后的匿名群').waitFor();
  const semantics=await page.locator('body').ariaSnapshot();
  assert.match(semantics,/主线输入次数：0/,'all interactions stay local');
  assert.deepEqual(requests,[],'no requests caused by interactions');
  assert.deepEqual(errors,[]);
  results.push({width,streaming:true,localClicks:true,fullscreen:true,history:true,requests:0});
  await page.close();
 }
 fs.writeFileSync('build/inline-theater-qa/flutter-results.json',JSON.stringify(results,null,2));
 console.log(JSON.stringify(results));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
