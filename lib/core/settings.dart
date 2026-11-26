import 'package:eme_app_sdk/eme_app_sdk.dart' show OpenI;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

const defaultServerUrl = 'http://localhost:8080';

Map<String, dynamic> _sdkSettings(String serverUrl) => {
  'mediadb': '$serverUrl/site/mediadb',
  'siteroot': serverUrl,
  'catalogid': 'site/catalog',
};

/// Points the SDK (which signs in and signs requests) at [serverUrl].
Future<void> initSdk(String serverUrl) =>
    OpenI().initialize(_sdkSettings(serverUrl));

class AppSettings {
  const AppSettings({
    required this.serverUrl,
    required this.themeMode,
    this.language = 'en',
  });

  /// Server root, e.g. http://localhost:8080 (no trailing slash).
  final String serverUrl;
  final ThemeMode themeMode;
  final String language;

  AppSettings copyWith({
    String? serverUrl,
    ThemeMode? themeMode,
    String? language,
  }) => AppSettings(
    serverUrl: serverUrl ?? this.serverUrl,
    themeMode: themeMode ?? this.themeMode,
    language: language ?? this.language,
  );
}

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() {
    final theme = _prefs.getString('themeMode');
    return AppSettings(
      serverUrl: _prefs.getString('serverUrl') ?? defaultServerUrl,
      // Dark is the default look; light is opt-in.
      themeMode: theme == 'light' ? ThemeMode.light : ThemeMode.dark,
      language: _prefs.getString('language') ?? 'en',
    );
  }

  void setServerUrl(String url) {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.isEmpty) clean = defaultServerUrl;
    _prefs.setString('serverUrl', clean);
    OpenI.instance?.updateSettings(_sdkSettings(clean));
    state = state.copyWith(serverUrl: clean);
  }

  void toggleTheme() {
    final next = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    _prefs.setString('themeMode', next == ThemeMode.dark ? 'dark' : 'light');
    state = state.copyWith(themeMode: next);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
