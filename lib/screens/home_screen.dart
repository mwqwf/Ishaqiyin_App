import 'package:flutter/material.dart';

import '../models.dart';
import '../services/audio_controller.dart';
import '../services/content_repository.dart';
import '../services/local_store.dart';
import '../theme.dart';
import '../utils/category_colors.dart';
import '../utils/lesson_display.dart';
import '../widgets/audio_item.dart';
import '../widgets/mini_player.dart';
import '../widgets/skeleton_loader.dart';
import 'notifications_screen.dart';
import 'player_screen.dart';
import 'search_delegate.dart';
import 'settings_screen.dart';
import 'subcategories_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ContentRepository _repo = ContentRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepo);
    _repo.loadFromCache();
    _repo.refresh();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepo);
    super.dispose();
  }

  void _onRepo() => setState(() {});

  void _openPlayer(Lesson l, List<Lesson> playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PlayerScreen(lesson: l, playlist: playlist)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منبر ادكصهك'),
        actions: [
          if (_repo.syncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث',
            onPressed: () => showSearch(
              context: context,
              delegate: ContentSearchDelegate(
                categories: _repo.categories,
                subcategories: _repo.subcategories,
                lessons: _repo.lessons,
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
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _repo.refresh(force: true),
              child: _repo.loading
                  ? const HomeSkeleton()
                  : _repo.lessons.isEmpty
                      ? _emptyState()
                      : _homeList(),
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _homeList() {
    return ListView(
      children: [
        if (_repo.categories.isNotEmpty) _sectionsRail(),
        if (_repo.continueList.isNotEmpty)
          _audioRail('تابع الاستماع', _repo.continueList, showProgress: true),
        if (_repo.mostListened.isNotEmpty)
          _audioRail('الأكثر استماعاً', _repo.mostListened),
        if (_repo.newestTop.isNotEmpty)
          _audioRail('الأحدث', _repo.newestTop),
        if (_repo.continueSection.isNotEmpty)
          _audioRail('استكمل قسمك', _repo.continueSection),
        if (_repo.randomToday.isNotEmpty)
          _audioRail('قسم اليوم', _repo.randomToday),
        _railHeader('مقترح لك'),
        ..._repo.feed.map((l) =>
            AudioItem(lesson: l, playlist: _repo.feed, showActions: false)),
        const SizedBox(height: 16),
      ],
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
            itemCount: _repo.categories.length,
            itemBuilder: (context, i) {
              final c = _repo.categories[i];
              final color = colorForCategory(c.id);
              return Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Semantics(
                  label: 'قسم ${c.name}',
                  button: true,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SubcategoriesScreen(category: c)),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 112,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, kSlate],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconForCategory(c.id),
                              color: Colors.white, size: 30),
                          const SizedBox(height: 8),
                          Text(
                            c.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _audioRail(String title, List<Lesson> lessons,
      {bool showProgress = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _railHeader(title),
        SizedBox(
          height: showProgress ? 190 : 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: lessons.length,
            itemBuilder: (context, i) => _AudioCard(
              lesson: lessons[i],
              showProgress: showProgress,
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

class _AudioCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;
  final bool showProgress;
  const _AudioCard({
    required this.lesson,
    required this.onTap,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final audio = AudioController.instance;
    final accent = colorForCategory(lesson.categoryId);
    final durMs = lesson.durationMs > 0
        ? lesson.durationMs
        : LocalStore.getDurationMs(lesson.id);
    final progress = showProgress ? audio.progressFor(lesson.id) : 0.0;
    if (progress == 0 && showProgress) {
      final saved = LocalStore.getPosition(lesson.id);
      if (saved > 0 && durMs > 0) {
        // use saved position when not currently playing
      }
    }
    final savedProgress = durMs > 0
        ? (LocalStore.getPosition(lesson.id) / durMs).clamp(0.0, 1.0)
        : 0.0;
    final displayProgress =
        showProgress ? (progress > 0 ? progress : savedProgress) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Semantics(
        label: 'درس ${lessonDisplayTitle(lesson)}',
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 96,
                      width: 150,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [accent, kSlate],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(iconForCategory(lesson.categoryId),
                          color: Colors.white, size: 44),
                    ),
                    if (durMs > 0)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            formatDuration(Duration(milliseconds: durMs)),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
                if (showProgress && displayProgress > 0) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: displayProgress,
                      minHeight: 3,
                      backgroundColor: Colors.grey.shade300,
                      color: kGreen,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  lessonDisplayTitle(lesson),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
