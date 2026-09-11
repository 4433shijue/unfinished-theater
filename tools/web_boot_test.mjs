import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const html = fs.readFileSync('web/index.html', 'utf8');
const source = html.match(/<script>([\s\S]*?)<\/script>/)[1];
function setup() {
  const elements = new Map();
  const timers = new Map();
  const events = new Map();
  const scripts = [];
  let id = 0;
  const context = {
    console,
    localStorage: {getItem: () => null, setItem: () => {}},
    document: {
      getElementById(key) {
        if (!elements.has(key)) elements.set(key, {style: {}, textContent: '', setAttribute() {}});
        return elements.get(key);
      },
      createElement: () => ({}),
      body: {appendChild: script => scripts.push(script)},
    },
    setTimeout(fn, ms) { timers.set(++id, {fn, ms}); return id; },
    clearTimeout(key) {timers.delete(key);},
    addEventListener(name, fn) {events.set(name, fn);},
  };
  context.window = context;
  vm.runInNewContext(source, context);
  return {context, elements, timers, events, scripts};
}
test('slow loading remains distinct from failure and first frame dismisses overlay', () => {
  const x = setup();
  x.context.theaterBoot.stage('测试阶段');
  [...x.timers.values()].find(t => t.ms === 20000).fn();
  assert.match(x.elements.get('boot-status-message').textContent, /测试阶段.*网络较慢/);
  x.context.theaterBoot.fail('下载失败');
  assert.match(x.elements.get('boot-status-message').textContent, /下载失败/);
  x.context.theaterBoot.stage('不能覆盖错误');
  assert.match(x.elements.get('boot-status-message').textContent, /下载失败/);
  x.events.get('flutter-first-frame')();
  assert.equal(x.elements.get('boot-status').style.display, 'none');
});
test('storage fallback boots once and script network failure exposes retry', async () => {
  const x = setup();
  [...x.timers.values()].find(t => t.ms === 4000).fn();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(x.scripts.length, 1);
  x.scripts[0].onerror();
  assert.match(x.elements.get('boot-status-message').textContent, /启动程序下载失败/);
  assert.equal(x.elements.get('boot-retry').style.display, 'block');
});
test('engine initialization rejection is caught and displayed', async () => {
  const x = setup();
  x.context.console = {error() {}};
  x.context._flutter = {loader: {load: async options => {
    await options.onEntrypointLoaded({initializeEngine: async () => {throw Error('offline');}});
  }}};
  const bootstrap = fs.readFileSync('web/flutter_bootstrap.js', 'utf8').replace(/\{\{flutter_[^}]+\}\}/g, '');
  await vm.runInNewContext(bootstrap, x.context);
  assert.match(x.elements.get('boot-status-message').textContent, /画面初始化失败/);
});
