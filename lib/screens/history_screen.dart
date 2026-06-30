import 'package:flutter/material.dart';
import '../models.dart';
import '../services/content_repository.dart';
import '../services/local_store.dart';
import '../widgets/audio_item.dart';

/// Recently played lessons (on-device history), most recent first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ContentRepository.instance;
    final items = LocalStore.getRecentPlayedIds()
        .map((id) => repo.lessonById(id))
        .whereType<Lesson>()
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('السجل')),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا يوجد سجل استماع بعد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, i) =>
                  AudioItem(lesson: items[i], playlist: items),
            ),
    );
  }
}
