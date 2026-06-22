import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import 'local_store.dart';

/// Read-only data access to Firestore (project mxqp-8d1e8), with a local
/// cache fallback so the app works offline after the first online load.
///
/// NOTE: This app never writes to Firestore. All content management lives
/// in a separate (future) admin app behind real authentication.
class FirebaseRepo {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<List<Category>> fetchCategories() async {
    try {
      final snap = await _db.collection('categories').get();
      final list =
          snap.docs.map((d) => Category.fromMap(d.id, d.data())).toList();
      await LocalStore.setCategories(list);
      return list;
    } catch (_) {
      return LocalStore.getCategories();
    }
  }

  static Future<List<Subcategory>> fetchSubcategories() async {
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

  static Future<List<Lesson>> fetchAllLessons() async {
    try {
      final snap = await _db.collection('lessons').get();
      final list =
          snap.docs.map((d) => Lesson.fromMap(d.id, d.data())).toList();
      await LocalStore.setLessons(list);
      return list;
    } catch (_) {
      return LocalStore.getLessons();
    }
  }

  static Future<List<Book>> fetchBooks() async {
    try {
      final snap = await _db.collection('books').get();
      final list = snap.docs.map((d) => Book.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await LocalStore.setBooks(list);
      return list;
    } catch (_) {
      final cached = LocalStore.getBooks();
      cached.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return cached;
    }
  }

  /// Latest lessons first.
  static Future<List<Lesson>> fetchRecentLessons({int limit = 50}) async {
    final all = await fetchAllLessons();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(limit).toList();
  }

  /// Lessons for a subcategory, oldest first (matches original ordering).
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

  /// Anonymous, aggregate play counter. Increments the lesson's `views`
  /// field by exactly 1. Requires Firestore rules that allow an
  /// increment-only update to `views` (see deployment notes). This is the
  /// ONLY write the app performs; it carries no device id or personal data.
  /// Fails silently when offline or not yet permitted by the rules.
  static Future<void> incrementViews(String lessonId) async {
    if (lessonId.isEmpty) return;
    try {
      await _db
          .collection('lessons')
          .doc(lessonId)
          .set({'views': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (_) {
      // Best-effort: popularity must never break playback or the UI.
    }
  }

  /// Most-listened first (by global `views`). Falls back to newest-first
  /// when no view data exists yet (e.g. before the rules are deployed),
  /// so the row is always meaningful.
  static List<Lesson> mostListened(List<Lesson> all, {int limit = 20}) {
    final list = all.where((l) => l.audioUrl.isNotEmpty).toList();
    final anyViews = list.any((l) => l.views > 0);
    list.sort((a, b) {
      if (anyViews) {
        final c = b.views.compareTo(a.views);
        if (c != 0) return c;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list.take(limit).toList();
  }

  /// Audio similar to [lesson]: same subcategory first, then same category,
  /// then the rest — so suggestions span both inside and outside the
  /// section. Excludes the lesson itself.
  static List<Lesson> similarTo(Lesson lesson, List<Lesson> all,
      {int limit = 20}) {
    final pool =
        all.where((l) => l.id != lesson.id && l.audioUrl.isNotEmpty).toList();
    int rank(Lesson l) {
      if (lesson.subcategoryId.isNotEmpty &&
          l.subcategoryId == lesson.subcategoryId) {
        return 0;
      }
      if (lesson.categoryId.isNotEmpty &&
          l.categoryId == lesson.categoryId) {
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

  /// Lessons the user started but didn't finish, most recent first.
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

  /// Personalized Home feed, ranked by the sections and audio the user
  /// actually uses (all computed on-device). For a brand-new user with no
  /// history it falls back to most-listened, so the first launch still
  /// surfaces the most popular audio.
  static List<Lesson> recommendedFeed(List<Lesson> all, {int limit = 60}) {
    final withAudio = all.where((l) => l.audioUrl.isNotEmpty).toList();
    final subVisits = LocalStore.getSubcategoryVisits();
    final catVisits = LocalStore.getCategoryVisits();
    final playCounts = LocalStore.getPlayCounts();
    final completed = LocalStore.getCompletedIds().toSet();

    final hasSignal =
        subVisits.isNotEmpty || catVisits.isNotEmpty || playCounts.isNotEmpty;
    if (!hasSignal) {
      return mostListened(withAudio, limit: limit);
    }

    double score(Lesson l) {
      var s = 0.0;
      s += (subVisits[l.subcategoryId] ?? 0) * 3.0;
      s += (catVisits[l.categoryId] ?? 0) * 1.5;
      s += l.views * 0.05; // gentle nudge from global popularity
      if ((playCounts[l.id] ?? 0) > 0) s -= 2.0; // already heard
      if (completed.contains(l.id)) s -= 4.0; // finished
      return s;
    }

    final list = [...withAudio];
    list.sort((a, b) {
      final c = score(b).compareTo(score(a));
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return list.take(limit).toList();
  }

  /// One-shot sync used at startup to warm the cache.
  static Future<void> syncAll() async {
    await Future.wait([
      fetchCategories(),
      fetchSubcategories(),
      fetchAllLessons(),
      fetchBooks(),
    ]);
  }
}
