import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/audio_controller.dart';
import '../services/content_repository.dart';
import '../services/local_store.dart';
import '../services/submission_service.dart';
import '../theme.dart';
import '../utils/category_colors.dart';
import '../utils/lesson_display.dart';
import '../widgets/audio_item.dart';
import '../widgets/mini_player.dart';
import '../widgets/skeleton_loader.dart';
import 'car_mode_screen.dart';
import 'my_submissions_screen.dart';
import 'notifications_screen.dart';
import 'player_screen.dart';
import 'radio_screen.dart';
import 'search_delegate.dart';
import 'settings_screen.dart';
import 'subcategories_screen.dart';
import 'wrapped_screen.dart';

class HomeScreen extends StatefulWidget {
  /// المشغّل المصغّر يُعرض من الهيكل الرئيسي (RootShell) فلا نكرّره هنا.
  final bool showMiniPlayer;
  const HomeScreen({super.key, this.showMiniPlayer = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ContentRepository _repo = ContentRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepo);
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
          const _MySubmissionsButton(),
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
          if (widget.showMiniPlayer) const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _homeList() {
    return ListView(
      children: [
        _quickActions(),
        if (_repo.dailyWard != null) _dailyWardCard(_repo.dailyWard!),
        if (_repo.featured.isNotEmpty)
          _audioRail('مختارات المنبر ⭐', _repo.featured),
        if (_repo.categories.isNotEmpty) _sectionsRail(),
        if (_repo.continueList.isNotEmpty)
          _audioRail('تابع الاستماع', _repo.continueList, showProgress: true),
        if (_repo.unfinished.isNotEmpty)
          _audioRail('لم تُكمله بعد', _repo.unfinished, showProgress: true),
        if (_repo.trending.isNotEmpty)
          _audioRail('الأكثر استماعاً هذا الأسبوع 🔥', _repo.trending),
        if (_repo.mostListened.isNotEmpty)
          _audioRail('الأكثر استماعاً', _repo.mostListened),
        if (_repo.newestTop.isNotEmpty) _audioRail('الأحدث', _repo.newestTop),
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

  Widget _quickActions() {
    Widget chip(IconData icon, String label, Color color, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ActionChip(
          avatar: Icon(icon, color: color, size: 20),
          label: Text(label),
          onPressed: onTap,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          chip(Icons.radio, 'إذاعة منبر', kTeal,
              () => _push(const RadioScreen())),
          chip(Icons.directions_car, 'وضع القيادة', kBlue,
              () => _push(const CarModeScreen())),
          chip(Icons.insights, 'حصادك', kOrange,
              () => _push(const WrappedScreen())),
        ],
      ),
    );
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _dailyWardCard(Lesson l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openPlayer(l, [l, ..._repo.feed]),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kTeal, kSlate],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_outlined,
                    color: Colors.white, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('وِرد اليوم',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(lessonDisplayTitle(l),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 40),
              ],
            ),
          ),
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
          height: 120,
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

/// زر «مساهماتي» بجوار الجرس — يظهر لمن لديه هوية مساهمات فقط،
/// وعليه نقطة إذا حُسمت مساهمة بعد آخر زيارة للشاشة.
class _MySubmissionsButton extends StatefulWidget {
  const _MySubmissionsButton();

  @override
  State<_MySubmissionsButton> createState() => _MySubmissionsButtonState();
}

class _MySubmissionsButtonState extends State<_MySubmissionsButton> {
  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
    );
    // بعد العودة تكون لحظة الاطلاع قد تحدّثت — أعد البناء لإطفاء النقطة.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnap) {
        if (authSnap.data == null) return const SizedBox.shrink();
        return StreamBuilder<List<LessonSubmission>>(
          stream: SubmissionService.watchMine(),
          builder: (context, snap) {
            final items = snap.data ?? const <LessonSubmission>[];
            final seen = LocalStore.getMySubsSeenMs();
            final hasNewDecision = items.any(
                (s) => s.status != 'pending' && s.decidedAtMs > seen);
            final button = IconButton(
              icon: const Icon(Icons.outbox_outlined),
              tooltip: 'مساهماتي',
              onPressed: _open,
            );
            if (!hasNewDecision) return button;
            return Badge(smallSize: 8, child: button);
          },
        );
      },
    );
  }
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
