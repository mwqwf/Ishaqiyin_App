import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/audio_controller.dart';
import '../services/content_repository.dart';
import '../services/download_service.dart';
import '../services/local_store.dart';
import '../theme.dart';
import '../utils/category_colors.dart';
import '../utils/lesson_display.dart';
import '../screens/player_screen.dart';

/// A lesson row with progress, favorite, duration, and share-as-link.
class AudioItem extends StatefulWidget {
  final Lesson lesson;
  final List<Lesson> playlist;
  final bool showActions;
  const AudioItem({
    super.key,
    required this.lesson,
    required this.playlist,
    this.showActions = true,
  });

  @override
  State<AudioItem> createState() => _AudioItemState();
}

class _AudioItemState extends State<AudioItem> {
  final AudioController _audio = AudioController.instance;
  bool _downloading = false;
  double _progress = 0;

  bool get _downloaded => DownloadService.isAudioDownloaded(widget.lesson.id);
  bool get _favorite => LocalStore.isFavorite(widget.lesson.id);

  void _openPlayer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(lesson: widget.lesson, playlist: widget.playlist),
      ),
    );
  }

  Future<void> _download() async {
    if (_downloading) return;
    if (widget.lesson.audioUrl.isEmpty) {
      _showSnack('لا يمكن التحميل: لا يتوفر رابط صوتي.');
      return;
    }
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      await DownloadService.downloadAudio(
        widget.lesson.id,
        widget.lesson.audioUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      _showSnack('تم تحميل الدرس بنجاح.');
    } catch (_) {
      _showSnack('تعذر تحميل الدرس.');
    }
    if (mounted) setState(() => _downloading = false);
  }

  Future<void> _share() async {
    final repo = ContentRepository.instance;
    final cat = repo.categoryById(widget.lesson.categoryId);
    final sub = repo.subcategoryById(widget.lesson.subcategoryId);
    final text = lessonShareText(widget.lesson,
        categoryName: cat?.name, subName: sub?.name);
    // محمّل → نشارك الملف نفسه؛ غير محمّل → نشارك رابطاً يفتح داخل التطبيق.
    final local = DownloadService.localAudioPath(widget.lesson.id);
    if (local != null) {
      await Share.shareXFiles([XFile(local)],
          text: text, subject: lessonDisplayTitle(widget.lesson));
    } else {
      await Share.share(text, subject: lessonDisplayTitle(widget.lesson));
    }
  }

  Future<void> _toggleFavorite() async {
    await LocalStore.toggleFavorite(widget.lesson.id);
    setState(() {});
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final durMs = widget.lesson.durationMs > 0
        ? widget.lesson.durationMs
        : LocalStore.getDurationMs(widget.lesson.id);
    final savedProgress = durMs > 0
        ? (LocalStore.getPosition(widget.lesson.id) / durMs).clamp(0.0, 1.0)
        : 0.0;
    final accent = colorForCategory(widget.lesson.categoryId);

    return AnimatedBuilder(
      animation: _audio,
      builder: (context, _) {
        final active = _audio.isActive(widget.lesson.id);
        final playing = active && _audio.playing;
        final liveProgress =
            active ? _audio.progressFor(widget.lesson.id) : savedProgress;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openPlayer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Semantics(
                        label: playing ? 'إيقاف' : 'تشغيل',
                        button: true,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: playing ? kGreen : accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(playing ? Icons.pause : Icons.play_arrow,
                              color: Colors.white, size: 26),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lessonDisplayTitle(widget.lesson),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: active ? kTeal : null,
                              ),
                            ),
                            if (widget.lesson.speaker.isNotEmpty)
                              Text(widget.lesson.speaker,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            if (durMs > 0)
                              Text(
                                formatDuration(Duration(milliseconds: durMs)),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      if (widget.showActions) ...[
                        Semantics(
                          label: _favorite ? 'إزالة من المفضّلة' : 'إضافة للمفضّلة',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              _favorite ? Icons.favorite : Icons.favorite_border,
                              color: _favorite ? Colors.red : Colors.grey,
                              size: 22,
                            ),
                            onPressed: _toggleFavorite,
                          ),
                        ),
                        _downloading
                            ? SizedBox(
                                width: 40,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    Text('${_progress.toStringAsFixed(0)}%',
                                        style: const TextStyle(fontSize: 10)),
                                  ],
                                ),
                              )
                            : Semantics(
                                label: _downloaded ? 'تم التحميل' : 'تحميل',
                                button: true,
                                child: IconButton(
                                  tooltip: _downloaded
                                      ? 'تم التحميل'
                                      : 'تحميل للاستماع دون إنترنت',
                                  icon: Icon(
                                    _downloaded
                                        ? Icons.download_done
                                        : Icons.download_outlined,
                                    color: _downloaded ? kGreen : kOrange,
                                  ),
                                  onPressed: _downloaded ? null : _download,
                                ),
                              ),
                        Semantics(
                          label: 'مشاركة',
                          button: true,
                          child: IconButton(
                            tooltip: 'مشاركة',
                            icon: const Icon(Icons.share, color: kTeal),
                            onPressed: _share,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (liveProgress > 0.02) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: liveProgress,
                        minHeight: 3,
                        backgroundColor: Colors.grey.shade300,
                        color: kGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
