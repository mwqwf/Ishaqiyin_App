import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/local_store.dart';
import '../theme.dart';
import '../utils/arabic_search.dart';
import '../utils/lesson_display.dart';
import 'lessons_screen.dart';
import 'player_screen.dart';
import 'subcategories_screen.dart';

class ContentSearchDelegate extends SearchDelegate<String?> {
  final List<Category> categories;
  final List<Subcategory> subcategories;
  final List<Lesson> lessons;

  ContentSearchDelegate({
    required this.categories,
    required this.subcategories,
    required this.lessons,
  });

  Timer? _debounce;

  @override
  String get searchFieldLabel => 'ابحث في الدروس والأقسام...';

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'مسح',
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      final history = LocalStore.getSearchHistory();
      if (history.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('ابحث في العناوين، الأقسام، وأسماء الشيوخ'),
          ),
        );
      }
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('عمليات بحث سابقة',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () async {
                    await LocalStore.clearSearchHistory();
                    // ignore: use_build_context_synchronously
                    showSuggestions(context);
                  },
                  child: const Text('مسح'),
                ),
              ],
            ),
          ),
          ...history.map((h) => ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(h),
                onTap: () {
                  query = h;
                  showResults(context);
                },
              )),
        ],
      );
    }
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) return const SizedBox.shrink();

    final catRes = categories.where((c) => arabicContains(c.name, q)).toList();
    final subRes =
        subcategories.where((s) => arabicContains(s.name, q)).toList();
    final lesRes = lessons
        .where((l) {
          if (arabicContains(l.title, q)) return true;
          if (l.speaker.isNotEmpty && arabicContains(l.speaker, q)) return true;
          final cat = categories.where((c) => c.id == l.categoryId);
          if (cat.isNotEmpty && arabicContains(cat.first.name, q)) return true;
          final sub = subcategories.where((s) => s.id == l.subcategoryId);
          if (sub.isNotEmpty && arabicContains(sub.first.name, q)) return true;
          return false;
        })
        .take(80)
        .toList();

    if (q.length >= 2) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        LocalStore.addSearchQuery(q);
      });
    }

    final tiles = <Widget>[];
    for (final c in catRes) {
      tiles.add(ListTile(
        leading: const Icon(Icons.folder, color: kTeal),
        title: Text(c.name),
        onTap: () {
          close(context, null);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SubcategoriesScreen(category: c)),
          );
        },
      ));
    }
    for (final s in subRes) {
      tiles.add(ListTile(
        leading: const Icon(Icons.folder_open, color: kBlue),
        title: Text(s.name),
        onTap: () {
          close(context, null);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LessonsScreen(subcategory: s)),
          );
        },
      ));
    }
    for (final l in lesRes) {
      tiles.add(ListTile(
        leading: const Icon(Icons.music_note, color: kGold),
        title: Text(lessonDisplayTitle(l)),
        subtitle: l.speaker.isNotEmpty ? Text(l.speaker) : null,
        onTap: () {
          close(context, null);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(lesson: l, playlist: lesRes),
            ),
          );
        },
      ));
    }
    if (tiles.isEmpty) {
      return const Center(child: Text('لا توجد نتائج'));
    }
    if (lesRes.length >= 80) {
      tiles.add(const Padding(
        padding: EdgeInsets.all(12),
        child: Text('عرض أول 80 نتيجة — حدّد البحث أكثر',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ));
    }
    return ListView(children: tiles);
  }
}
