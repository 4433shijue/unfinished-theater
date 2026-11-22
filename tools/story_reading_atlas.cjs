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
  '阿澈接过信，拇指在封口上停了一下。柜台后头的水壶响了，他也没回头。过了片刻，他把信挪到灯下，露出火漆边上半枚歪斜的指印。',
  '“我娘封信，总嫌印泥干得慢。”他盯着那枚指印，“她走了六年了。这封信是谁给你的？”',
].join('\n\n');
// Fictional sample choices, not events that have already happened.
const choices=['[CHOICES]','A|告诉阿澈，是北岸的邮差送来的。','B|先问他，小时候有没有替母亲送过信。','C|暂时隐去来处，借灯比对两封信的指印。','D|请他把水壶提下来，让门外偷听的人以为闲谈已经结束。','E|把信翻过来，请他读读背面写给自己的旧名。','F|把空信封贴到耳边，听听里面谁在催着收回那封信。','[/CHOICES]'].join('\n');
const samples=[...ids.map(id=>({id,width:1280,height:960})),{id:'vinyl_memories',width:390,height:1000}];
function seedStory(seed,scale){
  const h=JSON.parse(seed.history_world);
  h.messages.findLast(m=>m.role==='user').content='我把信递给阿澈。';
  h.messages.at(-1).content=[story,mock.protocol,choices].join('\n');
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
          for(const word of ['阿澈接过信','半枚歪斜的指印','这封信是谁给你的'])assert.ok(tree.includes(word),id+': '+word);
          assert.doesNotMatch(tree,/“我娘封信|给你的？”|\*\*广播\*\*/);
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
    const views=[...ids.map(id=>[names[id],id+'-1280']),['黑胶 · 手机','vinyl_memories-390'],['NPC 私聊','npc']];
    const html='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>渡口来信 · 全皮肤试读</title><style>*{box-sizing:border-box}body{margin:0;color:#21322d;background:#f7f9f8;font:16px/1.6 system-ui,sans-serif}header,main{max-width:1120px;margin:auto;padding:12px 20px}header{display:flex;align-items:center;flex-wrap:wrap;gap:12px;background:#fff;border-bottom:1px solid #c6d1c9;position:sticky;top:0}h1{font-size:20px;margin:0;flex:1}select,button{font:inherit;padding:5px}img{display:block;max-width:100%;height:auto;margin:auto}main{padding-top:8px}</style><header><h1>渡口来信 · 正文图册</h1><button id="prev" aria-label="上一套">←</button><select id="s" aria-label="皮肤">'+views.map(([name],i)=>'<option value="'+i+'">'+name+'</option>').join('')+'</select><button id="next" aria-label="下一套">→</button></header><main><img id="shot" alt=""></main><script>const data='+JSON.stringify(views.map(([name,id])=>[name,img(id)]))+';function show(i){s.selectedIndex=(i+data.length)%data.length;shot.src=data[s.selectedIndex][1];shot.alt=data[s.selectedIndex][0];window.scrollTo(0,0)}s.onchange=()=>show(s.selectedIndex);prev.onclick=()=>show(s.selectedIndex-1);next.onclick=()=>show(s.selectedIndex+1);show(0)</script></html>';
    fs.writeFileSync(path.join(out,'index.html'),html);
    fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
    const g=await b.newPage({viewport:{width:390,height:844}});await g.goto(require('node:url').pathToFileURL(path.resolve(out,'index.html')).href);
    for(let j=0;j<views.length;j++){await g.locator('#s').selectOption(String(j));await g.locator('#shot').evaluate(im=>im.decode());}
    assert.ok(await g.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  }finally{await b.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1});
