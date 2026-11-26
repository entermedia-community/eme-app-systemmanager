import 'package:eme_app_sdk/eme_app_sdk.dart' show DioUtil;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/settings.dart';
import 'router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await DioUtil.init();
  await initSdk(prefs.getString('serverUrl') ?? defaultServerUrl);
  runApp(
    ProviderScope(
      // A failed request shows its error; it is not silently re-sent.
      retry: (_, _) => null,
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const EmeSystemApp(),
    ),
  );
}

class EmeSystemApp extends ConsumerWidget {
  const EmeSystemApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'eMedia Settings',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
