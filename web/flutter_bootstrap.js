{{flutter_js}}
{{flutter_build_config}}

(async function () {
  try {
    await _flutter.loader.load({
      config: { canvasKitBaseUrl: 'canvaskit/' },
      onEntrypointLoaded: async function (initializer) {
        try {
          window.theaterBoot.stage('正在加载画面引擎和基础字体');
          const runner = await initializer.initializeEngine();
          window.theaterBoot.stage('正在打开剧场');
          await runner.runApp();
        } catch (error) {
          console.error('Theater engine startup failed', error);
          window.theaterBoot.fail('画面初始化失败');
        }
      }
    });
  } catch (error) {
    console.error('Theater loader failed', error);
    window.theaterBoot.fail('启动程序加载失败');
  }
})();
