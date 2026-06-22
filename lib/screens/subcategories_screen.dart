import 'package:flutter/material.dart';

import '../models.dart';
import '../services/firebase_repo.dart';
import '../services/local_store.dart';
import '../theme.dart';
import 'lessons_screen.dart';

class SubcategoriesScreen extends StatefulWidget {
  final Category category;
  const SubcategoriesScreen({super.key, required this.category});

  @override
  State<SubcategoriesScreen> createState() => _SubcategoriesScreenState();
}

class _SubcategoriesScreenState extends State<SubcategoriesScreen> {
  List<Subcategory> _subs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocalStore.incrementCategoryVisit(widget.category.id);
    _loadCache();
    _refresh();
  }

  void _loadCache() {
    final cached = FirebaseRepo.subcategoriesForCategory(
        widget.category.id, LocalStore.getSubcategories());
    setState(() {
      _subs = cached;
      _loading = cached.isEmpty;
    });
  }

  Future<void> _refresh() async {
    final all = await FirebaseRepo.fetchSubcategories();
    if (!mounted) return;
    setState(() {
      _subs = FirebaseRepo.subcategoriesForCategory(widget.category.id, all);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      return Card(
                        color: kSlate,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.folder_open, color: kGold),
                          title: Text(
                            s.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 17),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LessonsScreen(subcategory: s),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
