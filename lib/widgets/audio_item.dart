import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/audio_controller.dart';
import '../services/download_service.dart';
import '../theme.dart';
import '../screens/player_screen.dart';

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// A lesson row. Tapping it opens the dedicated player screen (which starts
/// playback and shows similar audio). Download / share stay inline.
class AudioItem extends StatefulWidget {
  final Lesson lesson;
  final List<Lesson> playlist;
  const AudioItem({super.key, required this.lesson, required this.playlist});

  @override
  State<AudioItem> createState() => _AudioItemState();
}

class _AudioItemState extends State<AudioItem> {
  final AudioController _audio = AudioController.instance;
  bool _downloading = false;
  double _progress = 0;

  bool get _downloaded => DownloadService.isAudioDownloaded(widget.lesson.id);

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
    final path = DownloadService.localAudioPath(widget.lesson.id);
    if (path != null) {
      await Share.shareXFiles([XFile(path)], subject: widget.lesson.title);
    } else {
      _showSnack('حمّل الدرس أولاً لمشاركته.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _audio,
      builder: (context, _) {
        final active = _audio.isActive(widget.lesson.id);
        final playing = active && _audio.playing;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openPlayer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: playing ? kGreen : kOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: active ? kTeal : null,
                      ),
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
                      : IconButton(
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
                  if (_downloaded)
                    IconButton(
                      tooltip: 'مشاركة',
                      icon: const Icon(Icons.share, color: kTeal),
                      onPressed: _share,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
