import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bootstrap_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The app's selection toolbar supplies quote/rewrite. Native web menus create
  // temporary platform views that can outlive recycled long-history rows.
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  runApp(const AppBootstrap());
}
