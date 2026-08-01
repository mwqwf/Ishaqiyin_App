import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models.dart';
import 'local_store.dart';
import 'anonymous_identity_service.dart';

/// Read-only Firestore access with local cache and incremental sync.
class FirebaseRepo {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Minimum interval between background full re-fetches (2 minutes).
  /// فتح التطبيق والعودة إليه يجلبان دائماً بالقوة (force) لظهور التعديلات
  /// فوراً؛ هذه الفترة القصيرة مجرد شبكة أمان أثناء التصفّح المستمر.
  static const _syncIntervalMs = 2 * 60 * 1000;

  static Future<List<Category>> fetchCategories({bool force = false}) async {
    if (!force && _cacheFresh()) return LocalStore.getCategories();
    try {
      final snap = await _db.collection('categories').get();
      final list = <Category>[
        for (final d in snap.docs) Category.fromMap(d.id, d.data()),
      ];
      await LocalStore.setCategories(list);
      return list;
    } catch (_) {
      return LocalStore.getCategories();
    }
  }

  static Future<List<Subcategory>> fetchSubcategories(
      {bool force = false}) async {
    if (!force && _cacheFresh()) return LocalStore.getSubcategories();
    try {
      final snap = await _db.collection('subcategories').get();
      final list =
          snap.docs.map((d) => Subcategory.fromMap(d.id, d.data())).toList();
      await LocalStore.setSubcategories(list);
      return list;
    } catch (_) {
      return LocalStore.getSubcategories();
    }
  }

  static bool _cacheFresh() {
    final last = LocalStore.getLastSyncMs();
    if (last == 0) return false;
    return DateTime.now().millisecondsSinceEpoch - last < _syncIntervalMs;
  }

  static Future<List<Lesson>> fetchAllLessons({bool force = false}) async {
    if (!force && _cacheFresh()) {
      return _mergeLocalDurations(LocalStore.getLessons());
    }
    try {
      final snap = await _db.collection('lessons').get();
      final list = snap.docs
          .map((d) => Lesson.fromMap(d.id, d.data()))
          .where(_isPublished)
          .toList();
      await LocalStore.setLessons(list);
      await LocalStore.setLastSyncMs(DateTime.now().millisecondsSinceEpoch);
      return _mergeLocalDurations(list);
    } catch (_) {
      return _mergeLocalDurations(
          LocalStore.getLessons().where(_isPublished).toList());
    }
  }

  /// الدرس منشور إن لم يكن له وقت نشر مجدول في المستقبل.
  static bool _isPublished(Lesson l) =>
      l.publishAt == null || !l.publishAt!.isAfter(DateTime.now());

  static List<Lesson> featured(List<Lesson> all, {int limit = 12}) {
    final list = all.where((l) => l.featured && l.audioUrl.isNotEmpty).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  static List<Lesson> _mergeLocalDurations(List<Lesson> lessons) {
    final durations = LocalStore.getDurations();
    return lessons.map((l) {
      final local = durations[l.id];
      if (local != null && local > 0 && l.durationMs <= 0) {
        return l.copyWith(durationMs: local);
      }
      return l;
    }).toList();
  }

  static Future<List<Lesson>> fetchRecentLessons({int limit = 50}) async {
    final all = await fetchAllLessons();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(limit).toList();
  }

  static List<Lesson> lessonsForSubcategory(String subId, List<Lesson> all) {
    final s = subId.trim();
    final list = all.where((l) => l.subcategoryId == s).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static List<Subcategory> subcategoriesForCategory(
      String categoryId, List<Subcategory> all) {
    final c = categoryId.trim();
    final list = all.where((s) => s.categoryId == c).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// يرسل التفاعل عبر الخادم بعد التحقق؛ الفشل يُعاد للواجهة بوضوح.
  static Future<void> sendFeedback(
      String lessonId, String type, String note) async {
    await AnonymousIdentityService.ensureSignedIn();
    await _functions.httpsCallable('sendFeedback').call(<String, dynamic>{
      'lessonId': lessonId,
      'type': type,
      'note': note.trim(),
    });
  }

  static Future<void> incrementViews(String lessonId) async {
    if (lessonId.isEmpty) return;
    try {
      await AnonymousIdentityService.ensureSignedIn();
      await _functions
          .httpsCallable('incrementLessonView')
          .call(<String, dynamic>{'lessonId': lessonId});
    } catch (e) {
      // عدّاد الاستماع إحصائي ولا ينبغي أن يوقف الصوت عند انقطاع الشبكة.
    }
  }

  static bool hasViewData(List<Lesson> all) => all.any((l) => l.views > 0);

  static List<Lesson> mostListened(List<Lesson> all, {int limit = 20}) {
    final list = all.where((l) => l.audioUrl.isNotEmpty).toList();
    if (!hasViewData(list)) return [];
    list.sort((a, b) {
      final c = b.views.compareTo(a.views);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return list.take(limit).toList();
  }

  static List<Lesson> similarTo(Lesson lesson, List<Lesson> all,
      {int limit = 20}) {
    final pool =
        all.where((l) => l.id != lesson.id && l.audioUrl.isNotEmpty).toList();
    int rank(Lesson l) {
      if (lesson.subcategoryId.isNotEmpty &&
          l.subcategoryId == lesson.subcategoryId) {
        return 0;
      }
      if (lesson.categoryId.isNotEmpty && l.categoryId == lesson.categoryId) {
        return 1;
      }
      return 2;
    }

    pool.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final v = b.views.compareTo(a.views);
      return v != 0 ? v : b.createdAt.compareTo(a.createdAt);
    });
    return pool.take(limit).toList();
  }

  static List<Lesson> continueListening(List<Lesson> all) {
    final positions = LocalStore.getPositions();
    final completed = LocalStore.getCompletedIds().toSet();
    final byId = {for (final l in all) l.id: l};
    final res = <Lesson>[];
    for (final id in LocalStore.getRecentPlayedIds()) {
      if (completed.contains(id)) continue;
      if ((positions[id] ?? 0) > 3000 && byId.containsKey(id)) {
        res.add(byId[id]!);
      }
    }
    return res;
  }

  static List<Lesson> recommendedFeed(List<Lesson> all, {int limit = 60}) {
    final withAudio = all.where((l) => l.audioUrl.isNotEmpty).toList();
    final subVisits = LocalStore.getSubcategoryVisits();
    final catVisits = LocalStore.getCategoryVisits();
    final playCounts = LocalStore.getPlayCounts();
    final completed = LocalStore.getCompletedIds().toSet();

    final hasSignal =
        subVisits.isNotEmpty || catVisits.isNotEmpty || playCounts.isNotEmpty;
    if (!hasSignal) {
      final newest = [...withAudio]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return newest.take(limit).toList();
    }

    double score(Lesson l) {
      var s = 0.0;
      s += (subVisits[l.subcategoryId] ?? 0) * 3.0;
      s += (catVisits[l.categoryId] ?? 0) * 1.5;
      s += l.views * 0.05;
      if ((playCounts[l.id] ?? 0) > 0) s -= 2.0;
      if (completed.contains(l.id)) s -= 4.0;
      return s;
    }

    final list = [...withAudio];
    list.sort((a, b) {
      final c = score(b).compareTo(score(a));
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return list.take(limit).toList();
  }

  /// Lessons in subcategories the user visited but hasn't completed all of.
  static List<Lesson> continueSection(List<Lesson> all, {int limit = 15}) {
    final subVisits = LocalStore.getSubcategoryVisits();
    if (subVisits.isEmpty) return [];
    final completed = LocalStore.getCompletedIds().toSet();
    final positions = LocalStore.getPositions();
    final sortedSubs = subVisits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final res = <Lesson>[];
    for (final entry in sortedSubs) {
      final subLessons = lessonsForSubcategory(entry.key, all);
      for (final l in subLessons) {
        if (completed.contains(l.id)) continue;
        if ((positions[l.id] ?? 0) > 0 ||
            subVisits.containsKey(l.subcategoryId)) {
          res.add(l);
          if (res.length >= limit) return res;
        }
      }
    }
    return res;
  }

  /// One random subcategory's lessons for daily discovery.
  static List<Lesson> randomSectionToday(List<Lesson> all, {int limit = 12}) {
    final subs = LocalStore.getSubcategories();
    if (subs.isEmpty) return [];
    final day = DateTime.now().day + DateTime.now().month * 31;
    final sub = subs[day % subs.length];
    return lessonsForSubcategory(sub.id, all).take(limit).toList();
  }

  static List<Lesson> favorites(List<Lesson> all) {
    final ids = LocalStore.getFavoriteIds().toSet();
    final byId = {for (final l in all) l.id: l};
    return ids.map((id) => byId[id]).whereType<Lesson>().toList();
  }

  // ---------------- السلاسل (تقدّم القسم الفرعي) ----------------
  /// (عدد المكتمل، الإجمالي) لدروس قسم فرعي معيّن.
  static (int, int) seriesProgress(String subId, List<Lesson> all) {
    final lessons =
        all.where((l) => l.subcategoryId == subId && l.audioUrl.isNotEmpty);
    final total = lessons.length;
    if (total == 0) return (0, 0);
    final completed = LocalStore.getCompletedIds().toSet();
    final done = lessons.where((l) => completed.contains(l.id)).length;
    return (done, total);
  }

  // ---------------- محطات «إذاعة منبر» ----------------
  static int _durMs(Lesson l) =>
      l.durationMs > 0 ? l.durationMs : LocalStore.getDurationMs(l.id);

  /// المحطة المخصّصة: طابور طويل من التوصيات + الأحدث (لبثّ لا يتوقف).
  static List<Lesson> stationForYou(List<Lesson> all) {
    final feed = recommendedFeed(all, limit: 200);
    if (feed.isNotEmpty) return feed;
    final withAudio = all.where((l) => l.audioUrl.isNotEmpty).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return withAudio;
  }

  static List<Lesson> stationNewest(List<Lesson> all) {
    final l = all.where((x) => x.audioUrl.isNotEmpty).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return l;
  }

  /// المحطة القصيرة: دروس مدّتها المعروفة أقل من 10 دقائق.
  static List<Lesson> stationShort(List<Lesson> all) {
    final l = all.where((x) => x.audioUrl.isNotEmpty).where((x) {
      final d = _durMs(x);
      return d > 0 && d < 10 * 60 * 1000;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return l;
  }

  static List<Lesson> stationRandom(List<Lesson> all) {
    final l = all.where((x) => x.audioUrl.isNotEmpty).toList()..shuffle();
    return l;
  }

  /// درس «الوِرد اليومي»: اختيار حتمي ثابت لكل يوم من كل الدروس.
  static Lesson? dailyWard(List<Lesson> all) {
    final withAudio = all.where((l) => l.audioUrl.isNotEmpty).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (withAudio.isEmpty) return null;
    final now = DateTime.now();
    final seed = now.year * 1000 + now.month * 40 + now.day;
    return withAudio[seed % withAudio.length];
  }

  // ---------------- «الأكثر استماعاً هذا الأسبوع» (تقريبي) ----------------
  /// يمزج عدّاد المشاهدات مع حداثة الإضافة لإبراز الرائج مؤخّراً.
  static List<Lesson> trendingThisWeek(List<Lesson> all, {int limit = 15}) {
    final pool =
        all.where((l) => l.audioUrl.isNotEmpty && l.views > 0).toList();
    if (pool.isEmpty) return [];
    final now = DateTime.now();
    double score(Lesson l) {
      final ageDays = now.difference(l.createdAt).inDays.clamp(0, 3650);
      final recency = 1.0 / (1 + ageDays / 30.0); // يتلاشى خلال أسابيع
      return l.views * (0.5 + recency);
    }

    pool.sort((a, b) => score(b).compareTo(score(a)));
    return pool.take(limit).toList();
  }

  // ---------------- قوائم ذكية تلقائية ----------------
  /// دروس بدأها المستخدم ولم يكملها.
  static List<Lesson> unfinished(List<Lesson> all) {
    final positions = LocalStore.getPositions();
    final completed = LocalStore.getCompletedIds().toSet();
    final byId = {for (final l in all) l.id: l};
    final res = <Lesson>[];
    positions.forEach((id, pos) {
      if (pos > 3000 && !completed.contains(id) && byId.containsKey(id)) {
        res.add(byId[id]!);
      }
    });
    return res;
  }

  static Future<void> syncAll({bool force = false}) async {
    await Future.wait([
      fetchCategories(force: force),
      fetchSubcategories(force: force),
      fetchAllLessons(force: force),
    ]);
  }
}
