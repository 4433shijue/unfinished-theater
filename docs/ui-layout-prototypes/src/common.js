'use strict';
(() => {
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const layout = document.body.dataset.layout;
  const storageKey = `unfinished-theater-layout-demo:${layout}:`;
  const read = (key, fallback = '') => { try { return localStorage.getItem(storageKey + key) ?? fallback; } catch { return fallback; } };
  const save = (key, value) => { try { localStorage.setItem(storageKey + key, value); return true; } catch { return false; } };
  const escape = text => String(text).replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const choices = [
    [
      ['顺着线索', '拆开信，读出那个被划掉的名字。', '你把信纸展平。被墨水遮住的名字，竟然是阿澈的旧姓。他没有阻止，只把灯向你推近了一点。'],
      ['靠近一个人', '先握住阿澈冰冷的手，问他在怕什么。', '你没有碰那封信，只握住他的手。阿澈紧绷的肩慢慢松下来。「我怕你知道以后，就再也不肯和我走了。」'],
      ['换一笔筹码', '把信交给摆渡人，换一次午夜渡河。', '摆渡人接过信，指节在信封上敲了两下。「一封信只能换一个座位。你们两个，谁先上船？」'],
      ['另找入口', '折返钟楼，找到寄信前一夜的值守记录。', '你带着阿澈折返钟楼。值守簿上，昨夜的记录被整页撕走，背面却留下了一个陌生的掌印。'],
      ['倒转局面', '当着所有人的面，宣称这封信是你写的。', '码头忽然安静了。一个始终背对着你的女人转过身：「原来是你。那你应该知道，我们为什么等了七年。」'],
      ['异想天开 🐟', '把信折成小船，请码头的鱼担任邮差。', '纸船刚碰到水面，一条银鱼便顶住船底。它吐出一枚写着「邮资不足」的铜钱，阿澈看你的眼神顿时复杂起来。']
    ],
    [
      ['求一个证据', '把信纸举向灯，寻找藏在背面的水印。', '暖光穿过纸页，浮出一张旧渡口的地图。终点被圈在河的中央，那里本不该有任何陆地。'],
      ['把心交出去', '把伞偏向阿澈，请他陪你一起读完。', '阿澈往伞下挪了一步。这一次，他没有躲开你的目光。你们挨着肩，念出了第一行。'],
      ['借别人的力', '用欠下的一次人情，请巡夜人封锁码头。', '巡夜人的哨声划破雨夜。最后一班渡船停在水中央，船尾却多出了一个你没见过的影子。'],
      ['追另一条线', '暂放下信，追查一直响个不停的空电话亭。', '电话亭里没有人。你拿起听筒，对面传来的却是你自己的声音：「千万别拆信。」'],
      ['把秘密公开', '借港口广播，念出信封上的禁用暗号。', '暗号响起的瞬间，所有船灯同时熄灭。黑暗里有人轻轻鼓掌，像是等你完成了某个仪式。'],
      ['离谱的念头 🦆', '给路过的鸭子封个邮政局长，让它主持拆信。', '鸭子踩住信封，郑重地叫了三声。摆渡人竟摘下帽子鞠了一躬：「局长，您终于回来了。」']
    ]
  ];
  const initialPages = [
    {speaker:'旁白', note:'夜雨 / 港口', direction:'雨沿着棚檐落下来，整条河像一封没有写完的信。', line:'阿澈没有看信。他先看了看你，又看向远处迟迟不肯靠岸的船。'},
    {speaker:'阿澈', note:'把声音藏进雨里', direction:'他的指尖按住信封一角，像按住一个快要说出口的秘密。', line:'「如果这封信，是明天的你寄来的呢？」'},
    {speaker:'旁白', note:'一个决定之前', direction:'远处传来第三声汽笛。末班船就要走了。', line:'灯下的墨迹正在慢慢洇开。你可以拆开它，也可以先握住那只一直没松开的手。'}
  ];
  const pages = initialPages.map(page => ({...page}));
  let pageIndex = 0;
  let choiceSet = 0;
  let quote = '';
  let toastTimer;
  let lastDraft = null;
  let activePerson = '阿澈';
  const selected = new Set();
  const directorPreferences = new Set();
  const privateChats = { '阿澈': [{who:'阿澈', text:'你刚才看我的时候，是不是有话想说？'}], '摆渡人': [{who:'摆渡人', text:'离开船还有一会儿。想问什么，就问吧。'}] };

  $$('[data-mount=choices]').forEach(mount => mount.append($('#choice-template').content.cloneNode(true)));
  $$('[data-mount=composer]').forEach(mount => mount.append($('#composer-template').content.cloneNode(true)));
  const composer = $('.composer');
  const input = $('#message');
  const drawer = $('#drawer');
  const routeDialog = $('#route-dialog');
  const themePicker = $('.skin-picker');
  const knownSkins = ['rain_radio', 'flower_not_flower', 'vinyl_memories'];
  const storedSkin = read('skin', document.body.dataset.skin);
  if (knownSkins.includes(storedSkin)) document.body.dataset.skin = storedSkin;
  themePicker.value = document.body.dataset.skin;
  themePicker.addEventListener('change', () => {
    document.body.dataset.skin = themePicker.value;
    save('skin', themePicker.value);
    notify(`已切换为${themePicker.selectedOptions[0].textContent}，布局不变`);
  });

  function notify(message) {
    clearTimeout(toastTimer);
    $('#toast').textContent = message;
    $('#toast').classList.add('visible');
    toastTimer = setTimeout(() => $('#toast').classList.remove('visible'), 2700);
  }

  function renderChoices() {
    $('.choice-grid').innerHTML = choices[choiceSet].map(([tag, description], index) => `<button type="button" class="choice" data-choice="${index}" aria-pressed="${selected.has(index)}"><span class="choice-letter">${'ABCDEF'[index]}</span><span class="choice-copy"><span class="choice-tag">${escape(tag)}</span><span class="choice-desc">${escape(description)}</span></span><span class="choice-check" aria-hidden="true">✓</span></button>`).join('');
    renderSelected();
  }

  function renderSelected() {
    $('.selected-chips').innerHTML = [...selected].map(index => `<button type="button" class="selected-chip" data-remove="${index}" aria-label="移除 ${'ABCDEF'[index]} ${escape(choices[choiceSet][index][0])}">${'ABCDEF'[index]} · ${escape(choices[choiceSet][index][0])} ×</button>`).join('');
    $('.selection-count').textContent = selected.size ? `已选 ${selected.size} 条 · 可以组合，也可以补充` : '可多选，也可以自己写';
    $$('.choice').forEach(button => button.setAttribute('aria-pressed', String(selected.has(Number(button.dataset.choice)))));
  }

  function setQuote(value) {
    quote = value;
    $('.quote-preview').hidden = !value;
    $('.quote-text').textContent = value;
  }

  function focusComposer() {
    if (routeDialog && matchMedia('(max-width:760px)').matches && !routeDialog.open) routeDialog.showModal();
    if (layout === 'journal') composer.scrollIntoView({behavior:'smooth', block:'center'});
    input.focus({preventScroll:true});
  }

  function openPanel(kind) {
    const title = $('#drawer-title');
    const content = $('#drawer-content');
    const panels = {
      people: ['此刻，在你身边', `<p>故事停在这里。和一个人说几句话，再回到雨里的港口。</p><div class="panel-stack"><button class="person" data-person="阿澈"><span class="avatar">澈</span><span><strong>阿澈</strong><small>同行者 · 有话没说完</small></span><span class="arrow">↗</span></button><button class="person" data-person="摆渡人"><span class="avatar">渡</span><span><strong>摆渡人</strong><small>码头 · 正在等最后一位乘客</small></span><span class="arrow">↗</span></button></div><p style="margin-top:25px">点一个名字，打开这段故事里的私聊。</p>`],
      notes: ['把念头留在这里', `<p>记下一个猜测、一句喜欢的话，或者暂时不想让角色知道的心事。</p><label class="sr-only" for="private-note">这段故事的私人手记</label><textarea id="private-note" class="note-area" placeholder="比如：阿澈似乎认识那封信上的笔迹…"></textarea><div class="panel-footer"><span class="small-label">只保存在此浏览器的原型里</span><button class="skin-button" data-action="save-note"><span>收好手记 ✓</span></button></div>`],
      chapters: ['翻到哪一幕', `<p>几段走过的路。点开可以回看，再接着走。</p><button class="chapter-entry" data-chapter="0"><span>第五幕 · 昨夜</span>钟楼里没有第二个人</button><button class="chapter-entry" data-chapter="1"><span>第六幕 · 傍晚</span>一把多出来的伞</button><button class="chapter-entry active" data-chapter="2"><span>第七幕 · 正在继续</span>雨停之前</button>`],
      map: ['雨夜里的几处灯', `<p>这一幕里可以去的地方。离开码头，就会错过这班船。</p><div class="map-stop active"><span class="map-node"></span><div>港口<small>你在这里 · 阿澈、摆渡人</small></div></div><div class="map-stop"><span class="map-node"></span><div>旧钟楼<small>步行十五分钟 · 值守记录的线索</small></div></div><div class="map-stop"><span class="map-node"></span><div>河对岸<small>只剩一班船 · 来信的地址</small></div></div><button class="panel-option" data-draft="我决定先去旧钟楼，查一查寄信前夜的值守记录。" style="width:100%;margin-top:20px">把「去旧钟楼」写进草稿 ↗</button>`],
      tools: ['给故事一点灵感 ✧', `<p>先放进草稿，你可以改成自己的话。</p><div class="panel-stack"><button class="panel-option" data-draft="我没有急着拆信，只轻轻按住阿澈的手，等他把没说完的话说完。">替我表达 · 温柔一点<small>保留靠近他的意思，把动作写得更细。</small></button><button class="panel-option" data-draft="我把信推到阿澈面前，盯住他的眼睛：这次，别再替我做决定。">替我表达 · 更有锋芒<small>让你的追问更直接。</small></button><button class="panel-option" data-action="undo-draft">撤回刚才的润色<small>恢复使用灵感前的草稿。</small></button></div><div class="line-rule"></div><h3 style="margin-bottom:15px">这一幕的节奏</h3><div class="director-tags"><button data-director="让关系慢一点" aria-pressed="false">让关系慢一点</button><button data-director="增加一点悬念" aria-pressed="false">增加一点悬念</button><button data-director="多写动作细节" aria-pressed="false">多写动作细节</button></div><p class="small-label" style="margin-top:15px">原型只演示偏好的选择状态。</p>`],
      fullstory: ['这一幕，完整读一遍', `<div class="prose">${pages.map(p => `<p>${escape(p.direction)}</p><p>${escape(p.line)}</p>`).join('')}</div>`],
      about: ['换个视角，继续故事', `<div class="about-number">0${{scene:1,journal:2,stage:3}[layout]}</div><p>${{scene:'故事现场。正文、选择和输入形成一条很短的操作路径；其余内容留在侧边，点开再看。',journal:'小说手账。左页读故事，右页写下一步；手机上自然叠成上下两页，用底部书签跳转。',stage:'舞台剧场。先看场景，再逐段读对白；桌面在右侧选路线，手机把路线收进底部抽屉。'}[layout]}</p><div class="about-details">独立 HTML 原型 · 不连接 AI<br>三套均可切换雨巷电台、花非花、黑胶往事。背景和按钮使用项目现有原图。<br><br>试试选两条路线、引用一句话、给阿澈留句话，再接着写。手记和皮肤会保存在当前浏览器；故事演示刷新后重新开始。</div>`]
    };
    const panel = panels[kind] || panels.about;
    title.textContent = panel[0];
    content.innerHTML = panel[1];
    if (kind === 'notes') $('#private-note').value = read('note');
    if (kind === 'tools') $$('[data-director]').forEach(button => button.setAttribute('aria-pressed', String(directorPreferences.has(button.dataset.director))));
    if (!drawer.open) drawer.showModal();
  }

  function openPrivate(person) {
    activePerson = person;
    $('#drawer-title').textContent = `和${person}说几句话`;
    $('#drawer-content').innerHTML = `<button class="text-button" data-panel="people">← 回到人物</button><p class="small-label" style="margin:12px 0 22px">此处为本地私聊演示，主线仍停在港口。</p><div class="private-log" aria-live="polite"></div><form class="private-form"><label class="sr-only" for="private-message">给${escape(person)}的消息</label><textarea id="private-message" placeholder="只对${escape(person)}说…" maxlength="2000" required></textarea><button type="submit" class="skin-button"><span>悄悄说 ↗</span></button></form><button class="text-button" data-close="drawer" style="width:100%;margin-top:15px">回到主线，继续读 ↓</button>`;
    renderPrivate();
    if (!drawer.open) drawer.showModal();
  }

  function renderPrivate() {
    $('.private-log').innerHTML = privateChats[activePerson].map(message => `<div class="private-message ${message.who === '你' ? 'mine' : ''}"><span class="private-name">${escape(message.who)}</span>${escape(message.text)}</div>`).join('');
  }

  function renderStage() {
    if (layout !== 'stage') return;
    const page = pages[pageIndex];
    $('#speaker-name').textContent = page.speaker;
    $('#speaker-note').textContent = page.note;
    $('#speaker-avatar').textContent = page.speaker === '阿澈' ? '澈' : '叙';
    $('#stage-line').innerHTML = `<span class="stage-direction">${escape(page.direction)}</span>${page.speaker === '阿澈' ? '<blockquote>' : '<span>'}${escape(page.line)}${page.speaker === '阿澈' ? '</blockquote>' : '</span>'}`;
    $('#page-counter').textContent = `${pageIndex + 1} / ${pages.length}`;
    $('[data-action=prev-page]').disabled = pageIndex === 0;
    $('[data-action=next-page]').disabled = pageIndex === pages.length - 1;
    $('.page-dots').innerHTML = pages.map((_, index) => `<button class="page-dot ${index === pageIndex ? 'active' : ''}" data-page="${index}" aria-label="第 ${index + 1} 段" ${index === pageIndex ? 'aria-current="step"' : ''}></button>`).join('');
  }

  document.addEventListener('click', event => {
    const button = event.target.closest('button');
    if (!button) return;
    if (button.dataset.panel) return openPanel(button.dataset.panel);
    if (button.dataset.close) return $(`#${button.dataset.close}`).close();
    if (button.dataset.person) return openPrivate(button.dataset.person);
    if (button.dataset.choice !== undefined) {
      const index = Number(button.dataset.choice);
      selected.has(index) ? selected.delete(index) : selected.add(index);
      return renderSelected();
    }
    if (button.dataset.remove !== undefined) {
      selected.delete(Number(button.dataset.remove));
      return renderSelected();
    }
    if (button.dataset.page !== undefined) { pageIndex = Number(button.dataset.page); return renderStage(); }
    if (button.dataset.chapter !== undefined) {
      const index = Number(button.dataset.chapter);
      if (index === 2) return drawer.close();
      const text = index === 0 ? '钟楼里只有一只停在十一点四十七分的旧钟。你在值守桌下找到半枚蜡封，形状和今晚的信封一模一样。' : '阿澈在街角把伞递给你，却说自己并不怕雨。你转身以后，才发现他的袖口已经湿透了。';
      $('#drawer-title').textContent = index === 0 ? '第五幕 · 钟楼' : '第六幕 · 一把伞';
      $('#drawer-content').innerHTML = `<div class="prose"><p>${text}</p></div><div class="line-rule"></div><button class="text-button" data-panel="chapters">← 回到章节</button><button class="text-button" data-close="drawer" style="float:right">回到第七幕 →</button>`;
      return;
    }
    if (button.dataset.director) {
      const on = button.getAttribute('aria-pressed') !== 'true';
      on ? directorPreferences.add(button.dataset.director) : directorPreferences.delete(button.dataset.director);
      button.setAttribute('aria-pressed', String(on));
      notify(on ? `已选偏好：${button.dataset.director}` : '已取消这个偏好');
      return;
    }
    if (button.dataset.draft) {
      lastDraft = input.value;
      input.value = button.dataset.draft;
      drawer.close();
      focusComposer();
      notify('已放入草稿，改成你自己的话也可以');
      return;
    }
    switch (button.dataset.action) {
      case 'reroll':
        choiceSet = 1 - choiceSet; selected.clear(); renderChoices(); notify('换了六个方向，正文仍留在这里'); break;
      case 'quote':
        setQuote(layout === 'stage' ? pages[pageIndex].line : '如果这封信，是明天的你寄来的呢？'); focusComposer(); notify('已引用这句话'); break;
      case 'clear-quote': setQuote(''); break;
      case 'save-note': {
        const saved = save('note', $('#private-note').value);
        notify(saved ? '收好了，下次打开这套原型还能看见 📝' : '浏览器未允许本地保存，请先复制手记');
        if (saved) drawer.close();
        break;
      }
      case 'undo-draft':
        if (lastDraft === null) return notify('还没有需要撤回的润色');
        input.value = lastDraft; lastDraft = null; drawer.close(); focusComposer(); notify('已恢复原来的草稿'); break;
      case 'font': document.body.classList.toggle('large-reading'); notify(document.body.classList.contains('large-reading') ? '字号已调大' : '已恢复原字号'); break;
      case 'respond': focusComposer(); break;
      case 'open-routes': if (routeDialog && !routeDialog.open) routeDialog.showModal(); break;
      case 'prev-page': pageIndex = Math.max(0, pageIndex - 1); renderStage(); break;
      case 'next-page': pageIndex = Math.min(pages.length - 1, pageIndex + 1); renderStage(); break;
    }
  });

  document.addEventListener('submit', event => {
    event.preventDefault();
    if (event.target.matches('.private-form')) {
      const value = $('#private-message').value.trim();
      if (!value) return;
      privateChats[activePerson].push({who:'你', text:value}, {who:activePerson, text:activePerson === '阿澈' ? '嗯，我在听。等这场雨小一点，我们再慢慢说。' : '你这话，我记下了。河上的事，急不得。'});
      $('#private-message').value = '';
      renderPrivate();
      $('.private-log').lastElementChild.scrollIntoView({behavior:'smooth', block:'nearest'});
      return;
    }
    if (!event.target.matches('.composer')) return;
    const text = input.value.trim();
    if (!selected.size && !text) { notify('先写一句，或者选一条想走的路'); input.focus(); return; }
    const selectedIndexes = [...selected];
    const action = [...selectedIndexes.map(index => choices[choiceSet][index][1]), text].filter(Boolean).join(' ');
    const reply = selectedIndexes.length ? selectedIndexes.map(index => choices[choiceSet][index][2]).join('\n\n') : '阿澈听完你的话，迟疑了一瞬，终于把手从信封上移开。「那这一次，我跟着你走。」远处的船灯轻轻晃了一下。';
    if (layout === 'stage') {
      pages.push({speaker:'旁白', note:'新的回应 / 本地示例', direction:`你 · ${action}`, line:reply});
      pageIndex = pages.length - 1;
      renderStage();
    } else {
      const turn = document.createElement('section');
      turn.className = 'new-turn';
      turn.innerHTML = `${quote ? `<div class="small-label" style="margin-bottom:12px">↳ ${escape(quote)}</div>` : ''}<p class="player-line">${escape(action)}</p>${reply.split('\n\n').map(paragraph => `<p>${escape(paragraph)}</p>`).join('')}<div class="reply-actions"><span>本地演示 · 这一页由你续上</span></div>`;
      $('#new-turns').append(turn);
      turn.scrollIntoView({behavior:'smooth', block:'start'});
    }
    input.value = ''; selected.clear(); setQuote(''); renderSelected();
    if (routeDialog?.open) routeDialog.close();
    notify('已接上一段本地示例 ✨');
  });

  input.addEventListener('keydown', event => {
    if (event.key === 'Enter' && (event.ctrlKey || event.metaKey) && !event.isComposing) {
      event.preventDefault(); composer.requestSubmit();
    }
  });
  [drawer, routeDialog].filter(Boolean).forEach(dialog => {
    dialog.addEventListener('click', event => {
      if (event.target !== dialog) return;
      const rect = dialog.getBoundingClientRect();
      if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) dialog.close();
    });
  });
  if (layout === 'stage') {
    const query = matchMedia('(max-width:760px)');
    const response = $('.stage-response');
    const relocate = () => {
      if (routeDialog.open) routeDialog.close();
      (query.matches ? $('#mobile-response') : $('#desktop-response')).append(response);
    };
    query.addEventListener('change', relocate);
    relocate();
    renderStage();
  }
  renderChoices();
})();
