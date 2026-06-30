import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

/// Lightweight local cache + settings, backed by SharedPreferences.
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

  /// Last successful Firestore sync timestamp (ms since epoch).
  static int getLastSyncMs() => _p.getInt('cache_last_sync_ms') ?? 0;
  static Future<void> setLastSyncMs(int v) =>
      _p.setInt('cache_last_sync_ms', v);

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
  static Map<String, int> getPlayCounts() => _getIntMap('pers_play_counts');
  static Future<void> incrementPlayCount(String id) async {
    final m = getPlayCounts();
    m[id] = (m[id] ?? 0) + 1;
    await _setIntMap('pers_play_counts', m);
  }

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
    await recordDailyListen();
  }

  /// Cached audio duration per lesson (ms), computed on first play.
  static Map<String, int> getDurations() => _getIntMap('pers_durations');
  static int getDurationMs(String id) => getDurations()[id] ?? 0;
  static Future<void> setDurationMs(String id, int ms) async {
    if (id.isEmpty || ms <= 0) return;
    final m = getDurations();
    m[id] = ms;
    await _setIntMap('pers_durations', m);
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static Future<bool> shouldCountView(String id) async {
    if (id.isEmpty) return false;
    final m = _getMap('pers_view_counted');
    if (m[id] == _todayKey()) return false;
    m[id] = _todayKey();
    await _setMap('pers_view_counted', m);
    return true;
  }

  // ---------------- favorites ----------------
  static List<String> getFavoriteIds() => _getStringList('pers_favorites');
  static bool isFavorite(String id) => getFavoriteIds().contains(id);
  static Future<void> toggleFavorite(String id) async {
    final list = getFavoriteIds();
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.insert(0, id);
    }
    await _setStringList('pers_favorites', list);
  }

  // ---------------- search history ----------------
  static List<String> getSearchHistory() => _getStringList('pers_search_hist');
  static Future<void> addSearchQuery(String q) async {
    final trimmed = q.trim();
    if (trimmed.length < 2) return;
    final list = getSearchHistory()..remove(trimmed);
    list.insert(0, trimmed);
    if (list.length > 20) list.removeRange(20, list.length);
    await _setStringList('pers_search_hist', list);
  }
  static Future<void> clearSearchHistory() async =>
      _p.remove('pers_search_hist');

  // ---------------- playlists (ON-DEVICE ONLY) ----------------
  static List<Playlist> getPlaylists() {
    final s = _p.getString('pers_playlists');
    if (s == null) return [];
    try {
      final d = jsonDecode(s);
      if (d is List) {
        return d
            .whereType<Map>()
            .map((e) => Playlist.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _savePlaylists(List<Playlist> v) =>
      _p.setString('pers_playlists', jsonEncode(v.map((e) => e.toJson()).toList()));

  static Future<Playlist> createPlaylist(String name) async {
    final list = getPlaylists();
    final p = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'قائمة' : name.trim(),
      lessonIds: [],
      createdAt: DateTime.now(),
    );
    list.insert(0, p);
    await _savePlaylists(list);
    return p;
  }

  static Future<void> deletePlaylist(String id) async {
    final list = getPlaylists()..removeWhere((p) => p.id == id);
    await _savePlaylists(list);
  }

  static Future<void> renamePlaylist(String id, String name) async {
    final list = getPlaylists();
    for (final p in list) {
      if (p.id == id) p.name = name.trim().isEmpty ? p.name : name.trim();
    }
    await _savePlaylists(list);
  }

  static Future<void> addToPlaylist(String playlistId, String lessonId) async {
    final list = getPlaylists();
    for (final p in list) {
      if (p.id == playlistId && !p.lessonIds.contains(lessonId)) {
        p.lessonIds.add(lessonId);
      }
    }
    await _savePlaylists(list);
  }

  static Future<void> removeFromPlaylist(
      String playlistId, String lessonId) async {
    final list = getPlaylists();
    for (final p in list) {
      if (p.id == playlistId) p.lessonIds.remove(lessonId);
    }
    await _savePlaylists(list);
  }

  // ---------------- listening streak (local) ----------------
  static int getStreakDays() => _p.getInt('pers_streak_days') ?? 0;
  static String? getLastListenDate() => _p.getString('pers_last_listen_date');

  static Future<void> recordDailyListen() async {
    final today = _todayKey();
    final last = getLastListenDate();
    if (last == today) return;
    var streak = getStreakDays();
    if (last != null) {
      final lastDate = DateTime.tryParse(last.replaceAll('-', '/'));
      final todayDate = DateTime.now();
      if (lastDate != null) {
        final diff = todayDate.difference(lastDate).inDays;
        streak = diff == 1 ? streak + 1 : 1;
      } else {
        streak = 1;
      }
    } else {
      streak = 1;
    }
    await _p.setInt('pers_streak_days', streak);
    await _p.setString('pers_last_listen_date', today);
  }

  static int getTotalCompletedCount() => getCompletedIds().length;

  // ---------------- playback preferences ----------------
  static double getPlaybackSpeed() => _p.getDouble('pref_speed') ?? 1.0;
  static Future<void> setPlaybackSpeed(double v) =>
      _p.setDouble('pref_speed', v.clamp(0.75, 2.0));

  static int getSkipSeconds() => _p.getInt('pref_skip_sec') ?? 15;
  static Future<void> setSkipSeconds(int v) => _p.setInt('pref_skip_sec', v);

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

  static bool getAutoDownloadWifiOnly() =>
      _p.getBool('auto_dl_wifi_only') ?? true;
  static Future<void> setAutoDownloadWifiOnly(bool v) =>
      _p.setBool('auto_dl_wifi_only', v);

  static bool getContinueReminderEnabled() =>
      _p.getBool('pref_continue_reminder') ?? true;
  static Future<void> setContinueReminderEnabled(bool v) =>
      _p.setBool('pref_continue_reminder', v);

  // ---------------- privacy-respecting analytics (on-device aggregates) ----
  static Map<String, int> getAnalyticsCounts() =>
      _getIntMap('analytics_event_counts');
  static Future<void> trackEvent(String name) async {
    final m = getAnalyticsCounts();
    m[name] = (m[name] ?? 0) + 1;
    await _setIntMap('analytics_event_counts', m);
  }

  // ---------------- notifications bell (آخر إشعار مقروء) ----------------
  static int getLastSeenNotifMs() => _p.getInt('notif_last_seen_ms') ?? 0;
  static Future<void> setLastSeenNotifMs(int v) =>
      _p.setInt('notif_last_seen_ms', v);
}
