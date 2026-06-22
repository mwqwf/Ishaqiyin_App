import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

/// Lightweight local cache + settings, backed by SharedPreferences.
/// Replaces the old Realm/AsyncStorage layer (read-only consumer app).
class LocalStore {
  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  // ---------------- generic list cache ----------------
  static List<Map<String, dynamic>> _getList(String key) {
    final s = _p.getString(key);
    if (s == null) return [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _setList(String key, List<Map<String, dynamic>> v) =>
      _p.setString(key, jsonEncode(v));

  static List<Category> getCategories() =>
      _getList('cache_categories').map(Category.fromCache).toList();
  static Future<void> setCategories(List<Category> v) =>
      _setList('cache_categories', v.map((e) => e.toCache()).toList());

  static List<Subcategory> getSubcategories() =>
      _getList('cache_subcategories').map(Subcategory.fromCache).toList();
  static Future<void> setSubcategories(List<Subcategory> v) =>
      _setList('cache_subcategories', v.map((e) => e.toCache()).toList());

  static List<Lesson> getLessons() =>
      _getList('cache_lessons').map(Lesson.fromCache).toList();
  static Future<void> setLessons(List<Lesson> v) =>
      _setList('cache_lessons', v.map((e) => e.toCache()).toList());

  static List<Book> getBooks() =>
      _getList('cache_books').map(Book.fromCache).toList();
  static Future<void> setBooks(List<Book> v) =>
      _setList('cache_books', v.map((e) => e.toCache()).toList());

  // ---------------- downloads index ----------------
  static Map<String, String> _getMap(String key) {
    final s = _p.getString(key);
    if (s == null) return {};
    try {
      final d = jsonDecode(s);
      if (d is Map) {
        return d.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _setMap(String key, Map<String, String> v) =>
      _p.setString(key, jsonEncode(v));

  static Map<String, String> getAudioDownloads() => _getMap('downloads_audio');
  static Future<void> setAudioDownload(String id, String path) async {
    final m = getAudioDownloads()..[id] = path;
    await _setMap('downloads_audio', m);
  }

  static Future<void> removeAudioDownload(String id) async {
    final m = getAudioDownloads()..remove(id);
    await _setMap('downloads_audio', m);
  }

  static Map<String, String> getBookDownloads() => _getMap('downloads_books');
  static Future<void> setBookDownload(String id, String path) async {
    final m = getBookDownloads()..[id] = path;
    await _setMap('downloads_books', m);
  }

  // ---------------- generic int map / string list ----------------
  static Map<String, int> _getIntMap(String key) {
    final s = _p.getString(key);
    if (s == null) return {};
    try {
      final d = jsonDecode(s);
      if (d is Map) {
        return d.map((k, v) =>
            MapEntry(k.toString(), v is int ? v : int.tryParse('$v') ?? 0));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _setIntMap(String key, Map<String, int> v) =>
      _p.setString(key, jsonEncode(v));

  static List<String> _getStringList(String key) {
    final s = _p.getString(key);
    if (s == null) return [];
    try {
      final d = jsonDecode(s);
      if (d is List) return d.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  static Future<void> _setStringList(String key, List<String> v) =>
      _p.setString(key, jsonEncode(v));

  // ---------------- personalization (ON-DEVICE ONLY) ----------------
  // None of the values below ever leave the device. They drive the
  // personalized rows on Home, "continue listening", and similar audio.

  static Map<String, int> getPlayCounts() => _getIntMap('pers_play_counts');
  static Future<void> incrementPlayCount(String id) async {
    final m = getPlayCounts();
    m[id] = (m[id] ?? 0) + 1;
    await _setIntMap('pers_play_counts', m);
  }

  /// Recently played lesson ids, most recent first (capped).
  static List<String> getRecentPlayedIds() =>
      _getStringList('pers_recent_played');
  static Future<void> addRecentPlayed(String id) async {
    final list = getRecentPlayedIds()..remove(id);
    list.insert(0, id);
    if (list.length > 60) list.removeRange(60, list.length);
    await _setStringList('pers_recent_played', list);
  }

  static Map<String, int> getCategoryVisits() => _getIntMap('pers_cat_visits');
  static Future<void> incrementCategoryVisit(String id) async {
    if (id.isEmpty) return;
    final m = getCategoryVisits();
    m[id] = (m[id] ?? 0) + 1;
    await _setIntMap('pers_cat_visits', m);
  }

  static Map<String, int> getSubcategoryVisits() =>
      _getIntMap('pers_sub_visits');
  static Future<void> incrementSubcategoryVisit(String id) async {
    if (id.isEmpty) return;
    final m = getSubcategoryVisits();
    m[id] = (m[id] ?? 0) + 1;
    await _setIntMap('pers_sub_visits', m);
  }

  /// Saved playback position (ms) per lesson, for "continue listening".
  static Map<String, int> getPositions() => _getIntMap('pers_positions');
  static int getPosition(String id) => getPositions()[id] ?? 0;
  static Future<void> setPosition(String id, int ms) async {
    final m = getPositions();
    if (ms <= 0) {
      m.remove(id);
    } else {
      m[id] = ms;
    }
    await _setIntMap('pers_positions', m);
  }

  static List<String> getCompletedIds() => _getStringList('pers_completed');
  static Future<void> markCompleted(String id) async {
    final list = getCompletedIds();
    if (!list.contains(id)) {
      list.add(id);
      await _setStringList('pers_completed', list);
    }
    await setPosition(id, 0);
  }

  /// Debounce the global view counter to one increment per lesson per day,
  /// so a single user replaying a lesson doesn't inflate the count.
  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static Future<bool> shouldCountView(String id) async {
    if (id.isEmpty) return false;
    final m = _getMap('pers_view_counted'); // id -> 'yyyy-m-d'
    if (m[id] == _todayKey()) return false;
    m[id] = _todayKey();
    await _setMap('pers_view_counted', m);
    return true;
  }

  // ---------------- settings ----------------
  static String getThemeMode() => _p.getString('theme_mode') ?? 'light';
  static Future<void> setThemeMode(String v) => _p.setString('theme_mode', v);

  static double getFontScale() => _p.getDouble('font_scale') ?? 1.0;
  static Future<void> setFontScale(double v) => _p.setDouble('font_scale', v);

  static bool getAutoDownloadEnabled() =>
      _p.getBool('auto_dl_enabled') ?? false;
  static Future<void> setAutoDownloadEnabled(bool v) =>
      _p.setBool('auto_dl_enabled', v);

  static String? getAutoDownloadTarget() => _p.getString('auto_dl_target');
  static Future<void> setAutoDownloadTarget(String? v) async {
    if (v == null) {
      await _p.remove('auto_dl_target');
    } else {
      await _p.setString('auto_dl_target', v);
    }
  }
}
