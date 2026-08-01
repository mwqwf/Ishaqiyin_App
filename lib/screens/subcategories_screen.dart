import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/content_repository.dart';
import '../services/firebase_repo.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../utils/category_colors.dart';
import '../theme.dart';
import 'lessons_screen.dart';

class SubcategoriesScreen extends StatefulWidget {
  final Category category;
  const SubcategoriesScreen({super.key, required this.category});

  @override
  State<SubcategoriesScreen> createState() => _SubcategoriesScreenState();
}

class _SubcategoriesScreenState extends State<SubcategoriesScreen> {
  final ContentRepository _repo = ContentRepository.instance;
  List<Subcategory> _subs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocalStore.incrementCategoryVisit(widget.category.id);
    _load();
    _repo.addListener(_onRepo);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepo);
    super.dispose();
  }

  void _onRepo() => _load();

  void _load() {
    final cached = FirebaseRepo.subcategoriesForCategory(
        widget.category.id, _repo.subcategories);
    setState(() {
      _subs = cached;
      _loading = cached.isEmpty && _repo.loading;
    });
  }

  Future<void> _refresh() async {
    await _repo.refresh(force: true);
  }

  Future<void> _toggleFollow(Subcategory s) async {
    final wasFollowing = LocalStore.isFollowingSub(s.id);
    try {
      if (wasFollowing) {
        await NotificationService.unsubscribeSub(s.id);
      } else {
        await NotificationService.subscribeSub(s.id);
      }
      await LocalStore.toggleFollowSub(s.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasFollowing
              ? 'أُلغيت متابعة «${s.name}»'
              : 'ستصلك إشعارات دروس «${s.name}» الجديدة'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذّر تحديث المتابعة. تحقق من الاتصال وحاول مجدداً.'),
        ));
      }
    }
  }

  void _showCertificate(Subcategory s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium, color: kGold, size: 64),
            const SizedBox(height: 12),
            const Text('شهادة إتمام',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('أتممت الاستماع إلى سلسلة\n«${s.name}»',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            const Text('نسأل الله لك العلم النافع 🌿',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('مشاركة'),
            onPressed: () {
              Navigator.pop(ctx);
              Share.share('أتممتُ سلسلة «${s.name}» في تطبيق «منبر ادكصهك» 🎓');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = colorForCategory(widget.category.id);
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _subs.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'لا توجد أقسام فرعية في هذا القسم.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _subs.length,
                    itemBuilder: (context, i) {
                      final s = _subs[i];
                      final (done, total) =
                          FirebaseRepo.seriesProgress(s.id, _repo.lessons);
                      final ratio = total > 0 ? done / total : 0.0;
                      final complete = total > 0 && done >= total;
                      final following = LocalStore.isFollowingSub(s.id);
                      return Card(
                        color: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        elevation: 1,
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accent, kSlate],
                              begin: AlignmentDirectional.topStart,
                              end: AlignmentDirectional.bottomEnd,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                leading: Icon(
                                    iconForCategory(widget.category.id),
                                    color: complete
                                        ? kPositiveOnDark
                                        : kGoldOnDark),
                                title: Text(
                                  s.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 17),
                                ),
                                subtitle: total > 0
                                    ? Text(
                                        complete
                                            ? 'أتممت السلسلة ✓'
                                            : '$done من $total',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13),
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: following
                                          ? 'إلغاء متابعة القسم'
                                          : 'متابعة القسم (إشعارات)',
                                      icon: Icon(
                                        following
                                            ? Icons.notifications_active
                                            : Icons.notifications_none,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => _toggleFollow(s),
                                    ),
                                    if (complete)
                                      IconButton(
                                        tooltip: 'شهادة الإتمام',
                                        icon: const Icon(
                                            Icons.workspace_premium,
                                            color: kGoldOnDark),
                                        onPressed: () => _showCertificate(s),
                                      ),
                                  ],
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LessonsScreen(subcategory: s),
                                  ),
                                ),
                              ),
                              if (total > 0)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 6,
                                      backgroundColor: Colors.white24,
                                      color: complete
                                          ? kPositiveOnDark
                                          : kGoldOnDark,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
