import 'dart:async';

import 'package:flutter/services.dart';

/// Shares downloads across rebuilds and theme switches; failures can be retried.
class ThemeFontService {
  ThemeFontService({Future<void> Function(String, String)? load})
      : _load = load ?? _loadAsset;

  static final instance = ThemeFontService();
  static const assets = <String, String>{
    'FlowerWenDingKai': 'gkai00mp-2.ttf',
    'AbyssSerif': 'SourceHanSerifCN-Regular.otf',
    'AbyssLogo': 'ZhanKuXiaoLOGOTi.otf',
    'RiftSans': 'SourceHanSansSC-Regular.otf',
    'RiftCombat': 'ZiTiChuanQiTeZhanTi.ttf',
    'PastureXiaolai': 'Xiaolai-Regular.ttf',
    'VinylWenkai': 'LXGWWenKai-Regular.ttf',
  };
  final Future<void> Function(String, String) _load;
  final Map<String, Future<void>> _pending = {};
  final Set<String> _loaded = {};

  Future<void> ensure(String family) {
    if (_loaded.contains(family)) return Future.value();
    return _pending.putIfAbsent(family, () => _download(family));
  }

  Future<void> _download(String family) async {
    // Defer so the pending entry exists even if an injected loader throws.
    await Future<void>.delayed(Duration.zero);
    try {
      await _load(family, 'assets/fonts/${assets[family]!}');
      _loaded.add(family);
    } finally {
      _pending.remove(family);
    }
  }

  static Future<void> _loadAsset(String family, String path) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(path));
    await loader.load();
  }
}
