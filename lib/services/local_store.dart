import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

/// Lightweight local cache + settings, backed by SharedPreferences.
class LocalStore {
  static late SharedPreferences _p;

  /// إشارة موحّدة لتحديث شاشات المكتبة عند تغيّر بياناتها على الجهاز.
  static final ValueNotifier<int> libraryRevision = ValueNotifier<int>(0);

  static void _notifyLibrary() => libraryRevision.value++;

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
    _notifyLibrary();
  }

  static Future<void> removeAudioDownload(String id) async {
    final m = getAudioDownloads()..remove(id);
    await _setMap('downloads_audio', m);
    _notifyLibrary();
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
    _notifyLibrary();
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
    _notifyLibrary();
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

  static Future<void> _savePlaylists(List<Playlist> v) async {
    await _p.setString(
        'pers_playlists', jsonEncode(v.map((e) => e.toJson()).toList()));
    _notifyLibrary();
  }

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
      final lastDate = DateTime.tryParse(last);
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      if (lastDate != null) {
        final normalizedLast =
            DateTime(lastDate.year, lastDate.month, lastDate.day);
        final diff = todayDate.difference(normalizedLast).inDays;
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

  /// آخر زيارة لشاشة «مساهماتي» — لنقطة زرّها في الشريط العلوي.
  static int getMySubsSeenMs() => _p.getInt('my_subs_seen_ms') ?? 0;
  static Future<void> setMySubsSeenMs(int v) =>
      _p.setInt('my_subs_seen_ms', v);

  /// تفعيل/إيقاف الإشعارات (افتراضياً مُفعّلة).
  static bool getNotificationsEnabled() => _p.getBool('notif_enabled') ?? true;
  static Future<void> setNotificationsEnabled(bool v) =>
      _p.setBool('notif_enabled', v);

  /// الإشعارات المحذوفة محلياً (لا تُحذف من السحابة المشتركة).
  static List<String> getDismissedNotifIds() =>
      _getStringList('notif_dismissed');
  static bool isNotifDismissed(String id) =>
      getDismissedNotifIds().contains(id);
  static Future<void> dismissNotif(String id) async {
    final list = getDismissedNotifIds();
    if (!list.contains(id)) {
      list.add(id);
      if (list.length > 500) list.removeRange(0, list.length - 500);
      await _setStringList('notif_dismissed', list);
    }
  }

  // ==================================================================
  //  ميزات التفاعل (تقرير 2026-07) — كلها محلية على الجهاز
  // ==================================================================

  // ---------------- «اللحظات» (علامات صوتية مع ملاحظة) ----------------
  /// خريطة: معرّف الدرس → قائمة لحظات [{ms, note}].
  static Map<String, List<Map<String, dynamic>>> _getBookmarks() {
    final s = _p.getString('pers_bookmarks');
    if (s == null) return {};
    try {
      final d = jsonDecode(s);
      if (d is Map) {
        return d.map((k, v) => MapEntry(
              k.toString(),
              (v is List)
                  ? v
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList()
                  : <Map<String, dynamic>>[],
            ));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _saveBookmarks(
          Map<String, List<Map<String, dynamic>>> m) =>
      _p.setString('pers_bookmarks', jsonEncode(m));

  static List<Map<String, dynamic>> getBookmarks(String lessonId) =>
      _getBookmarks()[lessonId] ?? [];

  /// كل اللحظات المحفوظة عبر كل الدروس: [{lessonId, ms, note}] مرتّبة بالأحدث.
  static List<Map<String, dynamic>> getAllBookmarks() {
    final all = <Map<String, dynamic>>[];
    _getBookmarks().forEach((lessonId, list) {
      for (final b in list) {
        all.add({'lessonId': lessonId, ...b});
      }
    });
    all.sort((a, b) => (b['savedAt'] ?? 0).compareTo(a['savedAt'] ?? 0));
    return all;
  }

  static int getBookmarkCount() {
    var n = 0;
    _getBookmarks().forEach((_, v) => n += v.length);
    return n;
  }

  static Future<void> addBookmark(String lessonId, int ms, String note) async {
    if (lessonId.isEmpty) return;
    final m = _getBookmarks();
    final list = m[lessonId] ?? [];
    list.add({
      'ms': ms,
      'note': note.trim(),
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    });
    list.sort((a, b) => (a['ms'] as int).compareTo(b['ms'] as int));
    m[lessonId] = list;
    await _saveBookmarks(m);
  }

  static Future<void> removeBookmark(String lessonId, int savedAt) async {
    final m = _getBookmarks();
    final list = m[lessonId];
    if (list == null) return;
    list.removeWhere((b) => (b['savedAt'] ?? 0) == savedAt);
    if (list.isEmpty) {
      m.remove(lessonId);
    } else {
      m[lessonId] = list;
    }
    await _saveBookmarks(m);
  }

  // ---------------- متابعة الأقسام (إشعارات مخصّصة) ----------------
  static List<String> getFollowedSubs() => _getStringList('pers_followed_subs');
  static bool isFollowingSub(String subId) => getFollowedSubs().contains(subId);
  static Future<void> toggleFollowSub(String subId) async {
    if (subId.isEmpty) return;
    final list = getFollowedSubs();
    if (list.contains(subId)) {
      list.remove(subId);
    } else {
      list.add(subId);
    }
    await _setStringList('pers_followed_subs', list);
  }

  // ---------------- الوِرد اليومي ----------------
  /// ساعة التسليم (0-23)، أو -1 إن كان الوِرد موقوفاً (الافتراضي موقوف).
  static int getWardHour() => _p.getInt('ward_hour') ?? -1;
  static int getWardMinute() => _p.getInt('ward_minute') ?? 0;
  static bool getWardEnabled() => getWardHour() >= 0;
  static Future<void> setWardTime(int hour, int minute) async {
    await _p.setInt('ward_hour', hour);
    await _p.setInt('ward_minute', minute);
  }

  static Future<void> disableWard() => _p.setInt('ward_hour', -1);

  static String? getWardLastDate() => _p.getString('ward_last_date');
  static Future<void> setWardDelivered() =>
      _p.setString('ward_last_date', _todayKey());
  static bool get wardDeliveredToday => getWardLastDate() == _todayKey();

  // ---------------- إحصاء وقت الاستماع (لـ«حصادك» والهدف) ----------------
  /// خريطة: يوم (YYYY-M-D) → إجمالي ثواني الاستماع.
  static Map<String, int> getDailySeconds() => _getIntMap('stat_daily_seconds');

  static Future<void> addListenSeconds(int seconds) async {
    if (seconds <= 0) return;
    final m = getDailySeconds();
    final k = _todayKey();
    m[k] = (m[k] ?? 0) + seconds;
    // احتفظ بآخر 120 يوماً فقط.
    if (m.length > 120) {
      final keys = m.keys.toList();
      for (final key in keys.take(m.length - 120)) {
        m.remove(key);
      }
    }
    await _setIntMap('stat_daily_seconds', m);
  }

  static int getTodaySeconds() => getDailySeconds()[_todayKey()] ?? 0;

  static int getTotalSeconds() {
    var t = 0;
    getDailySeconds().forEach((_, v) => t += v);
    return t;
  }

  /// إجمالي ثواني الاستماع خلال آخر 7 أيام (يشمل اليوم).
  static int getWeekSeconds() {
    final m = getDailySeconds();
    final now = DateTime.now();
    var t = 0;
    for (var i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: i));
      t += m['${d.year}-${d.month}-${d.day}'] ?? 0;
    }
    return t;
  }

  // ---------------- الهدف الأسبوعي (بالدقائق، 0 = موقوف) ----------------
  static int getWeeklyGoalMinutes() => _p.getInt('goal_weekly_min') ?? 0;
  static Future<void> setWeeklyGoalMinutes(int v) =>
      _p.setInt('goal_weekly_min', v < 0 ? 0 : v);

  /// يمحو بيانات المستخدم المحلية دون حذف مكتبة المحتوى العامة المؤقتة.
  static Future<void> clearPersonalData() async {
    const exactKeys = <String>{
      'downloads_audio',
      'pers_play_counts',
      'pers_recent_played',
      'pers_cat_visits',
      'pers_sub_visits',
      'pers_positions',
      'pers_completed',
      'pers_durations',
      'pers_view_counted',
      'pers_favorites',
      'pers_search_hist',
      'pers_playlists',
      'pers_streak_days',
      'pers_last_listen_date',
      'pers_bookmarks',
      'pers_followed_subs',
      'stat_daily_seconds',
      'analytics_event_counts',
      'notif_last_seen_ms',
      'notif_dismissed',
      'my_subs_seen_ms',
      'ward_last_date',
      'goal_weekly_min',
      'submission_known_statuses_v1',
      'submitter_name_v1',
    };
    for (final key in exactKeys) {
      await _p.remove(key);
    }
    _notifyLibrary();
  }
}
