// Run after the story-expression fixture generator, against a local Web build.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {open,launch,skinControls} = require('./story_expression_browser_qa.cjs');
const fixtures = 'build/story-expression-qa';
const out = process.env.THEATER_ATLAS_OUT || 'build/reading-atlas';
const ids = JSON.parse(fs.readFileSync(path.join(fixtures,'themes.json')));
const themeSource = fs.readFileSync('lib/theme/app_theme.dart','utf8');
const names = Object.fromEntries([...themeSource.matchAll(/id: '([^']+)',\s+label: '([^']+)'/g)].map(m=>[m[1],m[2]]));
const mock = JSON.parse(fs.readFileSync(path.join(fixtures,'mock.json')));
const story = [
  '### 渡口来信','风从门缝里钻进来。阿澈用杯底压住信角：“我说的是**明晚**，不是今晚。”',
  '> **来信**\n> 那天江上起了雾，谁也没能看清末班船。那盏灯一直亮到天明。\n>\n> 船票压在第二页。下次再收到我的信，记得先看纸边的水印。',
  '> **纸条**\n> 第二页的水印是一圈涟漪。','---','电话亮了，屏幕上只有一行字。',
  '> **短信**\n> 我到北岸了。','> **广播**\n> 末班渡船即将靠岸。',
  '*外面传来一声很轻的船笛。* 阿澈把信推回灯下。','“你从哪儿拿到的？”',
].join('\n\n');
const samples=[...ids.map(id=>({id,width:1280,height:1500})),{id:'vinyl_memories',width:390,height:1000,scale:1.25}];
function seedStory(seed,scale){
  const h=JSON.parse(seed.history_world);
  h.messages.at(-1).content=[story,mock.protocol,mock.options].join('\n');
  seed.history_world=JSON.stringify(h);
  if(scale)seed.app_settings=JSON.stringify({...JSON.parse(seed.app_settings),uiScale:scale});
}
async function main(){
  fs.mkdirSync(out,{recursive:true});
  const b=await launch(),report=[];
  try{
    let i=0;async function worker(){
      while(i<samples.length){
        const {id,width,height,scale}=samples[i++];
        const s=await open(b,{theme:id,width,height,prepareSeed:seed=>seedStory(seed,scale)});
        try{
          const {page,button}=s,controls=skinControls[id];
          const hide=button(controls.hide);if(await hide.count())await hide.click();
          const top=page.getByRole('button',{name:controls.top}).first();if(await top.count())await top.click();
          await page.mouse.move(1,1);await page.waitForTimeout(700);
          const tree=await page.locator('body').ariaSnapshot();
          for(const word of ['水印','北岸','末班渡船','你从哪儿拿到的'])assert.ok(tree.includes(word),id+': '+word);
          assert.doesNotMatch(tree,/“我说的是|\*\*广播\*\*/);
          await page.screenshot({path:path.join(out,id+'-'+width+'.png')});
          if(width===1280 && id==='sakura'){
            await button('NPC').click();const contact=page.getByRole('group',{name:/^阿 阿澈/}).first();
            await contact.waitFor();await page.waitForTimeout(650);
            await contact.click({force:true,position:{x:90,y:35}});await page.waitForTimeout(750);
            let npc=await page.locator('body').ariaSnapshot();
            if(!npc.includes('我听见了') && await contact.count()){await contact.click({force:true,position:{x:90,y:35}});await page.waitForTimeout(600);}
            await page.setViewportSize({width:390,height:844});await page.waitForTimeout(450);npc=await page.locator('body').ariaSnapshot();
            assert.match(npc,/我听见了/);assert.match(npc,/这枚印章，我见过/);assert.doesNotMatch(npc,/“这枚印章|\*\*|末班渡船/);
            await page.screenshot({path:path.join(out,'npc.png')});
          }
          assert.deepEqual(s.errors,[]);assert.equal(s.requests.length,0);
          report.push({id,width,scale:scale||1});console.log('OK '+id+' '+width);
        }finally{await s.context.close();}
      }
    }
    await Promise.all([worker(),worker(),worker()]);
    const img=(name)=>'data:image/png;base64,'+fs.readFileSync(path.join(out,name+'.png')).toString('base64');
    const views=[...ids.map(id=>[names[id],id+'-1280']),['黑胶 · 手机大字号','vinyl_memories-390'],['NPC 私聊','npc']];
    const html='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>渡口来信 · 全皮肤试读</title><style>*{box-sizing:border-box}body{margin:0;color:#21322d;background:#f7f9f8;font:16px/1.6 system-ui,sans-serif}header,main{max-width:1120px;margin:auto;padding:12px 20px}header{display:flex;align-items:center;flex-wrap:wrap;gap:12px;background:#fff;border-bottom:1px solid #c6d1c9;position:sticky;top:0}h1{font-size:20px;margin:0;flex:1}select,button{font:inherit;padding:5px}img{display:block;max-width:100%;height:auto;margin:auto}main{padding-top:8px}</style><header><h1>渡口来信 · 正文图册</h1><button id="prev" aria-label="上一套">←</button><select id="s" aria-label="皮肤">'+views.map(([name],i)=>'<option value="'+i+'">'+name+'</option>').join('')+'</select><button id="next" aria-label="下一套">→</button></header><main><img id="shot" alt=""></main><script>const data='+JSON.stringify(views.map(([name,id])=>[name,img(id)]))+';function show(i){s.selectedIndex=(i+data.length)%data.length;shot.src=data[s.selectedIndex][1];shot.alt=data[s.selectedIndex][0];window.scrollTo(0,0)}s.onchange=()=>show(s.selectedIndex);prev.onclick=()=>show(s.selectedIndex-1);next.onclick=()=>show(s.selectedIndex+1);show(0)</script></html>';
    fs.writeFileSync(path.join(out,'index.html'),html);
    fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
    const g=await b.newPage({viewport:{width:390,height:844}});await g.goto(require('node:url').pathToFileURL(path.resolve(out,'index.html')).href);
    for(let j=0;j<views.length;j++){await g.locator('#s').selectOption(String(j));await g.locator('#shot').evaluate(im=>im.decode());}
    assert.ok(await g.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  }finally{await b.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1});
