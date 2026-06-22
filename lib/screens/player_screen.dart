import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../services/firebase_repo.dart';
import '../services/local_store.dart';
import '../theme.dart';
import 'lessons_screen.dart';
import 'subcategories_screen.dart';

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Dedicated "now playing" screen (YouTube-style): large player, jump to the
/// audio's section (sub -> main), and a list of similar audio that spans both
/// the same section and beyond.
class PlayerScreen extends StatefulWidget {
  final Lesson lesson;
  final List<Lesson> playlist;
  const PlayerScreen({super.key, required this.lesson, required this.playlist});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioController _audio = AudioController.instance;
  List<Lesson> _all = [];
  List<Subcategory> _subs = [];
  List<Category> _cats = [];
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _all = LocalStore.getLessons();
    _subs = LocalStore.getSubcategories();
    _cats = LocalStore.getCategories();
    _audio.setPlaylist(
        widget.playlist.isNotEmpty ? widget.playlist : [widget.lesson]);
    if (!_audio.isActive(widget.lesson.id)) {
      _audio.playLesson(widget.lesson);
    }
  }

  Lesson get _current => _audio.currentLesson ?? widget.lesson;

  Subcategory? _subOf(Lesson l) {
    for (final s in _subs) {
      if (s.id == l.subcategoryId) return s;
    }
    return null;
  }

  Category? _catOf(Lesson l) {
    for (final c in _cats) {
      if (c.id == l.categoryId) return c;
    }
    return null;
  }

  void _openSubcategory(Lesson l) {
    final sub = _subOf(l) ??
        Subcategory(
          id: l.subcategoryId,
          name: 'القسم الفرعي',
          categoryId: l.categoryId,
          createdAt: l.createdAt,
        );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonsScreen(subcategory: sub)),
    );
  }

  void _openCategory(Lesson l) {
    final cat = _catOf(l);
    if (cat == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SubcategoriesScreen(category: cat)),
    );
  }

  Future<void> _download(Lesson l) async {
    if (_downloading) return;
    if (l.audioUrl.isEmpty) {
      _snack('لا يتوفر رابط صوتي لهذه الصوتية.');
      return;
    }
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      await DownloadService.downloadAudio(
        l.id,
        l.audioUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      _snack('تم التحميل بنجاح.');
    } catch (_) {
      _snack('تعذر التحميل.');
    }
    if (mounted) setState(() => _downloading = false);
  }

  Future<void> _share(Lesson l) async {
    final path = DownloadService.localAudioPath(l.id);
    if (path != null) {
      await Share.shareXFiles([XFile(path)], subject: l.title);
    } else {
      _snack('حمّل الصوتية أولاً لمشاركتها.');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الآن يُشغَّل')),
      body: AnimatedBuilder(
        animation: _audio,
        builder: (context, _) {
          final l = _current;
          final sub = _subOf(l);
          final cat = _catOf(l);
          final similar = FirebaseRepo.similarTo(l, _all);
          final downloaded = DownloadService.isAudioDownloaded(l.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _artwork(),
              const SizedBox(height: 18),
              Text(
                l.title.isEmpty ? 'درس صوتي' : l.title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              _SeekBarLarge(audio: _audio),
              const SizedBox(height: 6),
              _controls(l, downloaded),
              _autoplayToggle(),
              const Divider(height: 32),
              _sectionNav(l, sub, cat),
              const Divider(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('صوتيات مشابهة',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (similar.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('لا توجد اقتراحات بعد.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...similar.map((s) => _similarTile(s, similar)),
            ],
          );
        },
      ),
    );
  }

  Widget _artwork() {
    return Center(
      child: Container(
        width: 180,
        height: 180,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [kTeal, kSlate],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: const Icon(Icons.headphones, color: Colors.white, size: 84),
      ),
    );
  }

  Widget _controls(Lesson l, bool downloaded) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _downloading
            ? SizedBox(
                width: 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    Text('${_progress.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              )
            : IconButton(
                tooltip: downloaded ? 'تم التحميل' : 'تحميل للاستماع دون إنترنت',
                icon: Icon(
                  downloaded ? Icons.download_done : Icons.download_outlined,
                  color: downloaded ? kGreen : kOrange,
                ),
                onPressed: downloaded ? null : () => _download(l),
              ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous, color: kBlue),
          onPressed: _audio.playPrevious,
        ),
        _bigPlay(l),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next, color: kBlue),
          onPressed: _audio.playNext,
        ),
        IconButton(
          tooltip: 'مشاركة',
          icon: const Icon(Icons.share, color: kTeal),
          onPressed: () => _share(l),
        ),
      ],
    );
  }

  Widget _bigPlay(Lesson l) {
    final playing = _audio.isActive(l.id) && _audio.playing;
    return InkWell(
      onTap: () => _audio.toggle(l),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: playing ? kGreen : kOrange,
          shape: BoxShape.circle,
        ),
        child: Icon(playing ? Icons.pause : Icons.play_arrow,
            color: Colors.white, size: 42),
      ),
    );
  }

  Widget _autoplayToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.playlist_play, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        const Text('تشغيل تلقائي للتالي'),
        Switch(
          value: _audio.autoplay,
          onChanged: (v) => _audio.autoplay = v,
        ),
      ],
    );
  }

  Widget _sectionNav(Lesson l, Subcategory? sub, Category? cat) {
    final subName = (sub?.name.isNotEmpty ?? false) ? sub!.name : 'فتح القسم';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (l.subcategoryId.isNotEmpty)
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
                alignment: AlignmentDirectional.centerStart),
            icon: const Icon(Icons.folder_open),
            label: Text('القسم الفرعي: $subName'),
            onPressed: () => _openSubcategory(l),
          ),
        if (cat != null) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
                alignment: AlignmentDirectional.centerStart),
            icon: const Icon(Icons.folder),
            label: Text('القسم الرئيسي: ${cat.name}'),
            onPressed: () => _openCategory(l),
          ),
        ],
      ],
    );
  }

  Widget _similarTile(Lesson s, List<Lesson> playlist) {
    final sub = _subOf(s);
    final active = _audio.isActive(s.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: active ? kGreen : kTeal,
          child: Icon(
            active && _audio.playing ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
        ),
        title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: (sub?.name.isNotEmpty ?? false)
            ? Text(sub!.name, style: const TextStyle(fontSize: 12))
            : null,
        onTap: () {
          _audio.setPlaylist(playlist);
          _audio.toggle(s);
        },
      ),
    );
  }
}

class _SeekBarLarge extends StatelessWidget {
  final AudioController audio;
  const _SeekBarLarge({required this.audio});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audio.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final total = audio.duration;
        final maxMs =
            total.inMilliseconds <= 0 ? 1.0 : total.inMilliseconds.toDouble();
        final value = pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3),
              child: Slider(
                min: 0,
                max: maxMs,
                value: value,
                activeColor: kGreen,
                onChanged: (v) =>
                    audio.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(pos),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(_fmt(total),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
