import 'package:flutter/material.dart';

import '../models.dart';
import '../services/firebase_repo.dart';
import '../services/local_store.dart';
import '../theme.dart';
import '../widgets/audio_item.dart';
import 'player_screen.dart';
import 'subcategories_screen.dart';
import 'lessons_screen.dart';
import 'settings_screen.dart';

/// YouTube-style home: rails for "continue listening", "most listened",
/// "latest", a "browse sections" rail, then a personalized vertical feed.
/// Audio only — books live on their own tab. Settings open from the ⋮ menu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Category> _categories = [];
  List<Subcategory> _subcategories = [];
  List<Lesson> _lessons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCache();
    _refresh();
  }

  void _loadCache() {
    setState(() {
      _categories = LocalStore.getCategories();
      _subcategories = LocalStore.getSubcategories();
      _lessons = LocalStore.getLessons();
      _loading = _lessons.isEmpty && _categories.isEmpty;
    });
  }

  Future<void> _refresh() async {
    final cats = await FirebaseRepo.fetchCategories();
    final subs = await FirebaseRepo.fetchSubcategories();
    final lessons = await FirebaseRepo.fetchAllLessons();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _subcategories = subs;
      _lessons = lessons;
      _loading = false;
    });
  }

  void _openPlayer(Lesson l, List<Lesson> playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PlayerScreen(lesson: l, playlist: playlist)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newest = [..._lessons]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final newestTop = newest.take(15).toList();
    final most = FirebaseRepo.mostListened(_lessons, limit: 15);
    final cont = FirebaseRepo.continueListening(_lessons);
    final feed = FirebaseRepo.recommendedFeed(_lessons, limit: 50);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيق الإسحاقيين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث',
            onPressed: () => showSearch(
              context: context,
              delegate: _ContentSearchDelegate(
                categories: _categories,
                subcategories: _subcategories,
                lessons: _lessons,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'الإعدادات',
            onPressed: () => showSettingsSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _lessons.isEmpty
                ? _emptyState()
                : ListView(
                    children: [
                      if (_categories.isNotEmpty) _sectionsRail(),
                      if (cont.isNotEmpty) _audioRail('تابع الاستماع', cont),
                      if (most.isNotEmpty) _audioRail('الأكثر استماعاً', most),
                      if (newestTop.isNotEmpty) _audioRail('الأحدث', newestTop),
                      _railHeader('مقترح لك'),
                      ...feed.map((l) => AudioItem(lesson: l, playlist: feed)),
                      const SizedBox(height: 16),
                    ],
                  ),
      ),
    );
  }

  Widget _railHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      );

  Widget _sectionsRail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _railHeader('تصفّح الأقسام'),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            itemBuilder: (context, i) {
              final c = _categories[i];
              return _CategoryChip(
                category: c,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SubcategoriesScreen(category: c)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _audioRail(String title, List<Lesson> lessons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _railHeader(title),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: lessons.length,
            itemBuilder: (context, i) => _AudioCard(
              lesson: lessons[i],
              onTap: () => _openPlayer(lessons[i], lessons),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() => ListView(
        children: const [
          SizedBox(height: 120),
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'يجب الاتصال بالإنترنت أول مرة لتحميل المحتوى. بعد ذلك يمكنك استخدام التطبيق دون إنترنت.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      );
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  const _CategoryChip({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 112,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kSlate,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder, color: kGold, size: 30),
              const SizedBox(height: 8),
              Text(
                category.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;
  const _AudioCard({required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 96,
                width: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [kTeal, kSlate],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 6),
              Text(
                lesson.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentSearchDelegate extends SearchDelegate {
  final List<Category> categories;
  final List<Subcategory> subcategories;
  final List<Lesson> lessons;

  _ContentSearchDelegate({
    required this.categories,
    required this.subcategories,
    required this.lessons,
  });

  @override
  String get searchFieldLabel => 'ابحث...';

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const SizedBox.shrink();
    }
    final catRes =
        categories.where((c) => c.name.toLowerCase().contains(q)).toList();
    final subRes =
        subcategories.where((s) => s.name.toLowerCase().contains(q)).toList();
    final lesRes = lessons
        .where((l) => l.title.toLowerCase().contains(q))
        .take(50)
        .toList();

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
        title: Text(l.title),
        onTap: () {
          close(context, null);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PlayerScreen(lesson: l, playlist: lesRes)),
          );
        },
      ));
    }
    if (tiles.isEmpty) {
      return const Center(child: Text('لا توجد نتائج'));
    }
    return ListView(children: tiles);
  }
}
