import 'package:flutter/material.dart';

import '../models.dart';
import '../services/firebase_repo.dart';
import '../services/local_store.dart';
import '../widgets/audio_item.dart';
import 'subcategories_screen.dart';

class LessonsScreen extends StatefulWidget {
  final Subcategory subcategory;
  const LessonsScreen({super.key, required this.subcategory});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  List<Lesson> _lessons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocalStore.incrementSubcategoryVisit(widget.subcategory.id);
    _loadCache();
    _refresh();
  }

  void _loadCache() {
    final cached = FirebaseRepo.lessonsForSubcategory(
        widget.subcategory.id, LocalStore.getLessons());
    setState(() {
      _lessons = cached;
      _loading = cached.isEmpty;
    });
  }

  Future<void> _refresh() async {
    final all = await FirebaseRepo.fetchAllLessons();
    if (!mounted) return;
    setState(() {
      _lessons =
          FirebaseRepo.lessonsForSubcategory(widget.subcategory.id, all);
      _loading = false;
    });
  }

  void _openCategory() {
    Category? found;
    for (final c in LocalStore.getCategories()) {
      if (c.id == widget.subcategory.categoryId) {
        found = c;
        break;
      }
    }
    final cat = found;
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
      body: RefreshIndicator(
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
    );
  }
}
