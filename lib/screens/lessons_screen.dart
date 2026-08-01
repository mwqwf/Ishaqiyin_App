import 'package:flutter/material.dart';

import '../models.dart';
import '../services/content_repository.dart';
import '../services/download_service.dart';
import '../services/firebase_repo.dart';
import '../services/local_store.dart';
import '../widgets/audio_item.dart';
import '../widgets/mini_player.dart';
import 'subcategories_screen.dart';

class LessonsScreen extends StatefulWidget {
  final Subcategory subcategory;
  const LessonsScreen({super.key, required this.subcategory});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final ContentRepository _repo = ContentRepository.instance;
  List<Lesson> _lessons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocalStore.incrementSubcategoryVisit(widget.subcategory.id);
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
    final cached = FirebaseRepo.lessonsForSubcategory(
        widget.subcategory.id, _repo.lessons);
    setState(() {
      _lessons = cached;
      _loading = cached.isEmpty && _repo.loading;
    });
  }

  Future<void> _refresh() async {
    await _repo.refresh(force: true);
  }

  void _openCategory() {
    final cat = _repo.categoryById(widget.subcategory.categoryId);
    if (cat == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SubcategoriesScreen(category: cat)),
    );
  }

  bool _bulkDl = false;
  int _dlDone = 0;
  int _dlTotal = 0;

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// تحميل كل دروس القسم الفرعي دفعة واحدة (نمط يوتيوب «تنزيل الكل»).
  Future<void> _downloadAll() async {
    if (_bulkDl) return;
    final pending = _lessons
        .where((l) =>
            l.audioUrl.isNotEmpty && !DownloadService.isAudioDownloaded(l.id))
        .toList();
    if (pending.isEmpty) {
      _snack('كل دروس هذا القسم محمّلة بالفعل.');
      return;
    }
    setState(() {
      _bulkDl = true;
      _dlDone = 0;
      _dlTotal = pending.length;
    });
    var succeeded = 0;
    var failed = 0;
    for (final l in pending) {
      try {
        await DownloadService.downloadAudio(l.id, l.audioUrl);
        succeeded++;
      } catch (_) {
        failed++;
      }
      if (!mounted) return;
      setState(() => _dlDone++);
    }
    if (mounted) {
      setState(() => _bulkDl = false);
      if (failed == 0) {
        _snack('تم تحميل $succeeded درساً للاستماع دون إنترنت.');
      } else if (succeeded == 0) {
        _snack('تعذّر تحميل الدروس. تحقق من الاتصال وحاول مجدداً.');
      } else {
        _snack('تم تحميل $succeeded، وتعذّر تحميل $failed درساً.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subcategory.name),
        actions: [
          if (_bulkDl)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text('$_dlDone/$_dlTotal',
                    style: const TextStyle(fontSize: 13)),
              ),
            )
          else
            IconButton(
              tooltip: 'تنزيل كل دروس القسم',
              icon: const Icon(Icons.download_for_offline_outlined),
              onPressed: _lessons.isEmpty ? null : _downloadAll,
            ),
          IconButton(
            tooltip: 'القسم الرئيسي',
            icon: const Icon(Icons.drive_folder_upload),
            onPressed: _openCategory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _lessons.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'يجب الاتصال بالإنترنت أول مرة لتحميل الدروس. بعد ذلك يمكنك الاستماع دون إنترنت.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemCount: _lessons.length,
                          itemBuilder: (context, i) => AudioItem(
                            lesson: _lessons[i],
                            playlist: _lessons,
                          ),
                        ),
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
