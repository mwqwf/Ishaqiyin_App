import 'package:flutter/material.dart';
import '../models.dart';
import '../services/content_repository.dart';
import '../services/local_store.dart';
import '../theme.dart';
import '../utils/lesson_display.dart';
import 'player_screen.dart';

/// Prompts for a playlist name. Returns null when cancelled.
Future<String?> askPlaylistName(BuildContext context,
    {String title = 'قائمة جديدة', String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'اسم القائمة'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  List<Playlist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _playlists = LocalStore.getPlaylists());

  Future<void> _create() async {
    final name = await askPlaylistName(context);
    if (name == null || name.isEmpty) return;
    await LocalStore.createPlaylist(name);
    _load();
  }

  Future<void> _delete(Playlist p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القائمة'),
        content: Text('حذف "${p.name}"؟ (لن تُحذف الدروس نفسها)'),
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
      await LocalStore.deletePlaylist(p.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قوائم التشغيل')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('قائمة جديدة'),
      ),
      body: _playlists.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد قوائم بعد.\nأنشئ قائمة وأضِف إليها دروسك المفضّلة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _playlists.length,
              itemBuilder: (context, i) {
                final p = _playlists[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: kTeal,
                      child: Icon(Icons.queue_music, color: Colors.white),
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.lessonIds.length} صوتية'),
                    trailing: IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _delete(p),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlaylistDetailScreen(playlist: p)),
                      );
                      _load();
                    },
                  ),
                );
              },
            ),
    );
  }
}

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _p;
  List<Lesson> _lessons = [];

  @override
  void initState() {
    super.initState();
    _p = widget.playlist;
    _reload();
  }

  void _reload() {
    final fresh = LocalStore.getPlaylists().firstWhere(
      (x) => x.id == widget.playlist.id,
      orElse: () => widget.playlist,
    );
    final repo = ContentRepository.instance;
    setState(() {
      _p = fresh;
      _lessons = fresh.lessonIds
          .map(repo.lessonById)
          .whereType<Lesson>()
          .toList();
    });
  }

  Future<void> _remove(Lesson l) async {
    await LocalStore.removeFromPlaylist(_p.id, l.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_p.name)),
      body: _lessons.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'القائمة فارغة.\nأضِف دروساً من زر «إضافة لقائمة» في المشغّل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _lessons.length,
              itemBuilder: (context, i) {
                final l = _lessons[i];
                final dur = LocalStore.getDurationMs(l.id);
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: kTeal,
                      child: Icon(Icons.play_arrow, color: Colors.white),
                    ),
                    title: Text(lessonDisplayTitle(l),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: dur > 0
                        ? Text(formatDuration(Duration(milliseconds: dur)))
                        : null,
                    trailing: IconButton(
                      tooltip: 'إزالة من القائمة',
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () => _remove(l),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PlayerScreen(lesson: l, playlist: _lessons),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
