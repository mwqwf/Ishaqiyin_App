import 'package:flutter/material.dart';
import '../models.dart';
import '../services/content_repository.dart';
import '../services/download_service.dart';
import '../services/local_store.dart';
import '../theme.dart';
import '../utils/lesson_display.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Lesson> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
    ContentRepository.instance.addListener(_load);
    LocalStore.libraryRevision.addListener(_load);
  }

  void _load() {
    final repo = ContentRepository.instance;
    final downloads = DownloadService.allDownloads();
    final byId = {for (final l in repo.lessons) l.id: l};
    if (!mounted) return;
    setState(() {
      _items = downloads.map((e) => byId[e.key]).whereType<Lesson>().toList();
    });
  }

  @override
  void dispose() {
    ContentRepository.instance.removeListener(_load);
    LocalStore.libraryRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _delete(Lesson l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التنزيل'),
        content: Text('حذف "${lessonDisplayTitle(l)}" من جهازك؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await DownloadService.deleteDownload(l.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنزيلاتي')),
      body: _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد دروس منزّلة بعد.\nحمّل دروساً للاستماع دون إنترنت.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17),
                ),
              ),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final l = _items[i];
                final dur = LocalStore.getDurationMs(l.id);
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: kGreen,
                      child: Icon(Icons.download_done, color: Colors.white),
                    ),
                    title: Text(lessonDisplayTitle(l)),
                    subtitle: dur > 0
                        ? Text(formatDuration(Duration(milliseconds: dur)))
                        : null,
                    trailing: IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _delete(l),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PlayerScreen(lesson: l, playlist: _items),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
