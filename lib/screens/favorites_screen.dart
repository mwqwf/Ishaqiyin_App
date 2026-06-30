import 'package:flutter/material.dart';
import '../models.dart';
import '../services/content_repository.dart';
import '../services/firebase_repo.dart';
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
  }

  void _load() {
    final lessons = ContentRepository.instance.lessons;
    setState(() {
      _items = FirebaseRepo.favorites(lessons);
    });
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
