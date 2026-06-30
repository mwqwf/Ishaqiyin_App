import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models.dart';
import 'firebase_repo.dart';
import 'local_store.dart';

/// Cached content + precomputed home rails. Screens listen here instead of
/// re-fetching and re-sorting on every build.
class ContentRepository extends ChangeNotifier {
  ContentRepository._();
  static final ContentRepository instance = ContentRepository._();

  List<Category> categories = [];
  List<Subcategory> subcategories = [];
  List<Lesson> lessons = [];
  bool loading = true;
  bool syncing = false;

  List<Lesson> newestTop = [];
  List<Lesson> mostListened = [];
  List<Lesson> continueList = [];
  List<Lesson> feed = [];
  List<Lesson> continueSection = [];
  List<Lesson> randomToday = [];

  void loadFromCache() {
    categories = LocalStore.getCategories();
    subcategories = LocalStore.getSubcategories();
    lessons = LocalStore.getLessons();
    loading = lessons.isEmpty && categories.isEmpty;
    _recomputeRails();
    notifyListeners();
  }

  Future<void> refresh({bool force = false}) async {
    syncing = true;
    notifyListeners();
    try {
      categories = await FirebaseRepo.fetchCategories(force: force);
      subcategories = await FirebaseRepo.fetchSubcategories(force: force);
      lessons = await FirebaseRepo.fetchAllLessons(force: force);
      loading = false;
      _recomputeRails();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void _recomputeRails() {
    final sorted = [...lessons]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    newestTop = sorted.take(15).toList();
    mostListened = FirebaseRepo.mostListened(lessons, limit: 15);
    continueList = FirebaseRepo.continueListening(lessons);
    feed = FirebaseRepo.recommendedFeed(lessons, limit: 50);
    continueSection = FirebaseRepo.continueSection(lessons);
    randomToday = FirebaseRepo.randomSectionToday(lessons);
  }

  Lesson? lessonById(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  Category? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Subcategory? subcategoryById(String id) {
    for (final s in subcategories) {
      if (s.id == id) return s;
    }
    return null;
  }
}
