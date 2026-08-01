import 'package:flutter/material.dart';
import '../services/local_store.dart';

/// App-wide UI settings: theme mode, font scale, auto-download preference.
class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  double _fontScale = 1.0;
  bool _autoDownloadEnabled = false;
  String? _autoDownloadTarget; // 'recent' | 'main'

  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  bool get autoDownloadEnabled => _autoDownloadEnabled;
  String? get autoDownloadTarget => _autoDownloadTarget;

  void load() {
    _themeMode = _parseThemeMode(LocalStore.getThemeMode());
    _fontScale = LocalStore.getFontScale();
    _autoDownloadEnabled = LocalStore.getAutoDownloadEnabled();
    _autoDownloadTarget = LocalStore.getAutoDownloadTarget();
    notifyListeners();
  }

  static ThemeMode _parseThemeMode(String v) {
    switch (v) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  /// يضبط وضع السمة بأحد الخيارات الثلاثة: فاتح/داكن/اتّباع النظام.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final s = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.system
            ? 'system'
            : 'light';
    await LocalStore.setThemeMode(s);
    notifyListeners();
  }

  Future<void> setDark(bool v) =>
      setThemeMode(v ? ThemeMode.dark : ThemeMode.light);

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
