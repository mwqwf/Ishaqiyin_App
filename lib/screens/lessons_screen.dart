import 'package:flutter/material.dart';

import '../models.dart';
import '../services/content_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subcategory.name),
        actions: [
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
