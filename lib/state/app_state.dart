import 'package:flutter/material.dart';
import '../services/local_store.dart';

/// App-wide UI settings: theme mode, font scale, auto-download preference.
class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  double _fontScale = 1.0;
  bool _autoDownloadEnabled = false;
  String? _autoDownloadTarget; // 'recent' | 'main' | 'books'

  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  bool get autoDownloadEnabled => _autoDownloadEnabled;
  String? get autoDownloadTarget => _autoDownloadTarget;

  void load() {
    _themeMode =
        LocalStore.getThemeMode() == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _fontScale = LocalStore.getFontScale();
    _autoDownloadEnabled = LocalStore.getAutoDownloadEnabled();
    _autoDownloadTarget = LocalStore.getAutoDownloadTarget();
    notifyListeners();
  }

  Future<void> setDark(bool v) async {
    _themeMode = v ? ThemeMode.dark : ThemeMode.light;
    await LocalStore.setThemeMode(v ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setFontScale(double v) async {
    _fontScale = v.clamp(0.8, 1.6).toDouble();
    await LocalStore.setFontScale(_fontScale);
    notifyListeners();
  }

  Future<void> setAutoDownloadEnabled(bool v) async {
    _autoDownloadEnabled = v;
    await LocalStore.setAutoDownloadEnabled(v);
    if (!v) {
      _autoDownloadTarget = null;
      await LocalStore.setAutoDownloadTarget(null);
    }
    notifyListeners();
  }

  Future<void> setAutoDownloadTarget(String? v) async {
    _autoDownloadTarget = v;
    await LocalStore.setAutoDownloadTarget(v);
    notifyListeners();
  }
}
