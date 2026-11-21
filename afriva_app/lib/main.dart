import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/disk_cache.dart';
import 'core/theme.dart';
import 'state/settings_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(afrivaOverlayStyle);
  // Load preferences before the first frame so the saved language is used
  // from the start (UI and the first API requests).
  final settings = SettingsState();
  await Future.wait([
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    settings.load(),
    DiskCache.init(),
  ]);
  runApp(AfrivaApp(settings: settings));
}
