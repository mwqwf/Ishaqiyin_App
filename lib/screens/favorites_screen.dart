import 'package:flutter/material.dart';
import '../models.dart';
import '../services/content_repository.dart';
import '../services/firebase_repo.dart';
import '../services/local_store.dart';
import '../widgets/audio_item.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Lesson> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
    ContentRepository.instance.addListener(_load);
    LocalStore.libraryRevision.addListener(_load);
  }

  void _load() {
    final lessons = ContentRepository.instance.lessons;
    if (!mounted) return;
    setState(() {
      _items = FirebaseRepo.favorites(lessons);
    });
  }

  @override
  void dispose() {
    ContentRepository.instance.removeListener(_load);
    LocalStore.libraryRevision.removeListener(_load);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المفضّلة')),
      body: _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'اضغط ♥ على أي درس لحفظه هنا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              itemBuilder: (context, i) => AudioItem(
                lesson: _items[i],
                playlist: _items,
              ),
            ),
    );
  }
}
