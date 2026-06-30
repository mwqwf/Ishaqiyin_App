import 'package:flutter/material.dart';
import '../services/audio_controller.dart';
import '../theme.dart';
import '../utils/lesson_display.dart';
import '../screens/player_screen.dart';

/// Persistent mini player bar shown above the bottom of every screen.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = AudioController.instance;
    return AnimatedBuilder(
      animation: audio,
      builder: (context, _) {
        final lesson = audio.currentLesson;
        if (lesson == null) return const SizedBox.shrink();

        return Material(
          elevation: 8,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(
                    lesson: lesson,
                    playlist: audio.playlist.isNotEmpty
                        ? audio.playlist
                        : [lesson],
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (audio.isLoading)
                    const LinearProgressIndicator(minHeight: 2, color: kTeal),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: kTeal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.headphones,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lessonDisplayTitle(lesson),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              StreamBuilder<Duration>(
                                stream: audio.positionStream,
                                builder: (context, snap) {
                                  final progress = audio.progressFor(lesson.id);
                                  return LinearProgressIndicator(
                                    value: progress > 0 ? progress : null,
                                    minHeight: 2,
                                    backgroundColor: Colors.grey.shade300,
                                    color: kGreen,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          label: audio.playing ? 'إيقاف مؤقت' : 'تشغيل',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              audio.playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: kOrange,
                              size: 36,
                            ),
                            onPressed: () => audio.toggle(lesson),
                          ),
                        ),
                        Semantics(
                          label: 'التالي',
                          button: true,
                          child: IconButton(
                            icon: const Icon(Icons.skip_next, color: kBlue),
                            onPressed: audio.playNext,
                          ),
                        ),
                      ],
                    ),
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
