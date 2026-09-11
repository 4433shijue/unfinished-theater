import 'dart:async';

import 'package:flutter/material.dart';

import '../services/theme_font_service.dart';
import '../theme/app_theme.dart';

/// Paints the app first. Decorative font downloads never gate startup.
class ThemeFontLoader extends StatefulWidget {
  const ThemeFontLoader(
      {super.key, required this.themeId, required this.child});
  final String themeId;
  final Widget child;

  @override
  State<ThemeFontLoader> createState() => _ThemeFontLoaderState();
}

class _ThemeFontLoaderState extends State<ThemeFontLoader> {
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ThemeFontLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeId != widget.themeId) _schedule();
  }

  void _schedule() {
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) unawaited(_load(generation));
    });
  }

  Future<void> _load(int generation) async {
    setState(() => _failed = false);
    final variant = AppTheme.describeTheme(widget.themeId).baseVariant;
    final families = <String>{
      'FlowerWenDingKai', // Opening curtain, shared by every theme.
      if (variant.isEldritch || variant.isBasicPalette || variant.isVinyl)
        'AbyssSerif',
      if (variant.isEldritch) 'AbyssLogo',
      if (variant.isTerminal) ...['RiftSans', 'RiftCombat'],
      if (variant.isPasture) 'PastureXiaolai',
      if (variant.isVinyl) 'VinylWenkai',
    };
    try {
      await Future.wait(families.map(ThemeFontService.instance.ensure))
          .timeout(const Duration(seconds: 45));
      if (mounted && generation == _generation) setState(() => _failed = false);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_failed)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF6F1F5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        const Expanded(
                          child: Text('部分主题字体未加载，暂用基础字体，不影响游玩。',
                              style: TextStyle(color: Color(0xFF403747))),
                        ),
                        TextButton(
                            onPressed: _schedule, child: const Text('重试')),
                        IconButton(
                          tooltip: '关闭提示',
                          onPressed: () => setState(() => _failed = false),
                          icon: const Icon(Icons.close),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
